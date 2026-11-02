import '../../core/network/api_client.dart';
import '../models/article.dart';
import '../models/devotional.dart';
import '../models/home_payload.dart';

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

  Map<String, dynamic> _json(dynamic response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw StateError('Expected a JSON object from the API.');
  }
}
