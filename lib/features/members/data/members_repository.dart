import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../onboarding/domain/membership_role.dart';
import '../domain/org_member.dart';

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  return MembersRepository(ref.watch(supabaseClientProvider));
});

class MembersRepository {
  MembersRepository(this._client);

  final SupabaseClient _client;

  Future<List<OrgMember>> fetchMembers(String orgId) async {
    final rows = await _client
        .from('organization_members')
        .select('*, profile:profiles(full_name, email, avatar_url, phone)')
        .eq('org_id', orgId)
        .order('joined_at');
    return (rows as List)
        .map((row) => OrgMember.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateMemberRole(
    String membershipId,
    MembershipRole role,
  ) async {
    await _client
        .from('organization_members')
        .update({'role': role.value})
        .eq('id', membershipId);
  }

  /// Remove definitivamente uma pessoa da organização e limpa as suas
  /// atribuições (ministérios e escalas) desta org — espelha
  /// `deleteMemberAction`. Não apaga a conta/perfil global.
  Future<void> removeMember(
    String membershipId,
    String orgId,
    String userId,
  ) async {
    final ministries = await _client
        .from('ministries')
        .select('id')
        .eq('org_id', orgId);
    final ministryIds = (ministries as List)
        .map((row) => row['id'] as String)
        .toList();
    if (ministryIds.isNotEmpty) {
      await _client
          .from('ministry_members')
          .delete()
          .eq('user_id', userId)
          .inFilter('ministry_id', ministryIds);
    }

    final events = await _client
        .from('events')
        .select('id')
        .eq('org_id', orgId);
    final eventIds = (events as List)
        .map((row) => row['id'] as String)
        .toList();
    if (eventIds.isNotEmpty) {
      final eventMinistries = await _client
          .from('event_ministries')
          .select('id')
          .inFilter('event_id', eventIds);
      final emIds = (eventMinistries as List)
          .map((row) => row['id'] as String)
          .toList();
      if (emIds.isNotEmpty) {
        await _client
            .from('event_schedules')
            .delete()
            .eq('user_id', userId)
            .inFilter('event_ministry_id', emIds);
      }
    }

    await _client.from('organization_members').delete().eq('id', membershipId);
  }

  Future<List<({String ministryId, List<String> functions})>>
  fetchMemberMinistries(String userId) async {
    final rows = await _client
        .from('ministry_members')
        .select('ministry_id, functions')
        .eq('user_id', userId)
        .eq('is_active', true);
    return (rows as List)
        .map(
          (row) => (
            ministryId: row['ministry_id'] as String,
            functions: (row['functions'] as List? ?? const [])
                .map((f) => f as String)
                .toList(),
          ),
        )
        .toList();
  }
}
