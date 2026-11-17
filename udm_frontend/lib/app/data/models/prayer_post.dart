/// One card on the community wall, and the words written underneath it.
///
/// The wall prints a first name the ministry chose to share, never the address
/// a student signed up with, so `ownerName` falls back to a plain "A student"
/// when somebody keeps their profile blank.
class PrayerPost {
  const PrayerPost({
    required this.id,
    required this.body,
    required this.category,
    required this.visibility,
    required this.moderationState,
    required this.createdAt,
    required this.isOwner,
    required this.ownerName,
    required this.affirmed,
    required this.affirmationCount,
    required this.commentCount,
    this.groupId = '',
    this.ownerPhotoUrl = '',
  });

  final String id;
  final String body;

  /// `prayer`, `testimony` or `encouragement` — the wall's own tabs.
  final String category;

  /// `private`, `group` or `public`; a private request never reaches a wall.
  final String visibility;

  /// `pending`, `approved` or `rejected`, so the writer can see where their
  /// request is waiting when the wall is not showing it yet.
  final String moderationState;
  final DateTime createdAt;
  final bool isOwner;
  final String ownerName;

  /// Whether this reader is already standing with the writer.
  final bool affirmed;
  final int affirmationCount;
  final int commentCount;
  final String groupId;

  /// The writer's own picture, empty when they have none or keep their name
  /// off the wall. The card then draws the initials tile instead.
  final String ownerPhotoUrl;

  bool get isTestimony => category == 'testimony';

  factory PrayerPost.fromJson(Map<String, dynamic> json) => PrayerPost(
    id: json['id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    category: json['category'] as String? ?? 'prayer',
    visibility: json['visibility'] as String? ?? 'private',
    moderationState: json['moderation_state'] as String? ?? 'pending',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime(2000),
    isOwner: json['is_owner'] as bool? ?? false,
    ownerName: json['owner_name'] as String? ?? 'A student',
    affirmed: json['affirmed'] as bool? ?? false,
    affirmationCount: (json['affirmation_count'] as num?)?.toInt() ?? 0,
    commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
    groupId: json['group'] as String? ?? '',
    ownerPhotoUrl: json['owner_photo'] as String? ?? '',
  );

  /// The card after the reader makes or takes back a promise. The wall's two
  /// numbers come from the affirmation call itself, so a card is rewritten in
  /// place rather than the whole feed refetched.
  PrayerPost copyWith({bool? affirmed, int? affirmationCount, int? commentCount}) => PrayerPost(
    id: id,
    body: body,
    category: category,
    visibility: visibility,
    moderationState: moderationState,
    createdAt: createdAt,
    isOwner: isOwner,
    ownerName: ownerName,
    affirmed: affirmed ?? this.affirmed,
    affirmationCount: affirmationCount ?? this.affirmationCount,
    commentCount: commentCount ?? this.commentCount,
    groupId: groupId,
    ownerPhotoUrl: ownerPhotoUrl,
  );

  /// Two letters for the avatar, from the name the ministry chose to print.
  String get initials {
    final words = ownerName.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final only = words.first;
      return (only.length >= 2 ? only.substring(0, 2) : only).toUpperCase();
    }
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }
}

/// One word of encouragement under a request. Only its writer can remove it.
class PrayerComment {
  const PrayerComment({
    required this.id,
    required this.body,
    required this.authorName,
    required this.createdAt,
    required this.isOwner,
    this.authorPhotoUrl = '',
  });

  final String id;
  final String body;
  final String authorName;
  final DateTime createdAt;

  /// Only its writer may take it back, and the server says so per row rather
  /// than leaving the app to guess from a name two students can share.
  final bool isOwner;

  /// Empty when the writer has no picture or no published name, which is the
  /// same rule the card above the comment follows.
  final String authorPhotoUrl;

  factory PrayerComment.fromJson(Map<String, dynamic> json) => PrayerComment(
    id: json['id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    authorName: json['author_name'] as String? ?? 'A student',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime(2000),
    isOwner: json['is_owner'] as bool? ?? false,
    authorPhotoUrl: json['author_photo'] as String? ?? '',
  );
}

/// The wall's tabs, in the order the API documents them. `all` is a client-side
/// choice: the server only answers with the categories it knows.
enum PrayerCategory {
  prayer('prayer', 'Prayer'),
  testimony('testimony', 'Testimonies'),
  encouragement('encouragement', 'Encouragement');

  const PrayerCategory(this.value, this.label);

  final String value;
  final String label;

  static PrayerCategory? tryParse(String value) {
    for (final category in values) {
      if (category.value == value) return category;
    }
    return null;
  }
}

/// What the wall looks like after a promise is made or taken back.
class AffirmationState {
  const AffirmationState({required this.affirmed, required this.count});

  final bool affirmed;
  final int count;

  factory AffirmationState.fromJson(Map<String, dynamic> json) => AffirmationState(
    affirmed: json['affirmed'] as bool? ?? false,
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}
