import '../../core/network/failure.dart';
import '../../core/storage/local_cache.dart';
import '../models/home_payload.dart';
import '../providers/udm_api.dart';

/// Home feed with one cached payload so a student without data still sees the
/// devotion and verse downloaded on their last connection.
///
/// The cached copy remembers the server's content version at the time it was
/// written, so the screen knows — as soon as the network answers again — whether
/// what it is showing has already been superseded.
class HomeRepository {
  HomeRepository(
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

  static const String cacheKey = 'udm.home.v1';
  String get _cacheKey => _languageCode() == 'fr' ? '$cacheKey.fr' : cacheKey;

  Future<HomePayload> load() async {
    try {
      final fresh = await _api.home();
      final stamped = fresh.withCacheStamp(
        DateTime.now().toUtc(),
        // The payload dates itself; the locally known stamp only covers a
        // server that predates the field.
        version: fresh.contentVersion ?? _contentVersion(),
      );
      await _cache.writeJson(_cacheKey, stamped.toJson());
      return stamped;
    } on Failure {
      final stored = cached();
      if (stored != null) return stored;
      rethrow;
    }
  }

  /// A private write goes straight to the server and is never kept on the
  /// device: whoever holds the phone should not find what another student
  /// learned on it.
  Future<void> markVerseMemorized(String verseId) => _api.reviewMemoryVerse(verseId);

  HomePayload? cached() {
    final raw = _cache.readJson(_cacheKey);
    if (raw == null) return null;
    return HomePayload.fromJson(raw).asCached();
  }

  Future<void> clearCache() async {
    await _cache.remove(cacheKey);
    await _cache.remove('$cacheKey.fr');
  }
}
