import '../models/article.dart';
import '../models/devotional.dart';
import '../providers/udm_api.dart';

/// Reads individual content items. Offline storage of opened lessons arrives
/// with Phase 3, so this stays a thin pass-through to the API today.
class ContentRepository {
  ContentRepository(this._api);

  final UdmApi _api;

  Future<Devotional> devotional(String id) => _api.devotion(id);

  Future<Article> article(String id) => _api.article(id);
}
