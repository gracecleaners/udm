import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'failure.dart';

/// Single HTTP entry point for the app.
///
/// Every module talks to the API through `UdmApi`, never through `Dio` directly,
/// so base URL, headers, timeouts and error translation stay in one place.
class ApiClient {
  ApiClient({String? baseUrl, Dio? dio, Interceptor? interceptor})
      : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: AppConfig.requestTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                headers: const {'Accept': 'application/json'},
                responseType: ResponseType.json,
              ),
            ) {
    if (interceptor != null) this.dio.interceptors.add(interceptor);
  }

  final Dio dio;

  Future<T> guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw Failure.fromDio(error);
    }
  }

  void close() => dio.close(force: true);
}
