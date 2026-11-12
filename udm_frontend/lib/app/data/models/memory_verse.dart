/// The verse of the day, and the same record the memory-verse drill uses.
///
/// Text always comes from a translation the ministry has licensed or recorded
/// as public domain on the server; the app never carries a provider key.
class MemoryVerse {
  const MemoryVerse({
    required this.id,
    required this.reference,
    required this.text,
    required this.translationCode,
    this.attribution = '',
    this.prompt = '',
    this.completed = false,
  });

  final String id;
  final String reference;
  final String text;
  final String translationCode;
  final String attribution;
  final String prompt;
  final bool completed;

  factory MemoryVerse.fromJson(Map<String, dynamic> json) => MemoryVerse(
        id: json['id'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        text: json['text'] as String? ?? '',
        translationCode: json['translation'] as String? ?? 'kjv',
        attribution: json['attribution'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        completed: json['completed'] as bool? ?? false,
      );

  MemoryVerse copyWith({bool? completed}) => MemoryVerse(
        id: id,
        reference: reference,
        text: text,
        translationCode: translationCode,
        attribution: attribution,
        prompt: prompt,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'text': text,
        'translation': translationCode,
        'attribution': attribution,
        'prompt': prompt,
        'completed': completed,
      };
}
