import 'package:flutter/material.dart';

/// Um ponto do roteiro do evento ("7h30 ensaio", "9h devocional") — não
/// substitui `events.arrival_time` (hora única de chegada da equipa).
class EventTimelineItem {
  const EventTimelineItem({required this.time, required this.title});

  final TimeOfDay time;
  final String title;

  int get _minutes => time.hour * 60 + time.minute;

  static int compare(EventTimelineItem a, EventTimelineItem b) =>
      a._minutes.compareTo(b._minutes);

  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  factory EventTimelineItem.fromMap(Map<String, dynamic> map) {
    final parts = (map['time'] as String).split(':');
    return EventTimelineItem(
      time: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      title: map['title'] as String,
    );
  }
}
