import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ministries_providers.dart';
import 'ministry_detail_screen.dart';
import 'ministry_form_screen.dart';

class MinistriesListScreen extends ConsumerWidget {
  const MinistriesListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministriesAsync = ref.watch(ministriesListProvider(orgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Ministérios')),
      body: ministriesAsync.when(
        data: (ministries) {
          if (ministries.isEmpty) {
            return const Center(child: Text('Ainda não há ministérios.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ministries.length,
            itemBuilder: (context, index) {
              final ministry = ministries[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Opacity(
                  opacity: ministry.isActive ? 1 : 0.5,
                  child: ListTile(
                    leading: Text(
                      ministry.icon,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(ministry.name),
                    subtitle: Text(
                      ministry.isActive
                          ? '${ministry.functions.length} funções'
                          : 'Inativo',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MinistryDetailScreen(
                          orgId: orgId,
                          ministry: ministry,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar ministérios: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MinistryFormScreen(orgId: orgId),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
