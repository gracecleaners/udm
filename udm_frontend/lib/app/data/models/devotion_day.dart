/// A row in a devotion series: enough to choose the day, none of the body.
///
/// An unnumbered day is the Introduction, and the server sorts it first.
class DevotionDay {
  const DevotionDay({
    required this.id,
    required this.title,
    this.day,
    this.scriptureReference = '',
    this.excerpt = '',
    this.readingMinutes = 5,
  });

  final String id;
  final String title;
  final int? day;
  final String scriptureReference;
  final String excerpt;
  final int readingMinutes;

  bool get isIntroduction => day == null;

  factory DevotionDay.fromJson(Map<String, dynamic> json) => DevotionDay(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        day: (json['day'] as num?)?.toInt(),
        scriptureReference: json['scripture_reference'] as String? ?? '',
        excerpt: json['excerpt'] as String? ?? '',
        readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 5,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'day': day,
        'scripture_reference': scriptureReference,
        'excerpt': excerpt,
        'reading_minutes': readingMinutes,
      };
}
