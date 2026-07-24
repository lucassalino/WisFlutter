import '../../ministries/domain/ministry.dart';

/// Um ministério participante de um evento (linha de `event_ministries`),
/// com o ministério associado já carregado.
class EventMinistry {
  const EventMinistry({
    required this.id,
    required this.eventId,
    required this.ministry,
  });

  final String id;
  final String eventId;
  final Ministry ministry;

  factory EventMinistry.fromMap(Map<String, dynamic> map) => EventMinistry(
    id: map['id'] as String,
    eventId: map['event_id'] as String,
    ministry: Ministry.fromMap(map['ministry'] as Map<String, dynamic>),
  );
}
