class UserNotification {
  const UserNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.destination,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final String destination;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory UserNotification.fromJson(Map<String, dynamic> json) => UserNotification(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        kind: json['kind'] as String? ?? 'announcement',
        destination: json['destination'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      );
}
