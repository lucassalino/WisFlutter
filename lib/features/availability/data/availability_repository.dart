import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/unavailability_entry.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepository(ref.watch(supabaseClientProvider));
});

class AvailabilityRepository {
  AvailabilityRepository(this._client);

  final SupabaseClient _client;

  Future<List<UnavailabilityEntry>> fetchMyUnavailability(String orgId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    final rows = await _client
        .from('member_unavailability')
        .select()
        .eq('org_id', orgId)
        .eq('user_id', userId)
        .order('created_at');
    return (rows as List)
        .map((row) => UnavailabilityEntry.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Indisponibilidade de toda a organização, agrupada por pessoa — espelha
  /// `fetchOrgUnavailabilityAction`. O `reason` só é devolvido tal como está
  /// para o dono da entrada; para as restantes pessoas fica mascarado a
  /// menos que [canSeeReasons] seja true (admin/líder).
  Future<Map<String, List<UnavailabilityEntry>>> fetchOrgUnavailability(
    String orgId, {
    required bool canSeeReasons,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    final rows = await _client
        .from('member_unavailability')
        .select()
        .eq('org_id', orgId)
        .order('created_at');
    final byUser = <String, List<UnavailabilityEntry>>{};
    for (final row in rows as List) {
      var entry = UnavailabilityEntry.fromMap(row as Map<String, dynamic>);
      if (!canSeeReasons && entry.userId != currentUserId) {
        entry = entry.withMaskedReason();
      }
      byUser.putIfAbsent(entry.userId, () => []).add(entry);
    }
    return byUser;
  }

  Future<void> addDateRangeUnavailability({
    required String orgId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    await _client.from('member_unavailability').insert({
      'org_id': orgId,
      'user_id': userId,
      'kind': UnavailabilityKind.dateRange.value,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      'reason': reason,
    });
  }

  Future<void> addWeeklyUnavailability({
    required String orgId,
    required int weekday,
    String? period,
    String? reason,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    await _client.from('member_unavailability').insert({
      'org_id': orgId,
      'user_id': userId,
      'kind': UnavailabilityKind.weekly.value,
      'weekday': weekday,
      'period': period,
      'reason': reason,
    });
  }

  Future<void> removeUnavailability(String id) async {
    await _client.from('member_unavailability').delete().eq('id', id);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
