import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/pending_invite.dart';

final invitesRepositoryProvider = Provider<InvitesRepository>((ref) {
  return InvitesRepository(ref.watch(supabaseClientProvider));
});

class InviteCreateResult {
  const InviteCreateResult({
    required this.emailSent,
    required this.alreadyRegistered,
  });
  final bool emailSent;
  final bool alreadyRegistered;
}

/// A app móvel não tem servidor próprio, por isso os convites (que
/// precisam da service role para criar contas / contornar RLS em
/// `organization_invites`, que não tem policies para clientes) passam pela
/// Edge Function `manage-invite` já existente no projeto Supabase —
/// espelha 1:1 src/actions/invites.ts.
class InvitesRepository {
  InvitesRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(
      'manage-invite',
      body: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw StateError(data['error'] as String);
    }
    return data as Map<String, dynamic>;
  }

  Future<InviteCreateResult> createInvite({
    required String orgId,
    required String name,
    required String email,
    required String role,
  }) async {
    final data = await _invoke({
      'action': 'create',
      'orgId': orgId,
      'name': name,
      'email': email,
      'role': role,
    });
    return InviteCreateResult(
      emailSent: data['emailSent'] as bool? ?? false,
      alreadyRegistered: data['alreadyRegistered'] as bool? ?? false,
    );
  }

  Future<List<PendingInvite>> fetchPendingInvites(String orgId) async {
    final data = await _invoke({'action': 'list', 'orgId': orgId});
    final invites = data['invites'] as List? ?? const [];
    return invites
        .map((row) => PendingInvite.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteInvite(String orgId, String inviteId) async {
    await _invoke({'action': 'delete', 'orgId': orgId, 'inviteId': inviteId});
  }

  /// Aceita convites pendentes para o email do utilizador atual — deve ser
  /// chamada depois do login.
  Future<int> acceptPendingInvites() async {
    final data = await _invoke({'action': 'acceptPending'});
    return data['accepted'] as int? ?? 0;
  }
}
