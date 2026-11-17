/// One day of the reading plan the ministry marked as the daily one.
///
/// The staff write a day in the four sections a student actually works through,
/// so the app never has to invent a heading or guess what a day contains: the
/// server sends the passage, the verse, what it says and what to learn, and an
/// empty section is simply not drawn.
class ReadingDay {
  const ReadingDay({
    required this.id,
    required this.day,
    required this.reference,
    this.title = '',
    this.verseReference = '',
    this.verseText = '',
    this.whatItSays = '',
    this.whatToLearn = '',
    this.completed = false,
  });

  final String id;

  /// The day's number inside the plan, counted from one.
  final int day;
  final String title;

  /// The passage the student reads, as the ministry wrote it — "Romans 8".
  final String reference;
  final String verseReference;
  final String verseText;
  final String whatItSays;
  final String whatToLearn;

  /// The server's own record that this student finished this day.
  final bool completed;

  factory ReadingDay.fromJson(Map<String, dynamic> json) => ReadingDay(
        id: json['id'] as String? ?? '',
        day: (json['day'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        verseReference: json['verse_reference'] as String? ?? '',
        verseText: json['verse_text'] as String? ?? '',
        whatItSays: json['what_it_says'] as String? ?? '',
        whatToLearn: json['what_to_learn'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'title': title,
    'reference': reference,
    'verse_reference': verseReference,
    'verse_text': verseText,
    'what_it_says': whatItSays,
    'what_to_learn': whatToLearn,
    'completed': completed,
  };

  ReadingDay copyWith({bool? completed}) => ReadingDay(
    id: id,
    day: day,
    title: title,
    reference: reference,
    verseReference: verseReference,
    verseText: verseText,
    whatItSays: whatItSays,
    whatToLearn: whatToLearn,
    completed: completed ?? this.completed,
  );
}

/// Where a student stands in the plan, with the day in front of them.
///
/// The two counts come from the server because the plan's length is the plan's
/// own business: a progress line drawn from what the phone can see would say
/// "1 of 1" to a student on day one of thirty.
class TodaysReading {
  const TodaysReading({
    required this.planTitle,
    required this.total,
    required this.completed,
    required this.day,
  });

  final String planTitle;

  /// How many days the plan has, and how many this student has finished.
  final int total;
  final int completed;
  final ReadingDay day;

  /// The day the student is on, clamped to the plan so a damaged count still
  /// reads as a position rather than a negative number.
  int get number => completed.clamp(0, total) + (day.completed ? 0 : 1);

  double get fraction => total == 0 ? 0 : (completed / total).clamp(0.0, 1.0);

  bool get finished => total > 0 && completed >= total;

  factory TodaysReading.fromJson(Map<String, dynamic> json) => TodaysReading(
    planTitle: json['plan_title'] as String? ?? '',
    total: (json['total'] as num?)?.toInt() ?? 0,
    completed: (json['completed'] as num?)?.toInt() ?? 0,
    day: ReadingDay.fromJson(json['assignment'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'plan_title': planTitle,
    'total': total,
    'completed': completed,
    'assignment': day.toJson(),
  };

  /// The same plan position with one day ticked. Finishing a day is the only
  /// thing on this screen that changes what the card says, and refetching the
  /// whole dashboard to redraw one tick would flash every other card.
  TodaysReading copyWith({int? completed, ReadingDay? day}) => TodaysReading(
    planTitle: planTitle,
    total: total,
    completed: completed ?? this.completed,
    day: day ?? this.day,
  );
}
