import 'package:flutter/services.dart';

class NativeAirPlayChannel {
  static const _channel = MethodChannel('com.moonfin/native_cast');
  static const _events = EventChannel('com.moonfin/native_airplay_events');

  const NativeAirPlayChannel();

  Future<void> pauseAirPlay() async {
    await _channel.invokeMethod<void>('pauseAirPlay');
  }

  Future<void> playAirPlay() async {
    await _channel.invokeMethod<void>('playAirPlay');
  }

  Future<void> seekAirPlay({required int positionTicks}) async {
    await _channel.invokeMethod<void>('seekAirPlay', {'positionTicks': positionTicks});
  }

  Future<void> stopAirPlay() async {
    await _channel.invokeMethod<void>('stopAirPlay');
  }

  Future<void> loadAirPlay({
    required String url,
    String? title,
    int positionTicks = 0,
  }) async {
    await _channel.invokeMethod<void>('loadAirPlay', {
      'url': url,
      if (title != null) 'title': title,
      'positionTicks': positionTicks,
    });
  }

  Future<void> updateAirPlayPlaybackState({
    required bool isPlaying,
    required bool isBuffering,
    required int positionTicks,
  }) async {
    await _channel.invokeMethod<void>('updateAirPlayPlaybackState', {
      'isPlaying': isPlaying,
      'isBuffering': isBuffering,
      'positionTicks': positionTicks,
    });
  }

  Stream<Map<String, dynamic>> airPlayEventStream() {
    return _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.cast<String, dynamic>();
      }
      return <String, dynamic>{};
    }).where((event) => event.isNotEmpty);
  }
}
