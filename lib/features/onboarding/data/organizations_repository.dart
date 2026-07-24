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

enum LeaveOrgResult { left, needsDelete, onlyAdminBlocked }

class OrganizationsRepository {
  OrganizationsRepository(this._client);

  final SupabaseClient _client;

  /// Organizações a que o utilizador autenticado pertence (com o seu cargo),
  /// espelhando `fetchOrgMembershipsAction` na app web.
  Future<List<OrganizationMembership>> fetchMyMemberships() async {
    final userId = _requireUserId();
    await _acceptPendingInvites();
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

  /// Aceita automaticamente convites pendentes para o email do utilizador
  /// atual (via Edge Function `manage-invite`) — chamado sempre que se
  /// carregam as organizações, para nunca ficar um convite por aceitar
  /// depois do login. Falhas são ignoradas: não bloqueia a app.
  Future<void> _acceptPendingInvites() async {
    try {
      await _client.functions.invoke(
        'manage-invite',
        body: {'action': 'acceptPending'},
      );
    } catch (_) {
      // Best-effort — a pessoa pode sempre entrar manualmente por código.
    }
  }

  Future<void> updateOrganizationName(String orgId, String name) async {
    await _client
        .from('organizations')
        .update({'name': name, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', orgId);
  }

  /// Sair da organização — espelha `leaveOrganizationAction`. Se for a
  /// última pessoa, sair significa eliminar a organização (needsDelete).
  /// Se for o único admin com mais gente na organização, bloqueia.
  Future<LeaveOrgResult> leaveOrganization(String orgId) async {
    final userId = _requireUserId();
    final rows = await _client
        .from('organization_members')
        .select('user_id, role')
        .eq('org_id', orgId)
        .eq('is_active', true);
    final members = (rows as List).cast<Map<String, dynamic>>();

    final isLastPerson =
        members.length <= 1 && members.every((m) => m['user_id'] == userId);
    if (isLastPerson) return LeaveOrgResult.needsDelete;

    final admins = members.where((m) => m['role'] == 'admin').toList();
    final isOnlyAdmin = admins.length == 1 && admins.first['user_id'] == userId;
    if (isOnlyAdmin) return LeaveOrgResult.onlyAdminBlocked;

    await _client
        .from('organization_members')
        .delete()
        .eq('org_id', orgId)
        .eq('user_id', userId);
    return LeaveOrgResult.left;
  }

  /// Elimina permanentemente a organização. As tabelas dependentes têm
  /// `on delete cascade` a partir de `organizations`, por isso um único
  /// delete já limpa ministérios, eventos, escalas, músicas, convites, etc.
  Future<void> deleteOrganization(String orgId) async {
    await _client.from('organizations').delete().eq('id', orgId);
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
