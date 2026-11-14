/// The numbers a student keeps about their own walk, from `GET /progress/summary/`.
///
/// Every figure is a count of rows the app could already list, so a number here
/// and the list behind it can never disagree.
class WalkSummary {
  const WalkSummary({
    this.dayStreak = 0,
    this.devotionalsCompleted = 0,
    this.articlesCompleted = 0,
    this.stepsCompleted = 0,
    this.guidesCompleted = 0,
    this.videosWatched = 0,
    this.bookmarks = 0,
    this.notes = 0,
    this.planDaysCompleted = 0,
  });

  final int dayStreak;
  final int devotionalsCompleted;
  final int articlesCompleted;

  /// Steps finished inside the guided topics the app shows as courses.
  final int stepsCompleted;

  /// Guides whose every live step this student has finished.
  final int guidesCompleted;
  final int videosWatched;
  final int bookmarks;
  final int notes;
  final int planDaysCompleted;

  /// Devotions and articles read, which is what the profile's "Devotionals"
  /// tile counts.
  int get readingsCompleted => devotionalsCompleted + articlesCompleted;

  factory WalkSummary.fromJson(Map<String, dynamic> json) => WalkSummary(
        dayStreak: _int(json['day_streak']),
        devotionalsCompleted: _int(json['devotionals_completed']),
        articlesCompleted: _int(json['articles_completed']),
        stepsCompleted: _int(json['steps_completed']),
        guidesCompleted: _int(json['guides_completed']),
        videosWatched: _int(json['videos_watched']),
        bookmarks: _int(json['bookmarks']),
        notes: _int(json['notes']),
        planDaysCompleted: _int(json['plan_days_completed']),
      );

  static int _int(dynamic value) => value is num ? value.toInt() : 0;
}

/// One finished item in the student's own history, from `GET /progress/`.
///
/// The server prints the title, because a history row that carries only an id
/// is a row the student cannot read.
class ReadHistoryRow {
  const ReadHistoryRow({
    required this.kind,
    required this.kindLabel,
    required this.contentId,
    required this.title,
    required this.completedAt,
    this.note = '',
  });

  final String kind;
  final String kindLabel;
  final String contentId;
  final String title;
  final DateTime completedAt;
  final String note;

  factory ReadHistoryRow.fromJson(Map<String, dynamic> json) => ReadHistoryRow(
        kind: json['kind'] as String? ?? '',
        kindLabel: json['kind_label'] as String? ?? '',
        contentId: json['content_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        completedAt: DateTime.tryParse(json['completed_at'] as String? ?? '') ?? DateTime(2000),
        note: json['note'] as String? ?? '',
      );
}
