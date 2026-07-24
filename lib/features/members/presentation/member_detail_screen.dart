import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../ministries/presentation/ministries_providers.dart';
import '../../onboarding/domain/membership_role.dart';
import '../data/members_repository.dart';
import '../domain/org_member.dart';
import 'members_providers.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({
    super.key,
    required this.orgId,
    required this.member,
    required this.isAdmin,
  });

  final String orgId;
  final OrgMember member;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelf =
        member.userId == Supabase.instance.client.auth.currentUser?.id;
    final membershipsAsync = ref.watch(memberMinistriesProvider(member.userId));
    final ministriesAsync = ref.watch(ministriesListProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: Text(member.fullName),
        actions: [
          if (isAdmin && !isSelf)
            IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remover membro'),
                    content: Text(
                      'Remover "${member.fullName}" da organização?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Remover'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(membersRepositoryProvider)
                      .removeMember(member.membershipId, orgId, member.userId);
                  bumpRefreshTick(ref);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isAdmin)
            Text(member.email, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text('Cargo', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (isAdmin && !isSelf)
            DropdownButtonFormField<MembershipRole>(
              initialValue: member.role,
              items: [
                for (final role in MembershipRole.values)
                  DropdownMenuItem(value: role, child: Text(role.label)),
              ],
              onChanged: (value) async {
                if (value == null) return;
                await ref
                    .read(membersRepositoryProvider)
                    .updateMemberRole(member.membershipId, value);
                bumpRefreshTick(ref);
              },
            )
          else
            Chip(label: Text(member.role.label)),
          const SizedBox(height: 24),
          Text('Ministérios', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          membershipsAsync.when(
            data: (assignments) => ministriesAsync.when(
              data: (ministries) {
                if (assignments.isEmpty) {
                  return const Text('Não pertence a nenhum ministério.');
                }
                return Column(
                  children: [
                    for (final assignment in assignments)
                      Builder(
                        builder: (context) {
                          final ministry = ministries.firstWhere(
                            (m) => m.id == assignment.ministryId,
                            orElse: () => ministries.first,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Text(ministry.icon),
                              title: Text(ministry.name),
                              subtitle: Text(
                                assignment.functions
                                    .map(functionLabel)
                                    .join(', '),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Erro: $error'),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro: $error'),
          ),
        ],
      ),
    );
  }
}
