import 'package:flutter/foundation.dart';
import 'package:server_core/server_core.dart';

import '../models/aggregated_item.dart';

class BreadcrumbEntry {
  final String id;
  final String name;

  const BreadcrumbEntry({required this.id, required this.name});
}

enum FolderBrowseState { loading, ready, error }

class FolderBrowseViewModel extends ChangeNotifier {
  final MediaServerClient _client;

  static const _pageSize = 100;
  static const _fields = 'ProductionYear,ImageTags,BackdropImageTags,ChildCount';

  FolderBrowseViewModel(this._client);

  ImageApi get imageApi => _client.imageApi;

  FolderBrowseState _state = FolderBrowseState.loading;
  FolderBrowseState get state => _state;

  List<AggregatedItem> _items = const [];
  List<AggregatedItem> get items => _items;

  int _totalCount = 0;
  bool get hasMore => _items.length < _totalCount;

  bool _loadingMore = false;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  final List<BreadcrumbEntry> _breadcrumbs = [];
  List<BreadcrumbEntry> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  String get currentFolderId =>
      _breadcrumbs.isNotEmpty ? _breadcrumbs.last.id : '';

  Future<void> loadFolder(String folderId) async {
    _state = FolderBrowseState.loading;
    _items = const [];
    _totalCount = 0;
    notifyListeners();

    try {
      if (!_breadcrumbs.any((b) => b.id == folderId)) {
        final folderData = await _client.itemsApi.getItem(folderId);
        final folderName = folderData['Name'] as String? ?? '';
        _breadcrumbs.add(BreadcrumbEntry(id: folderId, name: folderName));
      }

      await _fetchPage(folderId, 0);
      _state = FolderBrowseState.ready;
    } catch (e) {
      _errorMessage = e.toString();
      _state = FolderBrowseState.error;
    }
    notifyListeners();
  }

  Future<void> navigateTo(int breadcrumbIndex) async {
    if (breadcrumbIndex < 0 || breadcrumbIndex >= _breadcrumbs.length) return;
    final target = _breadcrumbs[breadcrumbIndex];
    _breadcrumbs.removeRange(breadcrumbIndex + 1, _breadcrumbs.length);
    await loadFolder(target.id);
  }

  Future<void> enterFolder(AggregatedItem item) async {
    await loadFolder(item.id);
  }

  Future<void> loadMore() async {
    if (_loadingMore || !hasMore) return;
    _loadingMore = true;
    notifyListeners();

    try {
      await _fetchPage(currentFolderId, _items.length);
    } catch (_) {}

    _loadingMore = false;
    notifyListeners();
  }

  Future<void> _fetchPage(String parentId, int startIndex) async {
    final response = await _client.itemsApi.getItems(
      parentId: parentId,
      recursive: false,
      sortBy: 'IsFolder,SortName',
      sortOrder: 'Ascending',
      startIndex: startIndex,
      limit: _pageSize,
      fields: _fields,
      enableTotalRecordCount: true,
    );

    final rawItems = (response['Items'] as List?) ?? [];
    _totalCount = response['TotalRecordCount'] as int? ?? rawItems.length;

    final mapped = rawItems.cast<Map<String, dynamic>>().map((raw) {
      return AggregatedItem(
        id: raw['Id'] as String,
        serverId: _client.baseUrl,
        rawData: raw,
      );
    }).toList();

    if (startIndex == 0) {
      _items = mapped;
    } else {
      _items = [..._items, ...mapped];
    }
  }

  bool isNavigableFolder(AggregatedItem item) {
    final type = item.type;
    return type == 'Folder' ||
        type == 'CollectionFolder' ||
        type == 'UserView' ||
        type == 'BoxSet' ||
        type == 'MusicAlbum' ||
        type == 'Season' ||
        type == 'Series' ||
        type == 'PhotoAlbum' ||
        type == 'Playlist';
  }
}
