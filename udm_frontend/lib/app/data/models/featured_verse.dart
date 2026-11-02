/// Verse-of-the-day served by the API; text always comes from a licensed or
/// public-domain translation recorded on the server.
class FeaturedVerse {
  const FeaturedVerse({
    required this.id,
    required this.reference,
    required this.text,
    required this.translationCode,
    this.attribution = '',
  });

  final String id;
  final String reference;
  final String text;
  final String translationCode;
  final String attribution;

  factory FeaturedVerse.fromJson(Map<String, dynamic> json) => FeaturedVerse(
        id: json['id'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        text: json['text'] as String? ?? '',
        translationCode: json['translation_code'] as String? ?? 'kjv',
        attribution: json['attribution'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'text': text,
        'translation_code': translationCode,
        'attribution': attribution,
      };
}
