import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/event.dart';
import '../../../shared/state/refresh_tick.dart';
import '../data/events_repository.dart';
import '../domain/event_ministry.dart';
import '../domain/event_schedule.dart';
import '../domain/event_setlist_item.dart';
import '../domain/event_timeline_item.dart';

final eventsListProvider = FutureProvider.family<List<Event>, String>((
  ref,
  orgId,
) {
  ref.watch(refreshTickProvider);
  return ref.watch(eventsRepositoryProvider).fetchEvents(orgId);
});

final eventMinistriesProvider =
    FutureProvider.family<List<EventMinistry>, String>((ref, eventId) {
      ref.watch(refreshTickProvider);
      return ref.watch(eventsRepositoryProvider).fetchEventMinistries(eventId);
    });

final eventSchedulesProvider =
    FutureProvider.family<List<EventSchedule>, String>((ref, eventMinistryId) {
      ref.watch(refreshTickProvider);
      return ref
          .watch(eventsRepositoryProvider)
          .fetchEventSchedules(eventMinistryId);
    });

final eventSetlistProvider =
    FutureProvider.family<List<EventSetlistItem>, String>((ref, eventId) {
      ref.watch(refreshTickProvider);
      return ref.watch(eventsRepositoryProvider).fetchEventSetlist(eventId);
    });

final eventTimelineProvider =
    FutureProvider.family<List<EventTimelineItem>, String>((ref, eventId) {
      ref.watch(refreshTickProvider);
      return ref.watch(eventsRepositoryProvider).fetchEventTimeline(eventId);
    });
