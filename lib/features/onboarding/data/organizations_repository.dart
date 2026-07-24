import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/organization.dart';

final organizationsRepositoryProvider = Provider<OrganizationsRepository>((
  ref,
) {
  return OrganizationsRepository(ref.watch(supabaseClientProvider));
});

class OrganizationsRepository {
  OrganizationsRepository(this._client);

  final SupabaseClient _client;

  /// Organizações a que o utilizador autenticado pertence (com o seu cargo),
  /// espelhando `fetchOrgMembershipsAction` na app web.
  Future<List<OrganizationMembership>> fetchMyMemberships() async {
    final userId = _requireUserId();
    final rows = await _client
        .from('organization_members')
        .select(
          'id, role, is_active, organizations(id, name, logo_url, invite_code)',
        )
        .eq('user_id', userId)
        .eq('is_active', true);
    return (rows as List)
        .map(
          (row) => OrganizationMembership.fromMap(row as Map<String, dynamic>),
        )
        .toList();
  }

  /// Cria uma organização nova e torna o utilizador atual o seu admin.
  /// RLS permite a qualquer utilizador autenticado inserir em `organizations`,
  /// e inserir a sua própria linha em `organization_members` — sem precisar
  /// de nenhum backend privilegiado.
  Future<Organization> createOrganization(String name) async {
    final userId = _requireUserId();
    final inviteCode = _generateInviteCode();

    final orgRow = await _client
        .from('organizations')
        .insert({'name': name, 'invite_code': inviteCode})
        .select()
        .single();
    final organization = Organization.fromMap(orgRow);

    await _client.from('organization_members').insert({
      'org_id': organization.id,
      'user_id': userId,
      'role': 'admin',
    });

    return organization;
  }

  /// Entra numa organização através do código de convite.
  ///
  /// Antes de ser membro, o RLS de `organizations` bloqueia a leitura direta
  /// da linha por `invite_code` — por isso a resolução do código passa pela
  /// função `resolve_invite_code` (SECURITY DEFINER), que devolve apenas o
  /// id da organização, nunca os seus dados completos.
  Future<String> joinOrganizationByCode(String code) async {
    final userId = _requireUserId();
    final normalized = code.trim().toUpperCase();

    final orgId =
        await _client.rpc('resolve_invite_code', params: {'p_code': normalized})
            as String?;
    if (orgId == null) {
      throw StateError('Código de convite inválido');
    }

    final existing = await _client
        .from('organization_members')
        .select('id')
        .eq('org_id', orgId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('organization_members').insert({
        'org_id': orgId,
        'user_id': userId,
        'role': 'member',
      });
    }

    return orgId;
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    return userId;
  }

  static const _codeChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  String _generateInviteCode() {
    final random = Random.secure();
    return List.generate(
      6,
      (_) => _codeChars[random.nextInt(_codeChars.length)],
    ).join();
  }
}
