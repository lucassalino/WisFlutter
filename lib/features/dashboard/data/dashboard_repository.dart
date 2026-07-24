import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/birthday_person.dart';
import '../domain/dashboard_summary.dart';
import '../../../shared/domain/event.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<DashboardSummary> fetchSummary(String orgId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');

    final membership = await _client
        .from('organization_members')
        .select('role')
        .eq('org_id', orgId)
        .eq('user_id', userId)
        .maybeSingle();
    final isAdmin = membership?['role'] == 'admin';

    final today = DateTime.now();
    final todayIso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final eventRows = await _client
        .from('events')
        .select()
        .eq('org_id', orgId)
        .gte('date', todayIso)
        .order('date')
        .order('time');
    var events = (eventRows as List)
        .map((row) => Event.fromMap(row as Map<String, dynamic>))
        .toList();

    if (!isAdmin) {
      final scheduledEventIds = await _scheduledEventIds(userId);
      events = events
          .where((e) => e.isPublished || scheduledEventIds.contains(e.id))
          .toList();
    }

    final upcomingEvents = events.take(5).toList();
    final pendingConfirmations = await _countPendingConfirmations(
      upcomingEvents.map((e) => e.id).toList(),
    );
    final birthdays = await _fetchBirthdaysThisMonth(orgId);

    return DashboardSummary(
      isAdmin: isAdmin,
      upcomingEvents: upcomingEvents,
      pendingConfirmations: pendingConfirmations,
      birthdaysThisMonth: birthdays,
    );
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

  Future<int> _countPendingConfirmations(List<String> eventIds) async {
    if (eventIds.isEmpty) return 0;

    final eventMinistries = await _client
        .from('event_ministries')
        .select('id')
        .inFilter('event_id', eventIds);
    final eventMinistryIds = (eventMinistries as List)
        .map((row) => row['id'] as String)
        .toList();
    if (eventMinistryIds.isEmpty) return 0;

    final pending = await _client
        .from('event_schedules')
        .select('id')
        .inFilter('event_ministry_id', eventMinistryIds)
        .isFilter('confirmed', null);
    return (pending as List).length;
  }

  Future<List<BirthdayPerson>> _fetchBirthdaysThisMonth(String orgId) async {
    final currentMonth = DateTime.now().month;
    final memberRows = await _client
        .from('organization_members')
        .select('profile:profiles(full_name, avatar_url, birthday)')
        .eq('org_id', orgId)
        .eq('is_active', true);

    final people = <BirthdayPerson>[];
    for (final row in memberRows as List) {
      final profile =
          (row as Map<String, dynamic>)['profile'] as Map<String, dynamic>?;
      final birthday = profile?['birthday'] as String?;
      if (profile == null || birthday == null) continue;

      final month = int.parse(birthday.substring(5, 7));
      if (month != currentMonth) continue;

      people.add(
        BirthdayPerson(
          name: profile['full_name'] as String? ?? '',
          avatarUrl: profile['avatar_url'] as String?,
          day: int.parse(birthday.substring(8, 10)),
          month: month,
        ),
      );
    }
    people.sort((a, b) => a.day.compareTo(b.day));
    return people;
  }
}
