import '../../core/network/failure.dart';
import '../../core/storage/local_cache.dart';
import '../models/home_payload.dart';
import '../providers/udm_api.dart';

/// Home feed with one cached payload so a student without data still sees the
/// devotion and verse downloaded on their last connection.
class HomeRepository {
  HomeRepository(this._api, this._cache);

  final UdmApi _api;
  final LocalCache _cache;

  static const String cacheKey = 'udm.home.v1';

  Future<HomePayload> load() async {
    try {
      final fresh = await _api.home();
      final stamped = fresh.withCacheStamp(DateTime.now().toUtc());
      await _cache.writeJson(cacheKey, stamped.toJson());
      return stamped;
    } on Failure {
      final stored = cached();
      if (stored != null) return stored;
      rethrow;
    }
  }

  HomePayload? cached() {
    final raw = _cache.readJson(cacheKey);
    if (raw == null) return null;
    return HomePayload.fromJson(raw).asCached();
  }

  Future<void> clearCache() => _cache.remove(cacheKey);
}
