import '../models/article.dart';
import '../models/content_kind.dart';
import '../models/devotional.dart';
import '../models/new_believer_resource.dart';
import '../models/resource_step.dart';
import '../providers/udm_api.dart';

/// Reads individual content items and records that the student finished one.
/// Offline storage of opened lessons arrives with Phase 3, so reading stays a
/// thin pass-through to the API today.
class ContentRepository {
  ContentRepository(this._api);

  final UdmApi _api;

  Future<Devotional> devotional(String id) => _api.devotion(id);

  Future<Article> article(String id) => _api.article(id);

  Future<List<Article>> articles() => _api.articles();

  Future<ResourceStep> resourceStep(String id) => _api.resourceStep(id);

  Future<NewBelieverResource> newBelieverResource(String id) =>
      _api.newBelieverResource(id);

  /// Requires a signed-in student: progress belongs to an account. The API
  /// keeps one row per item, so marking the same devotion twice is harmless.
  Future<void> recordCompletion({required ContentKind kind, required String id}) =>
      _api.markComplete(kind: kind.value, contentId: id);
}
