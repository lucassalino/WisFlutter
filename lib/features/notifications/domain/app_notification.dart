class AppNotification {
  const AppNotification({
    required this.id,
    required this.message,
    required this.isRead,
    required this.sentAt,
    this.eventId,
    this.eventName,
  });

  final String id;
  final String message;
  final bool isRead;
  final DateTime sentAt;
  final String? eventId;
  final String? eventName;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final event = map['event'] as Map<String, dynamic>?;
    return AppNotification(
      id: map['id'] as String,
      message: map['message'] as String,
      isRead: map['is_read'] as bool? ?? false,
      sentAt: DateTime.parse(map['sent_at'] as String),
      eventId: event?['id'] as String?,
      eventName: event?['name'] as String?,
    );
  }
}
