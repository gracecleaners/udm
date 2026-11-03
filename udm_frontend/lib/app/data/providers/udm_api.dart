import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/auth_interceptor.dart';
import '../models/article.dart';
import '../models/devotional.dart';
import '../models/home_payload.dart';
import '../models/session.dart';
import '../models/user_profile.dart';

/// Typed surface of the UDM v1 API. Controllers never call Dio directly.
class UdmApi {
  UdmApi(this._client);

  final ApiClient _client;

  Future<HomePayload> home() => _client.guard(() async {
        final response = await _client.dio.get<dynamic>('/home/');
        return HomePayload.fromJson(_json(response));
      });

  Future<Devotional> devotion(String id) => _client.guard(() async {
        final response = await _client.dio.get<dynamic>('/devotions/$id/');
        return Devotional.fromJson(_json(response));
      });

  Future<Article> article(String id) => _client.guard(() async {
        final response = await _client.dio.get<dynamic>('/articles/$id/');
        return Article.fromJson(_json(response));
      });

  /// Sign-in and registration are public endpoints: an expired token sitting in
  /// storage must not turn them into a refresh-and-retry loop.
  Future<Session> signIn({required String email, required String password}) =>
      _session('/auth/token/', {'email': email, 'password': password});

  Future<Session> register({
    required String email,
    required String password,
    required String fullName,
  }) =>
      _session('/auth/register/', {'email': email, 'password': password, 'full_name': fullName});

  /// Revokes the refresh token server-side. Called with the stored token, which
  /// is why logout still needs the bearer header.
  Future<void> signOut({required String refresh}) => _client.guard(() async {
        await _client.dio.post<dynamic>('/auth/token/logout/', data: {'refresh': refresh});
      });

  Future<UserProfile> profile() => _client.guard(() async {
        final response = await _client.dio.get<dynamic>('/users/me/');
        return UserProfile.fromJson(_json(response));
      });

  /// Partial update, so a form that only changed two fields does not blank the
  /// rest by omission.
  Future<UserProfile> updateProfile(Map<String, dynamic> changes) => _client.guard(() async {
        final response = await _client.dio.patch<dynamic>('/users/me/', data: changes);
        return UserProfile.fromJson(_json(response));
      });

  Future<void> markComplete({
    required String kind,
    required String contentId,
    String? note,
  }) =>
      _client.guard(() async {
        await _client.dio.post<dynamic>(
          '/progress/',
          data: {'kind': kind, 'content_id': contentId, 'note': ?note},
        );
      });

  Future<Session> _session(String path, Map<String, dynamic> body) => _client.guard(() async {
        final response = await _client.dio.post<dynamic>(
          path,
          data: body,
          options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
        );
        return Session.fromJson(_json(response));
      });

  Map<String, dynamic> _json(dynamic response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw StateError('Expected a JSON object from the API.');
  }
}
