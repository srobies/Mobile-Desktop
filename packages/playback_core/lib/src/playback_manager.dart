import 'dart:async';

import 'media_stream_resolver.dart';
import 'player_backend.dart';
import 'player_service.dart';
import 'player_state.dart';
import 'queue_service.dart';
import 'stream_resolution_result.dart';

class PlaybackManager {
  PlayerBackend? _backend;
  MediaStreamResolver? _resolver;
  PlayerService? _service;
  final QueueService queueService = QueueService();
  final PlayerState state = PlayerState();
  final List<StreamSubscription> _streamSubs = [];
  Timer? _progressTimer;
  StreamResolutionResult? _currentResolution;

  PlayerBackend? get backend => _backend;
  StreamResolutionResult? get currentResolution => _currentResolution;

  void setBackend(PlayerBackend backend) {
    _disposeStreamSubs();
    _backend?.dispose();
    _backend = backend;
    _bindStreams(backend);
  }

  void setResolver(MediaStreamResolver resolver) {
    _resolver = resolver;
  }

  void setPlayerService(PlayerService service) {
    _service = service;
  }

  void _bindStreams(PlayerBackend backend) {
    _streamSubs.addAll([
      backend.positionStream.listen(state.setPosition),
      backend.durationStream.listen(state.setDuration),
      backend.playingStream.listen(state.setPlaying),
      backend.bufferingStream.listen(state.setBuffering),
    ]);
  }

  void _disposeStreamSubs() {
    for (final sub in _streamSubs) {
      sub.cancel();
    }
    _streamSubs.clear();
  }

  Future<void> playItems(
    List<dynamic> items, {
    int startIndex = 0,
    Duration startPosition = Duration.zero,
  }) async {
    await _stopAndReportCurrent();
    queueService.setQueue(items, startIndex: startIndex);
    await _playCurrentItem(startPosition: startPosition);
  }

  Future<void> _playCurrentItem({
    Duration startPosition = Duration.zero,
  }) async {
    final item = queueService.currentItem;
    if (item == null || _backend == null) return;

    if (_resolver == null) {
      throw StateError('No MediaStreamResolver configured');
    }

    final startTicks =
        startPosition > Duration.zero ? startPosition.inMicroseconds * 10 : null;

    final profile = _backend!.getDeviceProfile();
    final maxBitrate = profile['MaxStreamingBitrate'] as int?;

    final resolution = await _resolver!.resolve(
      item,
      deviceProfile: profile,
      maxStreamingBitrate: maxBitrate,
      startTimeTicks: startTicks,
    );
    _currentResolution = resolution;

    await _backend!.play(resolution.streamUrl);

    if (startTicks != null) {
      await _backend!.seekTo(startPosition);
    }

    _service?.onPlaybackStart(
      item,
      resolution,
      positionTicks: startTicks,
    );
    _startProgressTimer();
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final item = queueService.currentItem;
      final resolution = _currentResolution;
      if (item == null || resolution == null) return;
      _service?.onPlaybackProgress(
        item,
        resolution,
        state.position,
        isPaused: !state.isPlaying,
      );
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> play() async {
    await _stopAndReportCurrent();
    await _playCurrentItem();
  }

  Future<void> resume() async {
    await _backend?.resume();
  }

  Future<void> pause() async {
    await _backend?.pause();
  }

  Future<void> stop() async {
    await _stopAndReportCurrent();
  }

  Future<void> seekTo(Duration position) async {
    await _backend?.seekTo(position);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _backend?.setPlaybackSpeed(speed);
    state.setPlaybackSpeed(speed);
  }

  Future<void> next() async {
    if (queueService.hasNext) {
      await _stopAndReportCurrent();
      queueService.next();
      await _playCurrentItem();
    }
  }

  Future<void> previous() async {
    if (queueService.hasPrevious) {
      await _stopAndReportCurrent();
      queueService.previous();
      await _playCurrentItem();
    }
  }

  Future<void> _stopAndReportCurrent() async {
    _stopProgressTimer();
    final item = queueService.currentItem;
    final resolution = _currentResolution;
    if (item != null && resolution != null) {
      _service?.onPlaybackStop(item, resolution, state.position);
    }
    _currentResolution = null;
    await _backend?.stop();
    state.reset();
  }

  void dispose() {
    _stopProgressTimer();
    _disposeStreamSubs();
    _backend?.dispose();
    _service?.dispose();
    state.dispose();
  }
}
