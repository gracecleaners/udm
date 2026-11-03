import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_store.dart';

/// Adds the bearer token to every request and, when the API says the access
/// token has expired, refreshes once and replays the original request.
///
/// The refresh call runs on its own bare [Dio] client: routing it through the
/// app client would re-enter this interceptor and loop on a rejected refresh.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.store, required this.retryClient, required this.refreshClient});

  static const String authorizationHeader = 'Authorization';

  /// `extra` flags understood by [onRequest] and [onError].
  ///
  /// `skipAuth` marks a call that is public by design (sign-in, registration),
  /// so an expired session there must not look like a token problem.
  static const String skipAuthKey = 'udm.skipAuth';
  static const String retriedKey = 'udm.retried';

  /// Set by the session layer so an unusable refresh token can clear app state
  /// and route the student back to a signed-out view.
  void Function()? onSessionExpired;

  final TokenStore store;

  /// The app's own client, used to replay a request after a refresh.
  final Dio retryClient;
  final Dio refreshClient;

  Completer<_Refresh>? _refreshing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await store.read();
      if (tokens != null) options.headers[authorizationHeader] = 'Bearer ${tokens.access}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isTokenProblem = err.response?.statusCode == 401 &&
        options.extra[skipAuthKey] != true &&
        options.extra[retriedKey] != true;
    if (!isTokenProblem) return handler.next(err);

    final outcome = await _refreshOnce();
    if (outcome.tokens != null) {
      options.headers[authorizationHeader] = 'Bearer ${outcome.tokens!.access}';
      options.extra[retriedKey] = true;
      try {
        return handler.resolve(await retryClient.fetch(options));
      } on DioException catch (retryError) {
        return handler.next(retryError);
      }
    }
    if (outcome.expired) {
      await store.clear();
      onSessionExpired?.call();
    }
    // A refresh that failed for network reasons says nothing about the session,
    // so the original 401 is reported and the student stays signed in.
    handler.next(err);
  }

  /// Concurrent 401s share one refresh: without this, several expired-tab
  /// requests would each post a refresh and the rotating token would blacklist
  /// the pair the earlier response just stored.
  Future<_Refresh> _refreshOnce() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;
    final completer = Completer<_Refresh>();
    _refreshing = completer;
    _performRefresh().then(
      (outcome) {
        _refreshing = null;
        completer.complete(outcome);
      },
      onError: (Object error, StackTrace stack) {
        _refreshing = null;
        completer.completeError(error, stack);
      },
    );
    return completer.future;
  }

  Future<_Refresh> _performRefresh() async {
    final previous = await store.read();
    if (previous == null) return const _Refresh(expired: true);
    try {
      final response = await refreshClient.post<dynamic>(
        '/auth/token/refresh/',
        data: {'refresh': previous.refresh},
      );
      final data = response.data;
      final access = data is Map<String, dynamic> ? data['access'] : null;
      if (access is! String) return const _Refresh(expired: true);
      // SimpleJWT rotates the refresh token when `ROTATE_REFRESH_TOKENS` is on;
      // keep the old one if a future build ever returns only the access token.
      final rotated = data['refresh'] is String ? data['refresh'] as String : previous.refresh;
      final tokens = StoredTokens(access: access, refresh: rotated);
      await store.write(tokens);
      return _Refresh(tokens: tokens);
    } on DioException catch (err) {
      final status = err.response?.statusCode;
      final rejected = switch (status) {
        400 || 401 || 403 => true,
        _ => err.type == DioExceptionType.badCertificate,
      };
      return _Refresh(expired: rejected);
    }
  }
}

class _Refresh {
  const _Refresh({this.tokens, this.expired = false});

  /// Null unless the refresh succeeded.
  final StoredTokens? tokens;

  /// True when the server refused the refresh token, so the session is over.
  final bool expired;
}
