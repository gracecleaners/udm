import '../../core/network/failure.dart';
import '../../core/storage/local_cache.dart';
import '../models/home_payload.dart';
import '../models/resume_item.dart';
import '../models/walk_summary.dart';
import '../providers/udm_api.dart';

/// Home feed with one cached payload so a student without data still sees the
/// devotion and verse downloaded on their last connection.
///
/// The cached copy remembers the server's content version at the time it was
/// written, so the screen knows — as soon as the network answers again — whether
/// what it is showing has already been superseded.
class HomeRepository {
  HomeRepository(this._api, this._cache, {int? Function()? contentVersion})
    : _contentVersion = contentVersion ?? (() => null);

  final UdmApi _api;
  final LocalCache _cache;
  final int? Function() _contentVersion;

  static const String cacheKey = 'udm.home.v1';

  Future<HomePayload> load() async {
    try {
      final fresh = await _api.home();
      final stamped = fresh.withCacheStamp(
        DateTime.now().toUtc(),
        // The payload dates itself; the locally known stamp only covers a
        // server that predates the field.
        version: fresh.contentVersion ?? _contentVersion(),
      );
      await _cache.writeJson(cacheKey, stamped.toJson());
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

  /// One day of the ministry's reading plan, ticked on the account. The plan
  /// itself is public copy and reads without an account; the tick is the
  /// student's, and it is what moves the progress line.
  Future<void> markReadingFinished(String assignmentId) =>
      _api.completeBibleAssignment(assignmentId);

  /// Where this student stopped in the ministry's recordings. Read straight
  /// from the account and never cached, for the same reason the verse review
  /// is not: the next person to hold the phone is not this student.
  Future<List<ResumeItem>> resume() => _api.mediaResume();

  /// What this student has finished, newest first. Home reads it for the ticks
  /// on today's list, and Profile prints it as the history the row promises.
  Future<List<ReadHistoryRow>> history() => _api.readHistory();

  /// The counts of this student's own walk, worked out by the server in one
  /// pass. Never cached: these numbers belong to an account, and the next
  /// person to hold the phone is not this student.
  Future<WalkSummary> summary() => _api.walkSummary();

  HomePayload? cached() {
    final raw = _cache.readJson(cacheKey);
    if (raw == null) return null;
    return HomePayload.fromJson(raw).asCached();
  }

  Future<void> clearCache() async => _cache.remove(cacheKey);
}
