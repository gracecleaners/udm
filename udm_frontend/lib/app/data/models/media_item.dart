/// One recording in the Learn tab: the teaching itself, and the student's own
/// note and place in it.
///
/// The note and the resume position come back with the recording because they
/// belong to this screen and to nobody else. They are never cached on the
/// device: a note is private writing, and the app's private storage is not
/// where it belongs.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    this.author = '',
    this.excerpt = '',
    this.body = '',
    this.order,
    this.publishAt,
    this.durationSeconds,
    this.imageUrl = '',
    this.youtubeVideoId,
    this.youtubeUrl = '',
    this.downloadUrl = '',
    this.watched = false,
    this.resumeAt,
    this.note = '',
    this.noteUpdatedAt,
    this.collectionId = '',
    this.collectionTitle = '',
    this.collectionItemCount = 0,
    this.cachedAt,
    this.fromCache = false,
    this.contentVersion,
  });

  final String id;
  final String title;
  final String author;
  final String excerpt;
  final String body;
  final int? order;
  final DateTime? publishAt;
  final int? durationSeconds;
  final String imageUrl;

  /// Non-null only when staff attached a YouTube link, which is what makes the
  /// inline player possible. The server parses the id out of whatever form of
  /// link was pasted, so the app never has to.
  final String? youtubeVideoId;
  final String youtubeUrl;

  /// A file the ministry distributes itself. Download is offered only when
  /// staff put one here, because a YouTube recording may not be downloaded.
  final String downloadUrl;
  final bool watched;
  final int? resumeAt;
  final String note;
  final DateTime? noteUpdatedAt;
  final String collectionId;
  final String collectionTitle;
  final int collectionItemCount;
  final DateTime? cachedAt;
  final bool fromCache;
  final int? contentVersion;

  bool get hasArt => imageUrl.isNotEmpty;

  /// Whether anything can actually be played or saved. A recording whose link
  /// the ministry has not pasted yet opens as the readable page it is.
  bool get hasRecording => youtubeVideoId != null || downloadUrl.isNotEmpty;

  bool get hasNote => note.isNotEmpty;

  String get shareUrl => youtubeUrl.isNotEmpty
      ? youtubeUrl
      : (downloadUrl.isNotEmpty ? downloadUrl : '');

  /// `15:40` or `1:04:30`, and nothing at all when staff have not entered the
  /// length, so a row never promises a duration it does not know.
  String get durationLabel {
    final total = durationSeconds;
    if (total == null || total <= 0) return '';
    final seconds = total % 60;
    final minutes = (total ~/ 60) % 60;
    final hours = total ~/ 3600;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final watch = json['watch'] is Map ? Map<String, dynamic>.from(json['watch'] as Map) : null;
    final note = json['note'] is Map ? Map<String, dynamic>.from(json['note'] as Map) : null;
    final collection = json['collection'] is Map
        ? Map<String, dynamic>.from(json['collection'] as Map)
        : null;
    final stoppedAt = (watch?['position_seconds'] as num?)?.toInt() ?? 0;
    final finished = watch == null
        ? (json['watched'] as bool? ?? false)
        : (watch['completed'] as bool? ?? false);

    return MediaItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      body: json['body'] as String? ?? '',
      order: (json['order'] as num?)?.toInt(),
      publishAt: json['publish_at'] == null
          ? null
          : DateTime.tryParse(json['publish_at'] as String),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      imageUrl: json['image_url'] as String? ?? '',
      youtubeVideoId: json['youtube_video_id'] as String?,
      youtubeUrl: json['youtube_url'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      watched: finished,
      resumeAt: finished || stoppedAt <= 0 ? null : stoppedAt,
      note: note?['text'] as String? ?? '',
      noteUpdatedAt: note?['updated_at'] == null
          ? null
          : DateTime.tryParse(note!['updated_at'] as String),
      collectionId: collection?['id'] as String? ?? '',
      collectionTitle: collection?['title'] as String? ?? '',
      collectionItemCount: (collection?['item_count'] as num?)?.toInt() ?? 0,
      cachedAt: json['cached_at'] == null
          ? null
          : DateTime.tryParse(json['cached_at'] as String),
      fromCache: json['from_cache'] as bool? ?? false,
      contentVersion: (json['content_version'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'excerpt': excerpt,
        'body': body,
        'order': order,
        'publish_at': publishAt?.toIso8601String(),
        'duration_seconds': durationSeconds,
        'image_url': imageUrl,
        'youtube_video_id': youtubeVideoId,
        'youtube_url': youtubeUrl,
        'download_url': downloadUrl,
        'collection': {
          'id': collectionId,
          'title': collectionTitle,
          'item_count': collectionItemCount,
        },
        'cached_at': cachedAt?.toIso8601String(),
        'from_cache': fromCache,
        'content_version': contentVersion,
      };

  MediaItem withCacheStamp(DateTime moment, {int? version}) =>
      copyWith(cachedAt: moment, contentVersion: version);

  /// The saved copy holds only what the public list holds: `toJson` carries no
  /// note, no resume position and no completion mark, so a cached recording
  /// cannot surface one student's writing, or what they have watched, to the
  /// next one to use the device.
  MediaItem asCached() => copyWith(fromCache: true);

  MediaItem copyWith({
    String? id,
    String? title,
    String? author,
    String? excerpt,
    String? body,
    int? order,
    DateTime? publishAt,
    int? durationSeconds,
    String? imageUrl,
    String? youtubeVideoId,
    String? youtubeUrl,
    String? downloadUrl,
    bool? watched,
    int? resumeAt,
    String? note,
    DateTime? noteUpdatedAt,
    String? collectionId,
    String? collectionTitle,
    int? collectionItemCount,
    DateTime? cachedAt,
    bool? fromCache,
    int? contentVersion,
  }) => MediaItem(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author ?? this.author,
    excerpt: excerpt ?? this.excerpt,
    body: body ?? this.body,
    order: order ?? this.order,
    publishAt: publishAt ?? this.publishAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    imageUrl: imageUrl ?? this.imageUrl,
    youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
    youtubeUrl: youtubeUrl ?? this.youtubeUrl,
    downloadUrl: downloadUrl ?? this.downloadUrl,
    watched: watched ?? this.watched,
    resumeAt: resumeAt ?? this.resumeAt,
    note: note ?? this.note,
    noteUpdatedAt: noteUpdatedAt ?? this.noteUpdatedAt,
    collectionId: collectionId ?? this.collectionId,
    collectionTitle: collectionTitle ?? this.collectionTitle,
    collectionItemCount: collectionItemCount ?? this.collectionItemCount,
    cachedAt: cachedAt ?? this.cachedAt,
    fromCache: fromCache ?? this.fromCache,
    contentVersion: contentVersion ?? this.contentVersion,
  );
}
