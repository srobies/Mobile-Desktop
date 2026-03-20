import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../../platform/ios_storage.dart';
import '../../preference/user_preferences.dart';
import '../database/offline_database.dart';
import '../models/aggregated_item.dart';
import '../models/download_quality.dart';
import '../repositories/offline_repository.dart';
import 'book_reader_service.dart';
import 'download_notification_service.dart';
import 'storage_path_service.dart';

class DownloadProgress {
  final String itemId;
  final String fileName;
  final double progress;
  final int bytesReceived;
  final bool isComplete;
  final String? error;

  const DownloadProgress({
    required this.itemId,
    required this.fileName,
    this.progress = 0,
    this.bytesReceived = 0,
    this.isComplete = false,
    this.error,
  });
}

class DownloadService extends ChangeNotifier {
  final MediaServerClient _client;
  final DownloadNotificationService _notificationService;
  final Dio _downloadDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(hours: 6),
  ));

  final Map<String, DownloadProgress> _activeDownloads = {};
  Map<String, DownloadProgress> get activeDownloads =>
      Map.unmodifiable(_activeDownloads);

  final Map<String, CancelToken> _cancelTokens = {};

  int _totalQueued = 0;
  int _completedCount = 0;
  int get totalQueued => _totalQueued;
  int get completedCount => _completedCount;
  bool get isBatchDownloading => _totalQueued > 0 && _completedCount < _totalQueued;

  DownloadService(this._client, this._notificationService);

  bool isDownloading(String itemId) => _activeDownloads.containsKey(itemId);

  UserPreferences get _prefs => GetIt.instance<UserPreferences>();

  int _concurrencyLimit() {
    return _prefs.get(UserPreferences.downloadConcurrentCount).clamp(1, 5);
  }

  int _inFlightDownloads() {
    return _activeDownloads.values
        .where((d) => !d.isComplete && d.error == null)
        .length;
  }

  Future<void> _waitForDownloadSlot() async {
    while (_inFlightDownloads() >= _concurrencyLimit()) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<bool> _checkWifiPolicy() async {
    if (!_prefs.get(UserPreferences.downloadWifiOnly)) return true;
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r == ConnectivityResult.wifi);
  }

  Future<bool> _checkStorageLimit(int estimatedBytes) async {
    final limitMb = _prefs.get(UserPreferences.downloadStorageLimitMb);
    if (limitMb <= 0) return true;
    final used = await _offlineRepo.getTotalStorageUsed();
    return (used + estimatedBytes) <= limitMb * 1024 * 1024;
  }

  StoragePathService get _storagePath => GetIt.instance<StoragePathService>();
  OfflineRepository get _offlineRepo => GetIt.instance<OfflineRepository>();

  String _fileNameBaseFromPath(String savePath) {
    final fileName = savePath.split(Platform.pathSeparator).last;
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  Future<void> _deleteSubtitleFiles(Directory dir, String fileNameBase) async {
    if (!await dir.exists()) {
      return;
    }

    final prefix = '${fileNameBase}_sub_';
    await for (final entity in dir.list()) {
      if (entity is! File) {
        continue;
      }

      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith(prefix)) {
        await entity.delete();
      }
    }
  }

  Future<void> _deleteEmptyDirectoriesUpTo(Directory start, Directory root) async {
    var current = start;

    while (current.path.startsWith(root.path) && current.path != root.path) {
      if (!await current.exists()) {
        current = current.parent;
        continue;
      }

      if (!await current.list().isEmpty) {
        break;
      }

      final parent = current.parent;
      await current.delete();
      current = parent;
    }
  }

  Future<void> _deleteFileArtifacts(String savePath) async {
    final offlineRoot = await _storagePath.getOfflineRoot();
    await _deleteFileArtifactsWithinRoot(savePath, offlineRoot);
  }

  Future<void> _deleteFileArtifactsWithinRoot(String savePath, Directory offlineRoot) async {
    final file = File(savePath);
    if (await file.exists()) {
      await file.delete();
    }

    final parent = file.parent;
    await _deleteSubtitleFiles(parent, _fileNameBaseFromPath(savePath));
    await _deleteEmptyDirectoriesUpTo(parent, offlineRoot);
  }

  Future<void> _deleteCandidateFileArtifacts(
    Directory dir,
    AggregatedItem item,
    Directory offlineRoot,
  ) async {
    final candidatePaths = _candidateSavePaths(dir, item).toList(growable: false);
    final fileNameBases = candidatePaths.map(_fileNameBaseFromPath).toSet();

    for (final savePath in candidatePaths) {
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    for (final fileNameBase in fileNameBases) {
      await _deleteSubtitleFiles(dir, fileNameBase);
    }

    await _deleteEmptyDirectoriesUpTo(dir, offlineRoot);
  }

  Future<void> _deleteImagesForIds(Iterable<String> itemIds, Directory imageDir) async {
    for (final itemId in itemIds.toSet()) {
      await _deleteItemImages(itemId, imageDir);
    }
  }

  Future<void> _cleanupEpisodeContainers(AggregatedItem episode, Directory imageDir) async {
    if (episode.seasonId != null) {
      final seasonEpisodes = await _offlineRepo.getSeasonEpisodes(episode.seasonId!);
      if (seasonEpisodes.isEmpty) {
        await _offlineRepo.deleteItem(episode.seasonId!);
        await _deleteItemImages(episode.seasonId!, imageDir);
      }
    }

    if (episode.seriesId != null) {
      final seriesEpisodes = await _offlineRepo.getSeriesEpisodes(episode.seriesId!);
      if (seriesEpisodes.isEmpty) {
        await _offlineRepo.deleteItem(episode.seriesId!);
        await _deleteItemImages(episode.seriesId!, imageDir);
      }
    }
  }

  Iterable<String> _candidateSavePaths(Directory dir, AggregatedItem item) sync* {
    final seenPaths = <String>{};

    for (final quality in DownloadQuality.values) {
      final savePath = '${dir.path}/${_buildFileName(item, quality)}';
      if (seenPaths.add(savePath)) {
        yield savePath;
      }
    }
  }

  double _initialProgressForQuality(DownloadQuality quality) {
    return quality.isTranscoded ? -1.0 : 0.0;
  }

  double _clampProgress(double progress) {
    if (progress <= 0) {
      return 0.0;
    }

    if (progress >= 1) {
      return 1.0;
    }

    return progress;
  }

  double _storedProgress(double progress) {
    return progress < 0 ? 0.0 : _clampProgress(progress);
  }

  Future<Set<String>> _relatedImageIds(AggregatedItem item) async {
    final allItems = await _offlineRepo.getItems();

    switch (item.type) {
      case 'Season':
        return allItems
            .where((row) => row.itemId == item.id || row.seasonId == item.id)
            .map((row) => row.itemId)
            .toSet();

      case 'Series':
        return allItems
            .where((row) => row.itemId == item.id || row.seriesId == item.id)
            .map((row) => row.itemId)
            .toSet();

      default:
        return {item.id};
    }
  }

  double _calculateProgress({
    required int received,
    required int total,
    required int estimatedSize,
    required DownloadQuality quality,
  }) {
    if (total > 0) {
      return _clampProgress(received / total);
    }

    if (quality.isTranscoded) {
      return -1.0;
    }

    if (estimatedSize > 0) {
      return _clampProgress(received / estimatedSize);
    }

    return -1.0;
  }

  String _sanitizePath(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  String _buildSubFolder(AggregatedItem item) {
    switch (item.type) {
      case 'Movie':
        final year = item.productionYear;
        final title = _sanitizePath(item.name);
        return year != null ? 'Movies/$title ($year)' : 'Movies/$title';

      case 'Audio':
        final artist = _sanitizePath(
          item.albumArtist ??
              (item.artists.isNotEmpty ? item.artists.first : 'Unknown Artist'),
        );
        final album = _sanitizePath(item.album ?? 'Singles');
        return 'Music/$artist/$album';

      case 'AudioBook':
        final author = _sanitizePath(
          item.albumArtist ??
              (item.artists.isNotEmpty ? item.artists.first : 'Unknown Author'),
        );
        final collection = _sanitizePath(item.album ?? item.name);
        return 'Audiobooks/$author/$collection';

      case 'Book':
        return 'Books/${_sanitizePath(item.name)}';

      case 'Episode':
        final series = _sanitizePath(item.seriesName ?? 'Unknown Series');
        final season = item.parentIndexNumber;
        final seasonFolder =
            season != null ? 'Season ${season.toString().padLeft(2, '0')}' : 'Specials';
        return 'TV/$series/$seasonFolder';

      default:
        return 'Other/${_sanitizePath(item.name)}';
    }
  }

  String _buildFileName(AggregatedItem item, DownloadQuality quality) {
    final container = _getContainer(item, quality);
    switch (item.type) {
      case 'Audio':
      case 'AudioBook':
        final index = item.indexNumber;
        final prefix = index != null ? '${index.toString().padLeft(2, '0')} - ' : '';
        return '$prefix${_sanitizePath(item.name)}.$container';

      case 'Episode':
        final s = item.parentIndexNumber;
        final e = item.indexNumber;
        final prefix =
            (s != null && e != null) ? 'S${s.toString().padLeft(2, '0')}E${e.toString().padLeft(2, '0')} - ' : '';
        return '$prefix${_sanitizePath(item.name)}.$container';

      default:
        return '${_sanitizePath(item.name)}.$container';
    }
  }

  String _getContainer(AggregatedItem item, DownloadQuality quality) {
    if (item.type == 'Book') {
      final ext = BookReaderService.detectExtension(item);
      if (ext != null && ext.isNotEmpty) return ext.toLowerCase();
    }

    if (quality.isTranscoded) return quality.container;
    if (item.mediaSources.isNotEmpty) {
      final c = item.mediaSources.first['Container'] as String?;
      if (c != null && c.isNotEmpty) return c.toLowerCase();
    }
    return 'mkv';
  }

  Future<String?> _correctBookExtension(
    File savedFile,
    Response? response,
  ) async {
    final currentPath = savedFile.path;
    final currentExt = currentPath.contains('.')
        ? currentPath.substring(currentPath.lastIndexOf('.') + 1).toLowerCase()
        : '';

    String? detectedExt;

    if (response != null) {
      final disposition = response.headers.value('content-disposition');
      detectedExt = BookReaderService.extractExtensionFromContentDisposition(disposition);

      if (detectedExt == null) {
        final contentType = response.headers.value('content-type');
        detectedExt = BookReaderService.extensionFromMime(contentType);
      }
    }

    if (detectedExt == null || detectedExt == currentExt) return null;
    if (!BookReaderService.supportedExtensions.contains(detectedExt)) return null;

    final newPath = currentPath.contains('.')
        ? currentPath.replaceAll(RegExp(r'\.[^.]+$'), '.$detectedExt')
        : '$currentPath.$detectedExt';
    if (newPath == currentPath) return null;
    await savedFile.rename(newPath);
    return newPath;
  }

  Future<void> _populateOfflineAssets(AggregatedItem item) async {
    await _downloadImages(item);
    if (_usesAudioDownloadEndpoint(item)) {
      await _downloadLyrics(item);
    }
    await _ensureParentContainers(item);
  }

  /// Wraps [Dio.download] so that once all expected bytes have been received
  /// the future resolves after a short grace period, even if the HTTP
  /// connection hangs open (common behind reverse proxies / keep-alive).
  Future<Response?> _downloadWithHangGuard(
    String url,
    String savePath, {
    required Options options,
    required CancelToken cancelToken,
    required void Function(int, int) onReceiveProgress,
  }) async {
    final bytesComplete = Completer<void>();

    final downloadFuture = _downloadDio.download(
      url,
      savePath,
      options: options,
      cancelToken: cancelToken,
      deleteOnError: false,
      onReceiveProgress: (received, total) {
        onReceiveProgress(received, total);
        if (total > 0 && received >= total && !bytesComplete.isCompleted) {
          bytesComplete.complete();
        }
      },
    );

    return Future.any<Response?>([
      downloadFuture.then<Response?>((r) => r),
      bytesComplete.future
          .then((_) => Future<Response?>.delayed(
                const Duration(seconds: 5),
                () => null,
              )),
    ]);
  }

  bool _supportsTranscodedDownload(String? type) {
    return type == 'Movie' || type == 'Episode';
  }

  Map<String, String> _buildAuthHeaders() {
    final token = _client.accessToken;
    if (token == null || token.isEmpty) {
      return const {};
    }

    return {
      'X-Emby-Token': token,
      'Authorization': 'MediaBrowser Token="$token"',
    };
  }

  bool _usesAudioDownloadEndpoint(AggregatedItem item) {
    final mediaType = item.rawData['MediaType'] as String?;
    return item.type == 'Audio' || item.type == 'AudioBook' || mediaType == 'Audio';
  }

  bool _shouldRetryWithFallback(
    AggregatedItem item,
    DownloadQuality quality,
    DioException error,
  ) {
    final status = error.response?.statusCode;
    if (status != 401 && status != 403 && status != 404) {
      return false;
    }

    if (item.type == 'Book') {
      return true;
    }

    return !quality.isTranscoded;
  }

  String? _primaryMediaSourceId(AggregatedItem item) {
    return item.mediaSources.isNotEmpty ? item.mediaSources.first['Id'] as String? : null;
  }

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Map<String, String> _baseDownloadParams(AggregatedItem item, {bool isStatic = false}) {
    final mediaSourceId = _primaryMediaSourceId(item);
    return <String, String>{
      if (isStatic) 'Static': 'true',
      if (mediaSourceId != null) 'MediaSourceId': mediaSourceId,
      if (_client.accessToken != null) 'api_key': _client.accessToken!,
    };
  }

  String _buildDirectItemFileUrl(String itemId, AggregatedItem item) {
    final query = _encodeQuery(_baseDownloadParams(item));
    return '${_client.baseUrl}/Items/$itemId/File${query.isEmpty ? '' : '?$query'}';
  }

  String _buildStaticVideoStreamUrl(String itemId, AggregatedItem item) {
    final query = _encodeQuery(_baseDownloadParams(item, isStatic: true));
    return '${_client.baseUrl}/Videos/$itemId/stream?$query';
  }

  List<String> _buildDownloadFallbackUrls(
    AggregatedItem item,
    {
    required String primaryUrl,
  }) {
    final candidates = <String>[
      if (item.type == 'Book')
        ...BookReaderService.buildDownloadUris(_client, item).map((u) => u.toString())
      else ...[
        if (_usesAudioDownloadEndpoint(item)) _buildAudioDownloadUrl(item.id, item),
        _buildDirectItemDownloadUrl(item.id, item),
        _buildDirectItemFileUrl(item.id, item),
        _buildStaticVideoStreamUrl(item.id, item),
      ],
    ];

    final fallbackUrls = <String>[];
    final primary = Uri.parse(primaryUrl).toString();
    final seen = <String>{primary};
    for (final candidate in candidates) {
      final normalized = Uri.parse(candidate).toString();
      if (seen.add(normalized)) {
        fallbackUrls.add(normalized);
      }
    }

    return fallbackUrls;
  }

  String _friendlyDioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 403) {
      return 'Download forbidden (403). Retried alternate endpoints but access was denied.';
    }
    if (status == 401) {
      return 'Download unauthorized (401). Please re-login and try again.';
    }
    if (status == 404) {
      return 'Download source not found (404). The file may no longer be available.';
    }
    return e.message ?? 'Download failed';
  }

  String _buildAudioDownloadUrl(String itemId, AggregatedItem item) {
    final query = _encodeQuery(_baseDownloadParams(item, isStatic: true));
    return '${_client.baseUrl}/Audio/$itemId/stream?$query';
  }

  String _buildDirectItemDownloadUrl(String itemId, AggregatedItem item) {
    final query = _encodeQuery(_baseDownloadParams(item));
    return '${_client.baseUrl}/Items/$itemId/Download${query.isEmpty ? '' : '?$query'}';
  }

  String _buildDownloadUrl(String itemId, AggregatedItem item, DownloadQuality quality) {
    if (_usesAudioDownloadEndpoint(item)) {
      return _buildAudioDownloadUrl(itemId, item);
    }

    if (!quality.isTranscoded || !_supportsTranscodedDownload(item.type)) {
      return _buildDirectItemDownloadUrl(itemId, item);
    }

    final baseUrl = _client.baseUrl;
    final params = _baseDownloadParams(item);

    params['Static'] = 'false';
    params['videoCodec'] = quality.videoCodec;
    params['audioCodec'] = quality.audioCodec;
    if (quality.videoBitRate != null) {
      params['videoBitRate'] = quality.videoBitRate.toString();
    }
    if (quality.audioBitRate != null) {
      params['audioBitRate'] = quality.audioBitRate.toString();
    }
    if (quality.maxWidth != null) {
      params['maxWidth'] = quality.maxWidth.toString();
    }
    params['container'] = quality.container;
    if (quality.audioChannels != null) {
      params['audioChannels'] = quality.audioChannels.toString();
    }

    final query = _encodeQuery(params);
    return '$baseUrl/Videos/$itemId/stream?$query';
  }

  Future<AggregatedItem> _ensureFullItem(AggregatedItem item) async {
    if (item.mediaSources.isNotEmpty) return item;
    final data = await _client.itemsApi.getItem(item.id);
    return AggregatedItem(id: item.id, serverId: item.serverId, rawData: data);
  }

  Future<void> downloadItem(AggregatedItem item, {DownloadQuality quality = DownloadQuality.original}) async {
    if (isDownloading(item.id)) return;
    await _waitForDownloadSlot();

    String? savePath;

    if (!await _checkWifiPolicy()) {
      _activeDownloads[item.id] = DownloadProgress(
        itemId: item.id,
        fileName: item.name,
        error: 'WiFi-only mode enabled. Connect to WiFi to download.',
      );
      notifyListeners();
      return;
    }

    try {
      final fullItem = await _ensureFullItem(item);
      final estimatedSize =
          (fullItem.mediaSources.isNotEmpty ? fullItem.mediaSources.first['Size'] as int? : null) ?? 0;
      if (!await _checkStorageLimit(estimatedSize)) {
        _activeDownloads[item.id] = DownloadProgress(
          itemId: item.id,
          fileName: item.name,
          error: 'Storage limit reached. Free up space or increase the limit.',
        );
        notifyListeners();
        return;
      }
      final downloadsDir = await _storagePath.getOfflineRoot();
      final subFolder = _buildSubFolder(fullItem);
      final fileName = _buildFileName(fullItem, quality);
      final dir = Directory('${downloadsDir.path}/$subFolder');
      if (!await dir.exists()) await dir.create(recursive: true);
      savePath = '${dir.path}/$fileName';

      await _offlineRepo.upsertItem(DownloadedItemsCompanion(
        itemId: Value(item.id),
        serverId: Value(item.serverId),
        type: Value(item.type ?? 'Unknown'),
        name: Value(item.name),
        metadataJson: Value(jsonEncode(fullItem.rawData)),
        downloadStatus: const Value(1),
        qualityPreset: Value(quality.name),
        seriesId: Value(item.seriesId),
        seasonId: Value(item.seasonId),
        seriesName: Value(item.seriesName),
        seasonName: Value(fullItem.rawData['SeasonName'] as String?),
        indexNumber: Value(item.indexNumber),
        parentIndexNumber: Value(item.parentIndexNumber),
      ));

      final cancelToken = CancelToken();
      _cancelTokens[item.id] = cancelToken;

      final initialProgress = _initialProgressForQuality(quality);

      _activeDownloads[item.id] = DownloadProgress(
        itemId: item.id,
        fileName: fileName,
        progress: initialProgress,
      );
      await _notificationService.showProgress(
        itemName: item.name,
        progress: initialProgress,
        batchTotal: _totalQueued,
        batchCompleted: _completedCount,
      );
      notifyListeners();

      final url = _buildDownloadUrl(item.id, fullItem, quality);
      final requestOptions = Options(headers: _buildAuthHeaders());

      void onReceiveProgress(int received, int total) {
        final progress = _calculateProgress(
          received: received,
          total: total,
          estimatedSize: estimatedSize,
          quality: quality,
        );
        _activeDownloads[item.id] = DownloadProgress(
          itemId: item.id,
          fileName: fileName,
          progress: progress,
          bytesReceived: received,
        );
        _offlineRepo.updateDownloadStatus(
          item.id,
          1,
          progress: _storedProgress(progress),
        );
        _notificationService.showProgress(
          itemName: item.name,
          progress: progress,
          batchTotal: _totalQueued,
          batchCompleted: _completedCount,
        );
        notifyListeners();
      }

      Response? downloadResponse;
      try {
        downloadResponse = await _downloadWithHangGuard(
          url,
          savePath,
          options: requestOptions,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        );
      } on DioException catch (e) {
        if (!_shouldRetryWithFallback(fullItem, quality, e)) {
          rethrow;
        }

        var retrySucceeded = false;
        final fallbackUrls = _buildDownloadFallbackUrls(
          fullItem,
          primaryUrl: url,
        );
        for (final fallbackUrl in fallbackUrls) {
          try {
            downloadResponse = await _downloadWithHangGuard(
              fallbackUrl,
              savePath,
              options: requestOptions,
              cancelToken: cancelToken,
              onReceiveProgress: onReceiveProgress,
            );
            retrySucceeded = true;
            break;
          } on DioException {
            continue;
          }
        }

        if (!retrySucceeded) {
          rethrow;
        }
      }

      final savedFile = File(savePath);
      final fileSize = await savedFile.length();

      if (fileSize == 0) {
        throw StateError('Downloaded file is empty (0 bytes)');
      }

      if (fullItem.type == 'Book') {
        final corrected = await _correctBookExtension(
          savedFile, downloadResponse,
        );
        if (corrected != null) {
          savePath = corrected;
        }
      }

      final finalSize = await File(savePath).length();
      await _offlineRepo.setLocalFilePath(item.id, savePath, fileSize: finalSize);
      await _offlineRepo.updateDownloadStatus(item.id, 2);
      await _populateOfflineAssets(fullItem);

      if (Platform.isIOS) {
        await IosStorage.excludeFromBackup(savePath);
      }

      _activeDownloads[item.id] = DownloadProgress(
        itemId: item.id,
        fileName: fileName,
        progress: 1.0,
        isComplete: true,
      );
      _completedCount++;
      notifyListeners();

      if (_totalQueued <= 1 || _completedCount >= _totalQueued) {
        await _notificationService.showComplete(
          itemName: item.name,
          batchTotal: _totalQueued > 1 ? _completedCount : 0,
        );
      }

      await _downloadExternalSubtitles(fullItem, dir, fileName.replaceAll(RegExp(r'\.[^.]+$'), ''));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _activeDownloads.remove(item.id);
        final imageDir = await _storagePath.getImageCacheDir();
        if (savePath != null) {
          await _deleteFileArtifacts(savePath);
        }
        await _deleteItemImages(item.id, imageDir);
        await _offlineRepo.deleteItem(item.id);
        await _cleanupEpisodeContainers(item, imageDir);
        await _notificationService.dismiss();
      } else {
        final friendlyError = _friendlyDioError(e);
        if (savePath != null) {
          await _deleteFileArtifacts(savePath);
        }
        _activeDownloads[item.id] = DownloadProgress(
          itemId: item.id,
          fileName: item.name,
          error: friendlyError,
        );
        await _offlineRepo.updateDownloadStatus(item.id, 3, error: friendlyError);
        await _notificationService.showError(
          itemName: item.name,
          error: friendlyError,
        );
      }
    } catch (e) {
      if (savePath != null) {
        await _deleteFileArtifacts(savePath);
      }
      _activeDownloads[item.id] = DownloadProgress(
        itemId: item.id,
        fileName: item.name,
        error: e.toString(),
      );
      await _offlineRepo.updateDownloadStatus(item.id, 3, error: e.toString());
      await _notificationService.showError(
        itemName: item.name,
        error: e.toString(),
      );
    } finally {
      _cancelTokens.remove(item.id);
      notifyListeners();
    }
  }

  Future<void> downloadItems(List<AggregatedItem> items, {DownloadQuality quality = DownloadQuality.original}) async {
    _totalQueued = items.length;
    _completedCount = 0;
    notifyListeners();

    final concurrency = _concurrencyLimit();
    final queue = List<AggregatedItem>.from(items);
    final futures = <Future<void>>[];

    Future<void> processNext() async {
      while (queue.isNotEmpty) {
        final item = queue.removeAt(0);
        await downloadItem(item, quality: quality);
      }
    }

    for (var i = 0; i < concurrency; i++) {
      futures.add(processNext());
    }
    await Future.wait(futures);

    _totalQueued = 0;
    _completedCount = 0;
    await _notificationService.dismiss();
    notifyListeners();
  }

  Future<List<AggregatedItem>> _getAllEpisodesForSeries(String seriesId) async {
    final seasonsData = await _client.itemsApi.getSeasons(seriesId);
    final seasons = (seasonsData['Items'] as List?) ?? [];
    final allEpisodes = <AggregatedItem>[];
    for (final season in seasons) {
      final seasonId = season['Id'] as String;
      final episodesData = await _client.itemsApi.getEpisodes(seriesId, seasonId: seasonId);
      final episodes = (episodesData['Items'] as List?) ?? [];
      for (final raw in episodes) {
        final ep = raw as Map<String, dynamic>;
        allEpisodes.add(AggregatedItem(
          id: ep['Id'] as String,
          serverId: _client.baseUrl,
          rawData: ep,
        ));
      }
    }
    return allEpisodes;
  }

  Future<void> downloadSeries(String seriesId, {DownloadQuality quality = DownloadQuality.original}) async {
    final episodes = await _getAllEpisodesForSeries(seriesId);
    await downloadItems(episodes, quality: quality);
  }

  Future<bool> deleteDownloadedItems(List<AggregatedItem> items) async {
    var allSucceeded = true;
    final seenIds = <String>{};

    for (final item in items) {
      if (!seenIds.add(item.id)) {
        continue;
      }

      final succeeded = await deleteDownloadedFiles(item);
      if (!succeeded) {
        allSucceeded = false;
      }
    }

    return allSucceeded;
  }

  Future<bool> deleteDownloadedFiles(AggregatedItem item) async {
    try {
      final downloadsDir = await _storagePath.getOfflineRoot();
      final subFolder = _buildSubFolder(item);
      final targetDir = Directory('${downloadsDir.path}/$subFolder');
      final imageDir = await _storagePath.getImageCacheDir();

      switch (item.type) {
        case 'Movie':
          if (await targetDir.exists()) await targetDir.delete(recursive: true);
          await _deleteItemImages(item.id, imageDir);
          await _offlineRepo.deleteItem(item.id);
          return true;

        case 'Episode':
          await _deleteCandidateFileArtifacts(targetDir, item, downloadsDir);
          await _deleteItemImages(item.id, imageDir);
          await _offlineRepo.deleteItem(item.id);
          await _cleanupEpisodeContainers(item, imageDir);
          return true;

        case 'Audio':
        case 'AudioBook':
        case 'Book':
          await _deleteCandidateFileArtifacts(targetDir, item, downloadsDir);
          await _deleteItemImages(item.id, imageDir);
          await _offlineRepo.deleteItem(item.id);
          return true;

        case 'Season':
          final seasonImageIds = await _relatedImageIds(item);
          if (await targetDir.exists()) {
            await targetDir.delete(recursive: true);
            final seriesDir = targetDir.parent;
            if (await seriesDir.exists()) {
              final remaining = await seriesDir.list().length;
              if (remaining == 0) await seriesDir.delete();
            }
          }
          await _deleteImagesForIds(seasonImageIds, imageDir);
          await _offlineRepo.deleteSeasonItems(item.id);
          return true;

        case 'Series':
          final seriesImageIds = await _relatedImageIds(item);
          final seriesName = _sanitizePath(item.seriesName ?? item.name);
          final seriesDir = Directory('${downloadsDir.path}/TV/$seriesName');
          if (await seriesDir.exists()) await seriesDir.delete(recursive: true);
          await _deleteImagesForIds(seriesImageIds, imageDir);
          await _offlineRepo.deleteSeriesItems(item.id);
          return true;

        default:
          final defaultDir = Directory('${downloadsDir.path}/Other/${_sanitizePath(item.name)}');
          if (await defaultDir.exists()) await defaultDir.delete(recursive: true);
          await _deleteItemImages(item.id, imageDir);
          await _offlineRepo.deleteItem(item.id);
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteItemImages(String itemId, Directory imageDir) async {
    final dir = Directory('${imageDir.path}/$itemId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<bool> hasDownloadedFiles(AggregatedItem item) async {
    return _offlineRepo.isAvailableOffline(item.id);
  }

  Future<void> _downloadLyrics(AggregatedItem item) async {
    try {
      final data = await _client.itemsApi.getLyrics(item.id);
      final lyrics = data['Lyrics'] as List?;
      if (lyrics == null || lyrics.isEmpty) return;
      final imageDir = await _storagePath.getImageCacheDir();
      final itemDir = Directory('${imageDir.path}/${item.id}');
      if (!await itemDir.exists()) await itemDir.create(recursive: true);
      await File('${itemDir.path}/lyrics.json').writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _downloadImages(AggregatedItem item) async {
    try {
      final imageDir = await _storagePath.getImageCacheDir();
      final itemDir = Directory('${imageDir.path}/${item.id}');
      if (!await itemDir.exists()) await itemDir.create(recursive: true);

      final authOptions = Options(headers: _buildAuthHeaders());
      String? posterPath, backdropPath, logoPath;

      if (item.primaryImageTag != null) {
        final url = _client.imageApi.getPrimaryImageUrl(item.id, maxHeight: 500, tag: item.primaryImageTag);
        posterPath = '${itemDir.path}/poster.jpg';
        try {
          await _downloadDio.download(url, posterPath, options: authOptions);
        } catch (_) {
          posterPath = null;
        }
      }

      if (item.backdropImageTags.isNotEmpty) {
        final url = _client.imageApi.getBackdropImageUrl(item.id, maxWidth: 1920, tag: item.backdropImageTags.first);
        backdropPath = '${itemDir.path}/backdrop.jpg';
        try {
          await _downloadDio.download(url, backdropPath, options: authOptions);
        } catch (_) {
          backdropPath = null;
        }
      } else if (item.parentBackdropItemId != null && item.parentBackdropImageTags.isNotEmpty) {
        final url = _client.imageApi.getBackdropImageUrl(
          item.parentBackdropItemId!,
          maxWidth: 1920,
          tag: item.parentBackdropImageTags.first,
        );
        backdropPath = '${itemDir.path}/backdrop.jpg';
        try {
          await _downloadDio.download(url, backdropPath, options: authOptions);
        } catch (_) {
          backdropPath = null;
        }
      }

      if (item.logoImageTag != null) {
        final url = _client.imageApi.getLogoImageUrl(item.id, maxWidth: 500, tag: item.logoImageTag);
        logoPath = '${itemDir.path}/logo.png';
        try {
          await _downloadDio.download(url, logoPath, options: authOptions);
        } catch (_) {
          logoPath = null;
        }
      }

      await _offlineRepo.setImagePaths(
        item.id,
        poster: posterPath,
        backdrop: backdropPath,
        logo: logoPath,
      );
    } catch (_) {}
  }

  Future<void> _ensureParentContainers(AggregatedItem episode) async {
    if (episode.type != 'Episode') return;

    if (episode.seriesId != null) {
      final existing = await _offlineRepo.getItem(episode.seriesId!);
      if (existing == null) {
        try {
          final seriesData = await _client.itemsApi.getItem(episode.seriesId!);
          final seriesItem = AggregatedItem(id: episode.seriesId!, serverId: episode.serverId, rawData: seriesData);
          await _offlineRepo.upsertItem(DownloadedItemsCompanion(
            itemId: Value(episode.seriesId!),
            serverId: Value(episode.serverId),
            type: const Value('Series'),
            name: Value(seriesItem.name),
            metadataJson: Value(jsonEncode(seriesData)),
            downloadStatus: const Value(2),
            seriesName: Value(seriesItem.name),
          ));
          _downloadImages(seriesItem);
        } catch (_) {}
      }
    }

    if (episode.seasonId != null) {
      final existing = await _offlineRepo.getItem(episode.seasonId!);
      if (existing == null) {
        try {
          final seasonData = await _client.itemsApi.getItem(episode.seasonId!);
          final seasonItem = AggregatedItem(id: episode.seasonId!, serverId: episode.serverId, rawData: seasonData);
          await _offlineRepo.upsertItem(DownloadedItemsCompanion(
            itemId: Value(episode.seasonId!),
            serverId: Value(episode.serverId),
            type: const Value('Season'),
            name: Value(seasonItem.name),
            metadataJson: Value(jsonEncode(seasonData)),
            downloadStatus: const Value(2),
            seriesId: Value(episode.seriesId),
            seriesName: Value(episode.seriesName),
            seasonName: Value(seasonItem.name),
          ));
          _downloadImages(seasonItem);
        } catch (_) {}
      }
    }
  }

  Future<void> _downloadExternalSubtitles(AggregatedItem item, Directory dir, String fileNameBase) async {
    final mediaSources = item.mediaSources;
    if (mediaSources.isEmpty) return;
    final authOptions = Options(headers: _buildAuthHeaders());
    final streams = (mediaSources.first['MediaStreams'] as List?) ?? [];
    for (final stream in streams) {
      if (stream is! Map<String, dynamic>) continue;
      if (stream['Type'] != 'Subtitle') continue;
      final deliveryUrl = stream['DeliveryUrl'] as String?;
      if (deliveryUrl == null || deliveryUrl.isEmpty) continue;
      final isExternal = stream['IsExternal'] == true;
      final supportsExternal = stream['SupportsExternalStream'] == true;
      if (!isExternal && !supportsExternal) continue;
      final codec = (stream['Codec'] as String?) ?? 'srt';
      final index = stream['Index'] as int? ?? 0;
      final subPath = '${dir.path}/${fileNameBase}_sub_$index.$codec';
      final subUrl = '${_client.baseUrl}$deliveryUrl';
      try {
        await _downloadDio.download(subUrl, subPath, options: authOptions);
      } catch (_) {}
    }
  }

  void cancelDownload(String itemId) {
    _cancelTokens[itemId]?.cancel();
  }

  void cancelAll() {
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _notificationService.dismiss();
  }

  Future<void> clearAllDownloads() async {
    final allItems = await _offlineRepo.getItems();
    for (final item in allItems) {
      if (item.localFilePath != null) {
        final f = File(item.localFilePath!);
        if (await f.exists()) await f.delete();
      }
      await _offlineRepo.deleteItem(item.itemId);
    }
    final imageDir = await _storagePath.getImageCacheDir();
    if (await imageDir.exists()) await imageDir.delete(recursive: true);
  }

  Future<void> recoverIncompleteDownloads() async {
    final allItems = await _offlineRepo.getItems();

    for (final item in allItems) {
      if (item.downloadStatus == 1) {
        if (item.localFilePath != null) {
          final file = File(item.localFilePath!);
          if (await file.exists()) await file.delete();
        }
        if (item.metadataJson.isNotEmpty) {
          final qualityName = item.qualityPreset;
          final quality = DownloadQuality.values.firstWhere(
            (q) => q.name == qualityName,
            orElse: () => DownloadQuality.original,
          );
          final isStatic = !quality.isTranscoded;
          if (isStatic) {
            await _offlineRepo.updateDownloadStatus(item.itemId, 0);
          } else {
            await _offlineRepo.updateDownloadStatus(
              item.itemId, 3,
              error: 'Interrupted. Transcoded downloads cannot be resumed.',
            );
          }
        } else {
          await _offlineRepo.updateDownloadStatus(item.itemId, 3, error: 'Interrupted');
        }
      } else if (item.downloadStatus == 2) {
        if (item.localFilePath != null) {
          final file = File(item.localFilePath!);
          if (!await file.exists()) {
            await _offlineRepo.updateDownloadStatus(
              item.itemId, 3,
              error: 'File missing from disk',
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    cancelAll();
    _downloadDio.close();
    super.dispose();
  }
}
