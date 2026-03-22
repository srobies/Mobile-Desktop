import 'package:flutter/services.dart';

import 'cast_target.dart';

class NativeDlnaChannel {
  static const MethodChannel _channel = MethodChannel('com.moonfin/native_dlna');
  static const EventChannel _events = EventChannel('com.moonfin/native_dlna_events');

  const NativeDlnaChannel();

  Future<List<CastTarget>> discoverDlnaTargets() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('discoverDlnaTargets');
    if (raw == null) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .map(
          (entry) => CastTarget(
            id: entry['id'] as String? ?? '',
            kind: CastTargetKind.dlna,
            title: entry['title'] as String? ?? 'DLNA Device',
            subtitle: entry['subtitle'] as String? ?? '',
          ),
        )
        .where((target) => target.id.isNotEmpty)
        .toList();
  }

  Future<void> playToDlnaDevice({
    required String targetId,
    required String streamUrl,
    required String title,
    int? startPositionTicks,
  }) async {
    await _channel.invokeMethod<void>('playToDlnaDevice', {
      'targetId': targetId,
      'streamUrl': streamUrl,
      'title': title,
      if (startPositionTicks != null) 'startPositionTicks': startPositionTicks,
    });
  }

  Future<void> pauseDlna() async {
    await _channel.invokeMethod<void>('pauseDlna');
  }

  Future<void> playDlna() async {
    await _channel.invokeMethod<void>('playDlna');
  }

  Future<void> seekDlna({required int positionTicks}) async {
    await _channel.invokeMethod<void>('seekDlna', {
      'positionTicks': positionTicks,
    });
  }

  Future<void> stopDlna() async {
    await _channel.invokeMethod<void>('stopDlna');
  }

  Future<double?> getDlnaVolume() async {
    return _channel.invokeMethod<double>('getDlnaVolume');
  }

  Future<void> setDlnaVolume({required double volume}) async {
    await _channel.invokeMethod<void>('setDlnaVolume', {
      'volume': volume,
    });
  }

  Stream<Map<String, dynamic>> dlnaEventStream() {
    return _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.cast<String, dynamic>();
      }
      return <String, dynamic>{};
    }).where((event) => event.isNotEmpty);
  }
}
