import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

class JellyfinAdminLiveTvApi implements AdminLiveTvApi {
  final Dio _dio;

  JellyfinAdminLiveTvApi(this._dio);

  @override
  Future<List<Map<String, dynamic>>> getTunerHosts() async {
    final response = await _getWithFallback([
      '/LiveTv/TunerHosts',
      '/LiveTv/Tuners',
    ]);
    return _asList(response.data);
  }

  @override
  Future<Map<String, dynamic>> addTunerHost(Map<String, dynamic> tunerInfo) async {
    final response = await _postWithFallback([
      '/LiveTv/TunerHosts',
      '/LiveTv/Tuners',
    ], data: tunerInfo);
    return _asMap(response.data);
  }

  @override
  Future<void> removeTunerHost(String id) async {
    await _deleteWithFallback([
      '/LiveTv/TunerHosts/$id',
      '/LiveTv/Tuners/$id',
    ]);
  }

  @override
  Future<void> resetTuner(String tunerId) async {
    await _postWithFallback([
      '/LiveTv/TunerHosts/$tunerId/Reset',
      '/LiveTv/Tuners/$tunerId/Reset',
      '/LiveTv/Tuners/$tunerId/ResetTuner',
    ]);
  }

  @override
  Future<List<Map<String, dynamic>>> discoverTuners() async {
    final response = await _getWithFallback([
      '/LiveTv/Tuners/Discover',
      '/LiveTv/TunerHosts/Discover',
    ]);
    return _asList(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getListingProviders() async {
    final response = await _getWithFallback([
      '/LiveTv/ListingProviders',
      '/LiveTv/Listings/Providers',
    ]);
    return _asList(response.data);
  }

  @override
  Future<Map<String, dynamic>> addListingProvider(Map<String, dynamic> providerInfo) async {
    final response = await _postWithFallback([
      '/LiveTv/ListingProviders',
      '/LiveTv/Listings/Providers',
    ], data: providerInfo);
    return _asMap(response.data);
  }

  @override
  Future<void> removeListingProvider(String id) async {
    await _deleteWithFallback([
      '/LiveTv/ListingProviders/$id',
      '/LiveTv/Listings/Providers/$id',
    ]);
  }

  @override
  Future<void> setChannelMappings(Map<String, dynamic> mappings) async {
    await _postWithFallback([
      '/LiveTv/ChannelMappings',
      '/LiveTv/Channels/Mappings',
    ], data: mappings);
  }

  @override
  Future<Map<String, dynamic>> getLiveTvConfiguration() async {
    final response = await _getWithFallback([
      '/LiveTv/Configuration',
      '/LiveTv/Config',
    ]);
    return _asMap(response.data);
  }

  @override
  Future<void> updateLiveTvConfiguration(Map<String, dynamic> config) async {
    await _postWithFallback([
      '/LiveTv/Configuration',
      '/LiveTv/Config',
    ], data: config);
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (data is Map<String, dynamic>) {
      final items = data['Items'] ?? data['items'] ?? data['TunerHosts'] ?? data['Providers'];
      if (items is List) {
        return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return const {};
  }

  Future<Response<dynamic>> _getWithFallback(List<String> paths) async {
    DioException? lastDioError;
    for (final path in paths) {
      try {
        return await _dio.get(path);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404 || status == 405 || status == 501) {
          lastDioError = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastDioError ?? StateError('No live TV endpoint responded');
  }

  Future<Response<dynamic>> _postWithFallback(
    List<String> paths, {
    Object? data,
  }) async {
    DioException? lastDioError;
    for (final path in paths) {
      try {
        return await _dio.post(path, data: data);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404 || status == 405 || status == 501) {
          lastDioError = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastDioError ?? StateError('No live TV endpoint responded');
  }

  Future<void> _deleteWithFallback(List<String> paths) async {
    DioException? lastDioError;
    for (final path in paths) {
      try {
        await _dio.delete(path);
        return;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404 || status == 405 || status == 501) {
          lastDioError = e;
          continue;
        }
        rethrow;
      }
    }
    throw lastDioError ?? StateError('No live TV endpoint responded');
  }
}
