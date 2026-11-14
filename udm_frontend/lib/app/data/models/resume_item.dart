/// A recording the student stopped partway through, and where they stopped.
///
/// The server assembles this straight from watch rows, so the card on the home
/// feed is tappable without the app walking every shelf for it.
class ResumeItem {
  const ResumeItem({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.positionSeconds,
    this.imageUrl = '',
    this.collectionId = '',
    this.collectionTitle = '',
  });

  /// The recording's own id, so opening this card goes to the player.
  final String id;
  final String title;
  final String imageUrl;
  final int durationSeconds;
  final int positionSeconds;
  final String collectionId;
  final String collectionTitle;

  /// Fraction watched, used for the progress bar. A zero-length recording is
  /// read as untouched rather than as a division by zero.
  double get progress =>
      durationSeconds <= 0 ? 0 : (positionSeconds / durationSeconds).clamp(0.0, 1.0);

  bool get hasStarted => positionSeconds > 0;

  String get remainingLabel {
    final seconds = (durationSeconds - positionSeconds).clamp(0, durationSeconds);
    final minutes = (seconds / 60).ceil();
    return minutes <= 1 ? '1 min left' : '$minutes min left';
  }

  factory ResumeItem.fromJson(Map<String, dynamic> json) {
    final collection = json['collection'];
    return ResumeItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      positionSeconds: (json['position_seconds'] as num?)?.toInt() ?? 0,
      collectionId: collection is Map ? collection['id'] as String? ?? '' : '',
      collectionTitle: collection is Map ? collection['title'] as String? ?? '' : '',
    );
  }
}
