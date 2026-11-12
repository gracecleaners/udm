import '../../core/network/failure.dart';
import '../../core/storage/local_cache.dart';
import '../models/media_collection.dart';
import '../models/media_item.dart';
import '../providers/udm_api.dart';

/// The Learn tab: the ministry's shelves of recordings, the recordings on each
/// shelf, and one recording opened — each cached so a student out of data can
/// still read what a teaching is about and reach its file.
///
/// Only the public copy is cached. A student's note and their place in a
/// recording are read from the server each time the page opens and written
/// straight back to it, because the device cache is shared by whoever holds the
/// phone.
///
/// Every saved copy carries the server's content version at the moment it was
/// written, which is what lets a screen tell its cached rows are older than
/// whatever the ministry published next.
class MediaRepository {
  MediaRepository(
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

  static const String shelvesKey = 'udm.mediaShelves.v1';
  static const String shelfKey = 'udm.mediaShelf.v1';
  static const String itemKey = 'udm.mediaItem.v1';

  Future<List<MediaCollection>> shelves() async {
    try {
      final fresh = (await _api.mediaCollections())
          .map(_stampCollection)
          .toList(growable: false);
      await _cache.writeJson(_shelvesKey, {
        'shelves': fresh.map((shelf) => shelf.toJson()).toList(),
      });
      return fresh;
    } on Failure {
      final stored = _cachedShelves();
      if (stored != null) return stored;
      rethrow;
    }
  }

  Future<MediaCollection> shelf(String id) async {
    try {
      final fresh = _stampCollection(await _api.mediaCollection(id));
      await _cache.writeJson(_shelfKeyFor(id), fresh.toJson());
      return fresh;
    } on Failure {
      final stored = _cachedShelf(id);
      if (stored != null) return stored;
      rethrow;
    }
  }

  /// A recording opened. The item endpoint is the only place its note and
  /// resume position appear, so an offline student gets the public copy and is
  /// told the private part is waiting on a connection.
  Future<MediaItem> item(String id) async {
    try {
      final fresh = _stampItem(await _api.mediaItem(id));
      await _cache.writeJson(_itemKeyFor(id), fresh.toJson());
      return fresh;
    } on Failure {
      final stored = _cachedItem(id);
      if (stored != null) return stored;
      rethrow;
    }
  }

  /// The student's own note on a recording. Blank text deletes it server-side,
  /// and the answer is what the screen shows, so no refetch follows a save.
  Future<({String text, DateTime? updatedAt})> saveNote(String id, String text) async {
    final body = await _api.saveMediaNote(id, text);
    return (text: body['text'] as String? ?? '', updatedAt: _date(body['updated_at']));
  }

  /// Where the student stopped, and whether they finished. Sent by the player
  /// when the page closes and by the mark-watched action.
  Future<({int positionSeconds, bool completed})> saveWatch(
    String id, {
    required int positionSeconds,
    required bool completed,
  }) async {
    final body = await _api.saveMediaWatch(
      id,
      positionSeconds: positionSeconds,
      completed: completed,
    );
    return (
      positionSeconds: (body['position_seconds'] as num?)?.toInt() ?? positionSeconds,
      completed: body['completed'] as bool? ?? completed,
    );
  }

  /// The copy on this device, if there is one, labelled as cached. Used before
  /// the network answers so a returning student sees their shelf immediately.
  List<MediaCollection>? cachedShelves() => _cachedShelves();

  MediaCollection? cachedShelf(String id) => _cachedShelf(id);

  MediaItem? cachedItem(String id) => _cachedItem(id);

  /// The payload carries its own stamp, which is the exact moment of the copy
  /// the student is being sent. The locally known number only covers a server
  /// that predates the field, and cannot be trusted to line up with a response
  /// that raced the version request.
  MediaCollection _stampCollection(MediaCollection shelf) =>
      shelf.withCacheStamp(
        DateTime.now().toUtc(),
        version: shelf.contentVersion ?? _contentVersion(),
      );

  MediaItem _stampItem(MediaItem item) => item.withCacheStamp(
    DateTime.now().toUtc(),
    version: item.contentVersion ?? _contentVersion(),
  );

  String get _shelvesKey => _localized(shelvesKey);
  String _shelfKeyFor(String id) => _localized('$shelfKey.$id');
  String _itemKeyFor(String id) => _localized('$itemKey.$id');

  /// French and English copies of the same shelf are different text, so they
  /// are different cache entries.
  String _localized(String key) => _languageCode() == 'fr' ? '$key.fr' : key;

  List<MediaCollection>? _cachedShelves() {
    final raw = _cache.readJson(_shelvesKey)?['shelves'];
    if (raw is! List) return null;
    return raw
        .whereType<Map<String, dynamic>>()
        .map((row) => MediaCollection.fromJson(row).asCached())
        .toList();
  }

  MediaCollection? _cachedShelf(String id) {
    final raw = _cache.readJson(_shelfKeyFor(id));
    if (raw == null) return null;
    return MediaCollection.fromJson(raw).asCached();
  }

  MediaItem? _cachedItem(String id) {
    final raw = _cache.readJson(_itemKeyFor(id));
    if (raw == null) return null;
    return MediaItem.fromJson(raw).asCached();
  }

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse('$value');
}
