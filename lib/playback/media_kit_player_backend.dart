import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:playback_core/playback_core.dart';

import '../preference/user_preferences.dart';
import '../preference/preference_constants.dart';
import 'device_profile_builder.dart';

class MediaKitPlayerBackend implements PlayerBackend {
  final Player _player;
  final VideoController _videoController;
  final UserPreferences _prefs;

  MediaKitPlayerBackend._(this._player, this._videoController, this._prefs);

  factory MediaKitPlayerBackend(UserPreferences prefs) {
    final player = Player();
    final controller = VideoController(player);
    return MediaKitPlayerBackend._(player, controller, prefs);
  }

  VideoController get videoController => _videoController;

  @override
  Map<String, dynamic> getDeviceProfile() {
    final maxBitrate = int.tryParse(_prefs.get(UserPreferences.maxBitrate));
    final ac3Enabled = _prefs.get(UserPreferences.ac3Enabled);
    final stereoDownmix =
        _prefs.get(UserPreferences.audioBehavior) == AudioBehavior.downmixToStereo;

    return DeviceProfileBuilder.build(
      maxBitrateMbps: maxBitrate,
      ac3Enabled: ac3Enabled,
      stereoDownmix: stereoDownmix,
    );
  }

  @override
  Future<void> play(dynamic mediaItem) async {
    final url = mediaItem as String;
    await _player.open(Media(url));
  }

  @override
  Future<void> resume() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  @override
  Duration get position => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  bool get isBuffering => _player.state.buffering;

  @override
  double get playbackSpeed => _player.state.rate;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setRate(speed);
  }

  @override
  Future<void> setAudioTrack(int index) async {
    final tracks = _player.state.tracks.audio;
    if (index >= 0 && index < tracks.length) {
      await _player.setAudioTrack(tracks[index]);
    }
  }

  @override
  Future<void> setSubtitleTrack(int index) async {
    final tracks = _player.state.tracks.subtitle;
    if (index >= 0 && index < tracks.length) {
      await _player.setSubtitleTrack(tracks[index]);
    }
  }

  @override
  Future<void> disableSubtitleTrack() async {
    await _player.setSubtitleTrack(SubtitleTrack.no());
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0, 100));
  }

  @override
  void dispose() {
    _player.dispose();
  }
}
