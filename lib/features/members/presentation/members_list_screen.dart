import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../data/invites_repository.dart';
import 'invite_member_screen.dart';
import 'member_detail_screen.dart';
import 'members_providers.dart';

class MembersListScreen extends ConsumerWidget {
  const MembersListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersListProvider(orgId));
    final membership = ref.watch(orgStoreProvider);
    final isAdmin = membership?.role.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Pessoas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          membersAsync.when(
            data: (members) => Column(
              children: [
                for (final member in members)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: member.avatarUrl != null
                            ? NetworkImage(member.avatarUrl!)
                            : null,
                        child: member.avatarUrl == null
                            ? Text(
                                member.fullName.isNotEmpty
                                    ? member.fullName[0]
                                    : '?',
                              )
                            : null,
                      ),
                      title: Text(member.fullName),
                      subtitle: Text(member.role.label),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MemberDetailScreen(
                            orgId: orgId,
                            member: member,
                            isAdmin: isAdmin,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Erro ao carregar pessoas: $error')),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            Text(
              'Convites pendentes',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            _PendingInvitesSection(orgId: orgId),
          ],
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InviteMemberScreen(orgId: orgId),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Convidar'),
            )
          : null,
    );
  }
}

class _PendingInvitesSection extends ConsumerWidget {
  const _PendingInvitesSection({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(pendingInvitesProvider(orgId));
    return invitesAsync.when(
      data: (invites) {
        if (invites.isEmpty) {
          return const Text(
            'Sem convites pendentes.',
            style: TextStyle(color: Colors.white54),
          );
        }
        return Column(
          children: [
            for (final invite in invites)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(invite.name),
                  subtitle: Text('${invite.email} · ${invite.role.label}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await ref
                          .read(invitesRepositoryProvider)
                          .deleteInvite(orgId, invite.id);
                      bumpRefreshTick(ref);
                    },
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('Erro: $error'),
    );
  }
}
