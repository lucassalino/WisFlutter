import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/domain/event.dart';
import '../domain/event_ministry.dart';
import '../domain/event_schedule.dart';
import '../domain/event_setlist_item.dart';
import '../domain/event_timeline_item.dart';

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(supabaseClientProvider));
});

class EventPayload {
  const EventPayload({
    required this.name,
    required this.date,
    required this.time,
    this.arrivalTime,
    this.location,
    this.color,
    this.description,
    this.observations,
    required this.isPublished,
  });

  final String name;
  final DateTime date;
  final TimeOfDay time;
  final TimeOfDay? arrivalTime;
  final String? location;
  final String? color;
  final String? description;
  final String? observations;
  final bool isPublished;

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Map<String, dynamic> toMap() => {
    'name': name,
    'date': _fmtDate(date),
    'time': _fmtTime(time),
    'arrival_time': arrivalTime != null ? _fmtTime(arrivalTime!) : null,
    'location': location,
    'color': color,
    'description': description,
    'observations': observations,
    'is_published': isPublished,
  };
}

class EventScheduleAssignment {
  const EventScheduleAssignment({
    required this.userId,
    required this.functions,
  });
  final String userId;
  final List<String> functions;
}

class EventMinistrySetup {
  const EventMinistrySetup({required this.ministryId, required this.members});
  final String ministryId;
  final List<EventScheduleAssignment> members;
}

class EventSetupData {
  const EventSetupData({
    required this.ministryIds,
    required this.membersByMinistry,
    required this.songIds,
    required this.songKeys,
    required this.timeline,
  });

  final List<String> ministryIds;
  final Map<String, List<EventScheduleAssignment>> membersByMinistry;
  final List<String> songIds;
  final Map<String, String> songKeys;
  final List<EventTimelineItem> timeline;
}

class EventsRepository {
  EventsRepository(this._client);

  final SupabaseClient _client;

  /// Espelha `fetchEventsAction`: admin vê tudo (incl. rascunhos); os
  /// restantes veem apenas eventos publicados + onde estão escalados.
  Future<List<Event>> fetchEvents(String orgId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');

    final membership = await _client
        .from('organization_members')
        .select('role')
        .eq('org_id', orgId)
        .eq('user_id', userId)
        .maybeSingle();
    final isAdmin = membership?['role'] == 'admin';

    final rows = await _client
        .from('events')
        .select()
        .eq('org_id', orgId)
        .order('date')
        .order('time');
    var events = (rows as List)
        .map((row) => Event.fromMap(row as Map<String, dynamic>))
        .toList();

    if (!isAdmin) {
      final scheduledIds = await _scheduledEventIds(userId);
      events = events
          .where((e) => e.isPublished || scheduledIds.contains(e.id))
          .toList();
    }
    return events;
  }

  Future<Set<String>> _scheduledEventIds(String userId) async {
    final schedules = await _client
        .from('event_schedules')
        .select('event_ministry_id')
        .eq('user_id', userId);
    final emIds = (schedules as List)
        .map((row) => row['event_ministry_id'] as String)
        .toList();
    if (emIds.isEmpty) return {};
    final eventMinistries = await _client
        .from('event_ministries')
        .select('event_id')
        .inFilter('id', emIds);
    return (eventMinistries as List)
        .map((row) => row['event_id'] as String)
        .toSet();
  }

