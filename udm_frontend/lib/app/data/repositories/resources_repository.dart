import '../../core/network/failure.dart';
import '../../core/storage/local_cache.dart';
import '../models/resource_topic.dart';
import '../providers/udm_api.dart';

/// The "Find resources on" guides: the list home renders and the steps inside
/// one guide, each cached so a student out of data can still work through a
/// guide they had already opened.
///
/// Every saved copy carries the server's content version at the moment it was
/// written, which is what lets a screen tell its cached rows are older than
/// whatever the ministry published next.
class ResourcesRepository {
  ResourcesRepository(
    this._api,
    this._cache, {
    String Function()? languageCode,
    int? Function()? contentVersion,
  }) : _languageCode = languageCode ?? (() => 'en'),
       _contentVersion = contentVersion ?? (() => null);

  final UdmApi _api;
  final LocalCache _cache;
  final String Function() _languageCode;
  final int? Function() _contentVersion;

  static const String topicsKey = 'udm.resourceTopics.v1';
  static const String topicKey = 'udm.resourceTopic.v1';

  Future<List<ResourceTopic>> topics() async {
    try {
      final fresh = (await _api.resourceTopics())
          .map(_stamp)
          .toList(growable: false);
      await _cache.writeJson(_topicsKey, {
        'topics': fresh.map((topic) => topic.toJson()).toList(),
      });
      return fresh;
    } on Failure {
      final stored = _cachedTopics();
      if (stored != null) return stored;
      rethrow;
    }
  }

  Future<ResourceTopic> topic(String id) async {
    try {
      final fresh = _stamp(await _api.resourceTopicDetail(id));
      await _cache.writeJson(_topicKeyFor(id), fresh.toJson());
      return fresh;
    } on Failure {
      final stored = _cachedTopic(id);
      if (stored != null) return stored;
      rethrow;
    }
  }

  /// The copy on this device, if there is one, labelled as cached. Used before
  /// the network answers so a returning student sees the guide immediately.
  List<ResourceTopic>? cachedTopics() => _cachedTopics();

  ResourceTopic? cachedTopic(String id) => _cachedTopic(id);

  /// The payload carries its own stamp, which is the exact moment of the copy
  /// the student is being sent. The locally known number only covers a server
  /// that predates the field, and cannot be trusted to line up with a response
  /// that raced the version request.
  ResourceTopic _stamp(ResourceTopic topic) => topic.withCacheStamp(
    DateTime.now().toUtc(),
    version: topic.contentVersion ?? _contentVersion(),
  );

  String get _topicsKey => _localized(topicsKey);
  String _topicKeyFor(String id) => _localized('$topicKey.$id');

  /// French and English copies of the same guide are different text, so they
  /// are different cache entries.
  String _localized(String key) => _languageCode() == 'fr' ? '$key.fr' : key;

  List<ResourceTopic>? _cachedTopics() {
    final raw = _cache.readJson(_topicsKey)?['topics'];
    if (raw is! List) return null;
    return raw
        .whereType<Map<String, dynamic>>()
        .map((row) => ResourceTopic.fromJson(row).asCached())
        .toList();
  }

  ResourceTopic? _cachedTopic(String id) {
    final raw = _cache.readJson(_topicKeyFor(id));
    if (raw == null) return null;
    return ResourceTopic.fromJson(raw).asCached();
  }
}
