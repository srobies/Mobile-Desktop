import 'dart:async';

import 'player_backend.dart';
import 'player_state.dart';
import 'queue_service.dart';

class PlaybackManager {
  PlayerBackend? _backend;
  final QueueService queueService = QueueService();
  final PlayerState state = PlayerState();
  final List<StreamSubscription> _streamSubs = [];

  PlayerBackend? get backend => _backend;

  void setBackend(PlayerBackend backend) {
    _disposeStreamSubs();
    _backend?.dispose();
    _backend = backend;
    _bindStreams(backend);
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

  Future<void> play() async {
    final item = queueService.currentItem;
    if (item == null || _backend == null) return;
    await _backend!.play(item);
  }

  Future<void> resume() async {
    await _backend?.resume();
  }

  Future<void> pause() async {
    await _backend?.pause();
  }

  Future<void> stop() async {
    await _backend?.stop();
    state.reset();
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
      queueService.next();
      await play();
    }
  }

  Future<void> previous() async {
    if (queueService.hasPrevious) {
      queueService.previous();
      await play();
    }
  }

  void dispose() {
    _disposeStreamSubs();
    _backend?.dispose();
    state.dispose();
  }
}
