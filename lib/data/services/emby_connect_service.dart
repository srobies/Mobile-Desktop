import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

class EmbyConnectService {
  static const _connectBaseUrl = 'https://connect.emby.media/service';

  final DeviceInfo _deviceInfo;
  final Dio _dio;

  EmbyConnectService({required DeviceInfo deviceInfo})
    : _deviceInfo = deviceInfo,
      _dio = Dio(
        BaseOptions(
          baseUrl: _connectBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

  String get _applicationHeader =>
      '${_deviceInfo.appName}/${_deviceInfo.appVersion}';

  Future<EmbyConnectAuthResult> authenticate({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/user/authenticate',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Application': _applicationHeader,
        },
      ),
      data: {'nameOrEmail': username, 'rawpw': password},
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Invalid Emby Connect response');
    }
    return EmbyConnectAuthResult.fromJson(data);
  }

  Future<List<EmbyConnectServer>> getServers({
    required String connectUserId,
    required String connectAccessToken,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/servers',
      queryParameters: {'userId': connectUserId},
      options: Options(
        headers: {
          'X-Application': _applicationHeader,
          'X-Connect-UserToken': connectAccessToken,
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Invalid Emby Connect servers response');
    }

    return data
      .whereType<Map>()
      .map((entry) => EmbyConnectServer.fromJson(Map<String, dynamic>.from(entry)))
      .toList(growable: false);
  }

  Future<EmbyConnectExchangeResult> exchange({
    required String serverAddress,
    required String connectUserId,
    required String accessKey,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: serverAddress,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/Connect/Exchange',
        queryParameters: {'format': 'json', 'ConnectUserId': connectUserId},
        options: Options(
          headers: {
            'X-Emby-Token': accessKey,
            'X-Emby-Authorization':
                'Emby Client="${_deviceInfo.appName}", '
                'Device="${_deviceInfo.name}", '
                'DeviceId="${_deviceInfo.id}", '
                'Version="${_deviceInfo.appVersion}"',
          },
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const FormatException('Invalid exchange response');
      }

      return EmbyConnectExchangeResult.fromJson(data);
    } finally {
      dio.close();
    }
  }
}

class EmbyConnectAuthResult {
  final String accessToken;
  final EmbyConnectUser user;

  const EmbyConnectAuthResult({required this.accessToken, required this.user});

  factory EmbyConnectAuthResult.fromJson(Map<String, dynamic> json) {
    return EmbyConnectAuthResult(
      accessToken: json['AccessToken'] as String? ?? '',
      user: EmbyConnectUser.fromJson(
        (json['User'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }
}

class EmbyConnectUser {
  final String id;
  final String name;

  const EmbyConnectUser({required this.id, required this.name});

  factory EmbyConnectUser.fromJson(Map<String, dynamic> json) {
    return EmbyConnectUser(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
    );
  }
}

class EmbyConnectServer {
  final String accessKey;
  final String systemId;
  final String name;
  final String? url;
  final String? localAddress;

  const EmbyConnectServer({
    required this.accessKey,
    required this.systemId,
    required this.name,
    required this.url,
    required this.localAddress,
  });

  List<String> get candidateAddresses {
    final seen = <String>{};
    final addresses = <String>[];
    for (final candidate in [url, localAddress]) {
      final trimmed = candidate?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        continue;
      }
      if (seen.add(trimmed.toLowerCase())) {
        addresses.add(trimmed);
      }
    }
    return addresses;
  }

  factory EmbyConnectServer.fromJson(Map<String, dynamic> json) {
    return EmbyConnectServer(
      accessKey: json['AccessKey'] as String? ?? '',
      systemId: json['SystemId'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      url: json['Url'] as String?,
      localAddress: json['LocalAddress'] as String?,
    );
  }
}

class EmbyConnectExchangeResult {
  final String localUserId;
  final String accessToken;

  const EmbyConnectExchangeResult({
    required this.localUserId,
    required this.accessToken,
  });

  factory EmbyConnectExchangeResult.fromJson(Map<String, dynamic> json) {
    return EmbyConnectExchangeResult(
      localUserId: json['LocalUserId'] as String? ?? '',
      accessToken: json['AccessToken'] as String? ?? '',
    );
  }
}
