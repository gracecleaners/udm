import '../../core/network/failure.dart';
import '../../core/storage/local_cache.dart';
import '../models/devotion_series.dart';
import '../models/devotional.dart';
import '../providers/udm_api.dart';

/// The Devotions tab's own copy of the library: the grid of series, the days
/// inside one and the devotionals published on their own, each cached so a
/// student out of data can keep reading what the ministry published while they
/// had it.
///
/// Every saved copy carries the server's content version at the moment it was
/// written, which is what lets a screen tell its cached rows are older than
/// whatever the ministry published next.
class DevotionsRepository {
  DevotionsRepository(
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

  static const String gridKey = 'udm.devotionGrid.v1';
  static const String seriesKey = 'udm.devotionSeries.v1';
  static const String feedKey = 'udm.devotionalFeed.v1';

  Future<List<DevotionSeries>> grid() async {
    try {
      final fresh = await _api.devotionSeries();
      final stamped = fresh
          .map((series) => _stamp(series))
          .toList(growable: false);
      await _cache.writeJson(_gridKey, {
        'series': stamped.map((series) => series.toJson()).toList(),
      });
      return stamped;
    } on Failure {
      final stored = _cachedGrid();
      if (stored != null) return stored;
      rethrow;
    }
  }

  /// The devotionals the ministry publishes one at a time, newest first, so the
  /// tab can open on the day's reading and offer the ones just behind it.
  ///
  /// These rows are not stamped: the server sends no content version with an
  /// individual devotional, and the tab's offline notice rides on the series
  /// grid, which does.
  Future<List<Devotional>> devotionals() async {
    try {
      final fresh = await _api.devotionals();
      await _cache.writeJson(_feedKey, {
        'devotionals': fresh.map((devotional) => devotional.toJson()).toList(),
      });
      return fresh;
    } on Failure {
      final stored = _cachedFeed();
      if (stored != null) return stored;
      rethrow;
    }
  }

  Future<DevotionSeries> series(String id) async {
    try {
      final fresh = _stamp(await _api.devotionSeriesDetail(id));
      await _cache.writeJson(_seriesKeyFor(id), fresh.toJson());
      return fresh;
    } on Failure {
      final stored = _cachedSeries(id);
      if (stored != null) return stored;
      rethrow;
    }
  }

  /// The copy on this device, if there is one, labelled as cached. Used before
  /// the network answers so a returning student sees their library immediately
  /// and the fresh rows replace it when they arrive.
  List<DevotionSeries>? cachedGrid() => _cachedGrid();

  List<Devotional>? cachedDevotionals() => _cachedFeed();

  DevotionSeries? cachedSeries(String id) => _cachedSeries(id);

  /// The payload carries its own stamp, which is the exact moment of the copy
  /// the student is being sent. The locally known number only covers a server
  /// that predates the field, and cannot be trusted to line up with a response
  /// that raced the version request.
  DevotionSeries _stamp(DevotionSeries series) => series.withCacheStamp(
    DateTime.now().toUtc(),
    version: series.contentVersion ?? _contentVersion(),
  );

  String get _gridKey => _localized(gridKey);
  String _seriesKeyFor(String id) => _localized('$seriesKey.$id');
  String get _feedKey => _localized(feedKey);

  /// French and English copies of the same series are different text, so they
  /// are different cache entries.
  String _localized(String key) => _languageCode() == 'fr' ? '$key.fr' : key;

  List<DevotionSeries>? _cachedGrid() {
    final raw = _cache.readJson(_gridKey)?['series'];
    if (raw is! List) return null;
    return raw
        .whereType<Map<String, dynamic>>()
        .map((row) => DevotionSeries.fromJson(row).asCached())
        .toList();
  }

  DevotionSeries? _cachedSeries(String id) {
    final raw = _cache.readJson(_seriesKeyFor(id));
    if (raw == null) return null;
    return DevotionSeries.fromJson(raw).asCached();
  }

  List<Devotional>? _cachedFeed() {
    final raw = _cache.readJson(_feedKey)?['devotionals'];
    if (raw is! List) return null;
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Devotional.fromJson)
        .toList();
  }
}
