class NewBelieverResource {
  const NewBelieverResource({
    required this.id,
    required this.title,
    this.author = '',
    this.scriptureReference = '',
    this.excerpt = '',
    this.body = '',
    this.readingMinutes = 5,
    this.order = 1,
    this.videoUrl = '',
    this.imageUrl = '',
  });

  final String id;
  final String title;
  final String author;
  final String scriptureReference;
  final String excerpt;
  final String body;
  final int readingMinutes;
  final int order;
  final String videoUrl;
  final String imageUrl;

  bool get hasVideo => videoUrl.isNotEmpty;

  factory NewBelieverResource.fromJson(Map<String, dynamic> json) =>
      NewBelieverResource(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        scriptureReference: json['scripture_reference'] as String? ?? '',
        excerpt: json['excerpt'] as String? ?? '',
        body: json['body'] as String? ?? '',
        readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 5,
        order: (json['order'] as num?)?.toInt() ?? 1,
        videoUrl: json['video_url'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
      );
}
