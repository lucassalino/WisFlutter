import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/state/org_store.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/organization.dart';

class OrgSelectionScreen extends ConsumerStatefulWidget {
  const OrgSelectionScreen({super.key});

  @override
  ConsumerState<OrgSelectionScreen> createState() => _OrgSelectionScreenState();
}

class _OrgSelectionScreenState extends ConsumerState<OrgSelectionScreen> {
  bool _autoSelectAttempted = false;
  bool _autoSelecting = false;

  Future<void> _tryAutoSelect(List<OrganizationMembership> memberships) async {
    if (memberships.isEmpty) return;
    setState(() => _autoSelecting = true);

    OrganizationMembership? target;
    if (memberships.length == 1) {
      target = memberships.first;
    } else {
      final lastOrgId = await OrgStore.readLastOrgId();
      if (lastOrgId != null) {
        for (final m in memberships) {
          if (m.organization.id == lastOrgId) {
            target = m;
            break;
          }
        }
      }
    }

    if (target != null) {
      await ref.read(orgStoreProvider.notifier).setActive(target);
    } else if (mounted) {
      setState(() => _autoSelecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membershipsAsync = ref.watch(myMembershipsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Terminar sessão',
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
        ),
        title: const Text('As tuas organizações'),
      ),
      body: membershipsAsync.when(
        data: (memberships) {
          if (!_autoSelectAttempted) {
            _autoSelectAttempted = true;
            _tryAutoSelect(memberships);
          }
          if (_autoSelecting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (memberships.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ainda não pertences a nenhuma organização. Cria uma nova ou entra com um código de convite.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: memberships.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final membership = memberships[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: membership.organization.logoUrl != null
                        ? NetworkImage(membership.organization.logoUrl!)
                        : null,
                    child: membership.organization.logoUrl == null
                        ? Text(
                            membership.organization.name.isNotEmpty
                                ? membership.organization.name[0].toUpperCase()
                                : '?',
                          )
                        : null,
                  ),
                  title: Text(membership.organization.name),
                  subtitle: Text(membership.role.label),
                  onTap: () =>
                      ref.read(orgStoreProvider.notifier).setActive(membership),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar organizações: $error')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/join-org'),
                  child: const Text('Entrar com código'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/new-org'),
                  child: const Text('Criar organização'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
