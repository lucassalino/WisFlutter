import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/state/org_store.dart';
import '../../auth/data/auth_repository.dart';

/// Fatia mínima de "Definições": sessão + código de convite. As restantes
/// secções (perfil, organização, zona de perigo) ficam para a próxima
/// iteração — ver docs/reference/wis-app-overview-and-rn-prompt.md, tela 14.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(orgStoreProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user.email ?? ''),
              ),
            ),
          if (membership != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(membership.organization.name),
                subtitle: Text(
                  'Código de convite: ${membership.organization.inviteCode}',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              ref.read(orgStoreProvider.notifier).clear();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Terminar sessão'),
          ),
        ],
      ),
    );
  }
}
