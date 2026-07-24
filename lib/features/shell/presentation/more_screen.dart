import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/state/org_store.dart';
import '../../../shared/widgets/coming_soon_screen.dart';
import '../../members/presentation/members_list_screen.dart';
import '../../ministries/presentation/ministries_list_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// Hub "Mais": acesso às secções que não cabem na bottom nav (Ministérios,
/// Pessoas, Notificações, Definições). Ver
/// docs/reference/wis-app-overview-and-rn-prompt.md, tela 14.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(orgStoreProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final orgId = membership?.organization.id;

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
          const SizedBox(height: 12),
          if (orgId != null)
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.groups_2_outlined),
                    title: const Text('Ministérios'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            MinistriesListScreen(orgId: orgId),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Pessoas'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MembersListScreen(orgId: orgId),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notificações'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ComingSoonScreen(
                          title: 'Notificações',
                          icon: Icons.notifications_outlined,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Definições'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
