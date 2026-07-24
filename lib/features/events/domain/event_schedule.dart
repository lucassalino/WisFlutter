/// Uma pessoa escalada num ministério de um evento (linha de
/// `event_schedules`) — `confirmed` é `null` = pendente, `true` = confirmou,
/// `false` = recusou.
class EventSchedule {
  const EventSchedule({
    required this.id,
    required this.eventMinistryId,
    required this.userId,
    required this.functions,
    required this.confirmed,
    required this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String eventMinistryId;
  final String userId;
  final List<String> functions;
  final bool? confirmed;
  final String fullName;
  final String? avatarUrl;

  factory EventSchedule.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>?;
    return EventSchedule(
      id: map['id'] as String,
      eventMinistryId: map['event_ministry_id'] as String,
      userId: map['user_id'] as String,
      functions: (map['functions'] as List? ?? const [])
          .map((f) => f as String)
          .toList(),
      confirmed: map['confirmed'] as bool?,
      fullName: profile?['full_name'] as String? ?? '',
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