  Future<Event> createEvent(String orgId, EventPayload payload) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    final row = await _client
        .from('events')
        .insert({...payload.toMap(), 'org_id': orgId, 'created_by': userId})
        .select()
        .single();
    return Event.fromMap(row);
  }

  Future<void> updateEvent(String id, EventPayload payload) async {
    await _client
        .from('events')
        .update({
          ...payload.toMap(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteEvent(String id) async {
    await _client.from('events').delete().eq('id', id);
  }

  Future<void> publishEvent(String id, bool publish) async {
    await _client
        .from('events')
        .update({
          'is_published': publish,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<List<EventMinistry>> fetchEventMinistries(String eventId) async {
    final rows = await _client
        .from('event_ministries')
        .select('id, event_id, ministry:ministries(*)')
        .eq('event_id', eventId);
    return (rows as List)
        .map((row) => EventMinistry.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventSchedule>> fetchEventSchedules(
    String eventMinistryId,
  ) async {
    final rows = await _client
        .from('event_schedules')
        .select('*, profile:profiles(full_name, avatar_url)')
        .eq('event_ministry_id', eventMinistryId);
    return (rows as List)
        .map((row) => EventSchedule.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventSetlistItem>> fetchEventSetlist(String eventId) async {
    final rows = await _client
        .from('event_setlists')
        .select('order_index, musical_key, song:songs(*)')
        .eq('event_id', eventId)
        .order('order_index');
    return (rows as List)
        .map((row) => EventSetlistItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventTimelineItem>> fetchEventTimeline(String eventId) async {
    final rows = await _client
        .from('event_timeline_items')
        .select('time, title')
        .eq('event_id', eventId)
        .order('order_index');
    return (rows as List)
        .map((row) => EventTimelineItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<EventSetupData> fetchEventSetup(String eventId) async {
    final eventMinistries = await _client
        .from('event_ministries')
        .select('id, ministry_id')
        .eq('event_id', eventId);

    final ministryIds = <String>[];
    final membersByMinistry = <String, List<EventScheduleAssignment>>{};
    for (final row in eventMinistries as List) {
      final ministryId = row['ministry_id'] as String;
      ministryIds.add(ministryId);
      final schedules = await _client
          .from('event_schedules')
          .select('user_id, functions')
          .eq('event_ministry_id', row['id'] as String);
      membersByMinistry[ministryId] = (schedules as List)
          .map(
            (s) => EventScheduleAssignment(
              userId: s['user_id'] as String,
              functions: (s['functions'] as List? ?? const [])
                  .map((f) => f as String)
                  .toList(),
            ),
          )
          .toList();
    }

    final setlist = await fetchEventSetlist(eventId);
    final songIds = setlist.map((item) => item.song.id).toList();
    final songKeys = <String, String>{
      for (final item in setlist)
        if (item.eventKey != null) item.song.id: item.eventKey!,
    };

    final timeline = await fetchEventTimeline(eventId);

    return EventSetupData(
      ministryIds: ministryIds,
      membersByMinistry: membersByMinistry,
      songIds: songIds,
      songKeys: songKeys,
      timeline: timeline,
    );
  }

  /// Grava tudo o wizard de uma vez: ministérios+integrantes, setlist e
  /// roteiro — apaga e reinsere, espelhando `replaceEventSetupAction`.
  Future<void> replaceEventSetup(
    String eventId,
    List<EventMinistrySetup> setup,
    List<String> songIds,
    Map<String, String> songKeys,
    List<EventTimelineItem> timeline,
  ) async {
    final existingMinistries = await _client
        .from('event_ministries')
        .select('id')
        .eq('event_id', eventId);
    final existingIds = (existingMinistries as List)
        .map((row) => row['id'] as String)
        .toList();
    if (existingIds.isNotEmpty) {
      await _client
          .from('event_schedules')
          .delete()
          .inFilter('event_ministry_id', existingIds);
    }
    await _client.from('event_ministries').delete().eq('event_id', eventId);

    for (final ministrySetup in setup) {
      final eventMinistry = await _client
          .from('event_ministries')
          .insert({
            'event_id': eventId,
            'ministry_id': ministrySetup.ministryId,
          })
          .select()
          .single();
      if (ministrySetup.members.isNotEmpty) {
        await _client.from('event_schedules').insert([
          for (final member in ministrySetup.members)
            {
              'event_ministry_id': eventMinistry['id'],
              'user_id': member.userId,
              'functions': member.functions,
            },
        ]);
      }
    }

    await _client.from('event_setlists').delete().eq('event_id', eventId);
    if (songIds.isNotEmpty) {
      await _client.from('event_setlists').insert([
        for (var i = 0; i < songIds.length; i++)
          {
            'event_id': eventId,
            'song_id': songIds[i],
            'order_index': i,
            'musical_key': songKeys[songIds[i]],
          },
      ]);
    }

    await _client.from('event_timeline_items').delete().eq('event_id', eventId);
    if (timeline.isNotEmpty) {
      final sorted = [...timeline]..sort(EventTimelineItem.compare);
      await _client.from('event_timeline_items').insert([
        for (var i = 0; i < sorted.length; i++)
          {
            'event_id': eventId,
            'time':
                '${sorted[i].time.hour.toString().padLeft(2, '0')}:${sorted[i].time.minute.toString().padLeft(2, '0')}:00',
            'title': sorted[i].title,
            'order_index': i,
          },
      ]);
    }
  }

  /// Só a própria pessoa escalada pode confirmar a sua presença — também
  /// garantido pela policy RLS "event_schedules: own can update confirmed".
  Future<void> confirmSchedule(String id, bool confirmed) async {
    await _client
        .from('event_schedules')
        .update({'confirmed': confirmed})
        .eq('id', id);
  }
}
