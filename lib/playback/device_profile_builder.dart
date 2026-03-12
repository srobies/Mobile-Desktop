import '../util/platform_detection.dart';

class DeviceProfileBuilder {
  const DeviceProfileBuilder._();

  static Map<String, dynamic> build() {
    return {
      'Name': _profileName(),
      'MaxStaticBitrate': 200000000,
      'MaxStreamingBitrate': 200000000,
      'MusicStreamingTranscodingBitrate': 384000,
      'DirectPlayProfiles': _directPlayProfiles(),
      'TranscodingProfiles': _transcodingProfiles(),
      'ContainerProfiles': <Map<String, dynamic>>[],
      'CodecProfiles': _codecProfiles(),
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
  static const _audioCodecs = 'aac,ac3,eac3,dts,mp3,flac,vorbis,opus,truehd,pcm_s16le,pcm_s24le';
  static const _hlsAudioCodecs = 'aac,ac3,eac3,mp3';

  static List<Map<String, dynamic>> _directPlayProfiles() {
    return [
      {
        'Container': 'mp4,m4v,mkv,avi,mov',
        'Type': 'Video',
        'VideoCodec': _videoCodecs,
        'AudioCodec': _audioCodecs,
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
        'AudioCodec': 'aac,ac3,eac3,dts,mp3',
      },
      {
        'Container': 'wmv,asf',
        'Type': 'Video',
        'VideoCodec': 'vc1,mpeg4',
        'AudioCodec': 'aac,ac3,mp3',
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

  static List<Map<String, dynamic>> _transcodingProfiles() {
    return [
      {
        'Container': 'ts',
        'Type': 'Video',
        'VideoCodec': 'h264',
        'AudioCodec': _hlsAudioCodecs,
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
        'AudioCodec': _hlsAudioCodecs,
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

  static List<Map<String, dynamic>> _codecProfiles() {
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
