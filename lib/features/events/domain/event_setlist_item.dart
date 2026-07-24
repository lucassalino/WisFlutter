import '../../songs/domain/song.dart';

/// Uma música do reportório do evento, com o Tom escolhido *para este
/// evento* (`event_setlists.musical_key`) — cada evento pode usar um tom
/// diferente da mesma música.
class EventSetlistItem {
  const EventSetlistItem({
    required this.song,
    required this.orderIndex,
    this.eventKey,
  });

  final Song song;
  final int orderIndex;
  final String? eventKey;

  factory EventSetlistItem.fromMap(Map<String, dynamic> map) =>
      EventSetlistItem(
        song: Song.fromMap(map['song'] as Map<String, dynamic>),
        orderIndex: map['order_index'] as int,
        eventKey: map['musical_key'] as String?,
      );
}
