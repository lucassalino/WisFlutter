import 'package:flutter/material.dart';

/// Período do dia derivado da hora do evento — Manhã (05:00–11:59),
/// Tarde (12:00–17:59), Noite (18:00–04:59).
enum EventDayPeriod {
  morning('🌅', 'Manhã'),
  afternoon('☀️', 'Tarde'),
  night('🌙', 'Noite');

  const EventDayPeriod(this.emoji, this.label);
  final String emoji;
  final String label;

  static EventDayPeriod fromTimeOfDay(TimeOfDay time) {
    final minutes = time.hour * 60 + time.minute;
    if (minutes >= 5 * 60 && minutes < 12 * 60) return EventDayPeriod.morning;
    if (minutes >= 12 * 60 && minutes < 18 * 60) {
      return EventDayPeriod.afternoon;
    }
    return EventDayPeriod.night;
  }
}

class Event {
  const Event({
    required this.id,
    required this.orgId,
    required this.name,
    required this.date,
    required this.time,
    this.arrivalTime,
    this.location,
    this.color,
    this.description,
    this.observations,
    this.coverImageUrl,
    required this.isPublished,
    required this.createdBy,
  });

  final String id;
  final String orgId;
  final String name;
  final DateTime date;
  final TimeOfDay time;
  final TimeOfDay? arrivalTime;
  final String? location;
  final String? color;
  final String? description;
  final String? observations;
  final String? coverImageUrl;
  final bool isPublished;
  final String createdBy;

  EventDayPeriod get period => EventDayPeriod.fromTimeOfDay(time);

  DateTime get dateTime =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  factory Event.fromMap(Map<String, dynamic> map) => Event(
    id: map['id'] as String,
    orgId: map['org_id'] as String,
    name: map['name'] as String,
    date: DateTime.parse(map['date'] as String),
    time: _parseTimeOfDay(map['time'] as String),
    arrivalTime: map['arrival_time'] != null
        ? _parseTimeOfDay(map['arrival_time'] as String)
        : null,
    location: map['location'] as String?,
    color: map['color'] as String?,
    description: map['description'] as String?,
    observations: map['observations'] as String?,
    coverImageUrl: map['cover_image_url'] as String?,
    isPublished: map['is_published'] as bool,
    createdBy: map['created_by'] as String,
  );

  static TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
