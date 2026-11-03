import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';
import 'failure.dart';

/// Single HTTP entry point for the app.
///
/// Every module talks to the API through `UdmApi`, never through `Dio` directly,
/// so base URL, headers, timeouts, the bearer token and error translation all
/// stay in one place. Passing a [tokenStore] is what turns the client from an
/// anonymous one into an authenticated one; there is no second client to keep
/// in sync.
class ApiClient {
  ApiClient({String? baseUrl, Dio? dio, TokenStore? tokenStore})
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        dio = dio ?? _buildDio(baseUrl ?? AppConfig.apiBaseUrl) {
    if (tokenStore != null) {
      auth = AuthInterceptor(
        store: tokenStore,
        retryClient: this.dio,
        // Refreshing must never travel through the interceptor it is fixing.
        refreshClient: _buildDio(this.baseUrl),
      );
      this.dio.interceptors.add(auth!);
    }
  }

  final String baseUrl;
  final Dio dio;

  /// Null on an anonymous client (tests, and the build before a session exists).
  AuthInterceptor? auth;

  static Dio _buildDio(String baseUrl) => Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: AppConfig.requestTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          headers: const {'Accept': 'application/json'},
          responseType: ResponseType.json,
        ),
      );

  Future<T> guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw Failure.fromDio(error);
    }
  }

  void close() => dio.close(force: true);
}
