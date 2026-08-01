import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_providers.dart';
import '../domain/org_member_option.dart';

final rosterRepositoryProvider = Provider<RosterRepository>((ref) {
  return RosterRepository(ref.watch(supabaseClientProvider));
});

final activeRosterProvider =
    FutureProvider.family<List<OrgMemberOption>, String>((ref, orgId) {
      return ref.watch(rosterRepositoryProvider).fetchActiveMembers(orgId);
    });

/// Lista de pessoas da organização usada em seletores (adicionar a um
/// ministério, escalar para um evento). Reaproveitada por várias features.
class RosterRepository {
  RosterRepository(this._client);

  final SupabaseClient _client;

  Future<List<OrgMemberOption>> fetchActiveMembers(String orgId) async {
    final rows = await _client
        .from('organization_members')
        .select('user_id, profile:profiles(full_name, avatar_url)')
        .eq('org_id', orgId)
        .eq('is_active', true);
    final members = (rows as List)
        .map((row) => OrgMemberOption.fromMap(row as Map<String, dynamic>))
        .toList();
    members.sort((a, b) => a.fullName.compareTo(b.fullName));
    return members;
  }
}
