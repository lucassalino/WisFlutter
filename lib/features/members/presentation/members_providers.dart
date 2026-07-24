import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/refresh_tick.dart';
import '../data/invites_repository.dart';
import '../data/members_repository.dart';
import '../domain/org_member.dart';
import '../domain/pending_invite.dart';

final membersListProvider = FutureProvider.family<List<OrgMember>, String>((
  ref,
  orgId,
) {
  ref.watch(refreshTickProvider);
  return ref.watch(membersRepositoryProvider).fetchMembers(orgId);
});

final pendingInvitesProvider =
    FutureProvider.family<List<PendingInvite>, String>((ref, orgId) {
      ref.watch(refreshTickProvider);
      return ref.watch(invitesRepositoryProvider).fetchPendingInvites(orgId);
    });

final memberMinistriesProvider =
    FutureProvider.family<
      List<({String ministryId, List<String> functions})>,
      String
    >((ref, userId) {
      ref.watch(refreshTickProvider);
      return ref.watch(membersRepositoryProvider).fetchMemberMinistries(userId);
    });
