import '../util/platform_detection.dart';

class DeviceProfileBuilder {
  const DeviceProfileBuilder._();

  static Map<String, dynamic> build({
    int? maxBitrateMbps,
    bool ac3Enabled = true,
    bool stereoDownmix = false,
  }) {
    final bitrate = (maxBitrateMbps ?? 200) * 1000000;
    return {
      'Name': _profileName(),
      'MaxStaticBitrate': bitrate,
      'MaxStreamingBitrate': bitrate,
      'MusicStreamingTranscodingBitrate': 384000,
      'DirectPlayProfiles': _directPlayProfiles(ac3Enabled: ac3Enabled),
      'TranscodingProfiles': _transcodingProfiles(ac3Enabled: ac3Enabled),
      'ContainerProfiles': <Map<String, dynamic>>[],
      'CodecProfiles': _codecProfiles(stereoDownmix: stereoDownmix),
      'SubtitleProfiles': _subtitleProfiles(),
    };
  }

  static String _profileName() {
    if (PlatformDetection.isAndroid) return 'Moonfin Android';
    if (PlatformDetection.isIOS) return 'Moonfin iOS';
    if (PlatformDetection.isMacOS) return 'Moonfin macOS';
    if (PlatformDetection.isWindows) return 'Moonfin Windows';
    if (PlatformDetection.isLinux) return 'Moonfin Linux';
    return 'Moonfin';
  }

  static const _videoCodecs = 'h264,hevc,vp8,vp9,av1,mpeg2video,mpeg4,vc1';

  static String _audioCodecs({required bool ac3Enabled}) {
    return [
      'aac',
      if (ac3Enabled) ...['ac3', 'eac3'],
      'mp3', 'flac', 'vorbis', 'opus', 'dts', 'truehd',
      'pcm_s16le', 'pcm_s24le',
    ].join(',');
  }

  static String _hlsAudioCodecs({required bool ac3Enabled}) {
    return [
      'aac',
      if (ac3Enabled) ...['ac3', 'eac3'],
      'mp3',
    ].join(',');
  }

  static List<Map<String, dynamic>> _directPlayProfiles({
    required bool ac3Enabled,
  }) {
    final audio = _audioCodecs(ac3Enabled: ac3Enabled);
    return [
      {
        'Container': 'mp4,m4v,mkv,avi,mov',
        'Type': 'Video',
        'VideoCodec': _videoCodecs,
        'AudioCodec': audio,
      },
      {
        'Container': 'webm',
        'Type': 'Video',
        'VideoCodec': 'vp8,vp9,av1',
        'AudioCodec': 'vorbis,opus',
      },
      {
        'Container': 'ts,m2ts,mpegts',
        'Type': 'Video',
        'VideoCodec': 'h264,hevc,mpeg2video',
        'AudioCodec': ac3Enabled
            ? 'aac,ac3,eac3,dts,mp3'
            : 'aac,dts,mp3',
      },
      {
        'Container': 'wmv,asf',
        'Type': 'Video',
        'VideoCodec': 'vc1,mpeg4',
        'AudioCodec': ac3Enabled ? 'aac,ac3,mp3' : 'aac,mp3',
      },
      {
        'Container': 'mp3',
        'Type': 'Audio',
      },
      {
        'Container': 'aac',
        'Type': 'Audio',
      },
      {
        'Container': 'flac',
        'Type': 'Audio',
      },
      {
        'Container': 'ogg',
        'Type': 'Audio',
        'AudioCodec': 'vorbis,opus',
      },
      {
        'Container': 'wav',
        'Type': 'Audio',
      },
    ];
  }

  static List<Map<String, dynamic>> _transcodingProfiles({
    required bool ac3Enabled,
  }) {
    final hlsAudio = _hlsAudioCodecs(ac3Enabled: ac3Enabled);
    return [
      {
        'Container': 'ts',
        'Type': 'Video',
        'VideoCodec': 'h264',
        'AudioCodec': hlsAudio,
        'Protocol': 'hls',
        'Context': 'Streaming',
        'CopyTimestamps': false,
        'EnableSubtitlesInManifest': true,
        'BreakOnNonKeyFrames': false,
      },
      {
        'Container': 'mp4',
        'Type': 'Video',
        'VideoCodec': 'h264',
        'AudioCodec': hlsAudio,
        'Protocol': 'hls',
        'Context': 'Streaming',
        'CopyTimestamps': false,
        'EnableSubtitlesInManifest': true,
        'BreakOnNonKeyFrames': false,
      },
      {
        'Container': 'mp3',
        'Type': 'Audio',
        'AudioCodec': 'mp3',
        'Protocol': 'http',
        'Context': 'Streaming',
      },
    ];
  }

  static List<Map<String, dynamic>> _codecProfiles({
    required bool stereoDownmix,
  }) {
    return [
      {
        'Type': 'Video',
        'Codec': 'h264',
        'Conditions': [
          {
            'Condition': 'LessThanEqual',
            'Property': 'VideoLevel',
            'Value': '52',
            'IsRequired': false,
          },
          {
            'Condition': 'EqualsAny',
            'Property': 'VideoProfile',
            'Value': 'high,main,baseline,constrained baseline,high 10',
            'IsRequired': false,
          },
        ],
      },
      {
        'Type': 'Video',
        'Codec': 'hevc',
        'Conditions': [
          {
            'Condition': 'LessThanEqual',
            'Property': 'VideoLevel',
            'Value': '183',
            'IsRequired': false,
          },
          {
            'Condition': 'EqualsAny',
            'Property': 'VideoProfile',
            'Value': 'main,main 10',
            'IsRequired': false,
          },
        ],
      },
      {
        'Type': 'Video',
        'Codec': 'vp9',
        'Conditions': [
          {
            'Condition': 'LessThanEqual',
            'Property': 'VideoLevel',
            'Value': '62',
            'IsRequired': false,
          },
        ],
      },
      if (stereoDownmix)
        {
          'Type': 'VideoAudio',
          'Conditions': [
            {
              'Condition': 'LessThanEqual',
              'Property': 'AudioChannels',
              'Value': '2',
              'IsRequired': false,
            },
          ],
        },
    ];
  }

  static List<Map<String, dynamic>> _subtitleProfiles() {
    return [
      {'Format': 'srt', 'Method': 'External'},
      {'Format': 'srt', 'Method': 'Embed'},
      {'Format': 'ass', 'Method': 'Embed'},
      {'Format': 'ssa', 'Method': 'Embed'},
      {'Format': 'vtt', 'Method': 'External'},
      {'Format': 'sub', 'Method': 'Embed'},
      {'Format': 'pgs', 'Method': 'Embed'},
      {'Format': 'pgssub', 'Method': 'Embed'},
      {'Format': 'dvbsub', 'Method': 'Embed'},
      {'Format': 'dvdsub', 'Method': 'Embed'},
    ];
  }
}
