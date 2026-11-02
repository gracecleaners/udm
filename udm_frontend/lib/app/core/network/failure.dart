import 'dart:io';

import 'package:dio/dio.dart';

/// Why a request failed, in terms the UI can act on.
enum FailureKind { offline, timeout, serverUnavailable, unauthorized, notFound, rejected, unexpected }

class Failure implements Exception {
  const Failure(this.kind, this.message, {this.fieldErrors = const {}, this.statusCode});

  final FailureKind kind;
  final String message;
  final Map<String, dynamic> fieldErrors;
  final int? statusCode;

  bool get isOffline => kind == FailureKind.offline || kind == FailureKind.timeout;

  /// The API returns `{detail, code, status, errors}` for every error; anything
  /// else (a proxy page, a bare string) still yields a readable message.
  factory Failure.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const Failure(
          FailureKind.timeout,
          'The connection took too long. Check your network and try again.',
        );
      case DioExceptionType.connectionError:
        return const Failure(
          FailureKind.offline,
          'You appear to be offline. Showing what was last downloaded.',
        );
      case DioExceptionType.cancel:
        return const Failure(FailureKind.unexpected, 'The request was cancelled.');
      case DioExceptionType.badCertificate:
        return const Failure(
          FailureKind.serverUnavailable,
          'The server certificate could not be verified.',
        );
      case DioExceptionType.badResponse:
        return Failure._fromResponse(error.response);
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return const Failure(
            FailureKind.offline,
            'No connection to the UDM service. Showing what was last downloaded.',
          );
        }
        return Failure(FailureKind.unexpected, error.message ?? 'Something went wrong.');
    }
  }

  factory Failure._fromResponse(Response? response) {
    final status = response?.statusCode ?? 0;
    final data = response?.data;
    final envelope = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final detail = envelope['detail'];
    final errors = envelope['errors'];
    final message = detail is String && detail.isNotEmpty
        ? detail
        : _statusMessage(status);

    return Failure(
      _kindFor(status),
      message,
      fieldErrors: errors is Map<String, dynamic> ? errors : const {},
      statusCode: status,
    );
  }

  static FailureKind _kindFor(int status) {
    if (status == 401 || status == 403) return FailureKind.unauthorized;
    if (status == 404) return FailureKind.notFound;
    if (status >= 400 && status < 500) return FailureKind.rejected;
    if (status >= 500) return FailureKind.serverUnavailable;
    return FailureKind.unexpected;
  }

  static String _statusMessage(int status) => switch (status) {
        400 => 'The request was rejected.',
        401 => 'Please sign in to continue.',
        403 => 'You do not have access to this.',
        404 => 'We could not find that.',
        429 => 'Too many requests. Please pause and try again shortly.',
        >= 500 => 'The service is temporarily unavailable.',
        _ => 'Something went wrong.',
      };

  @override
  String toString() => 'Failure($kind, $message)';
}
