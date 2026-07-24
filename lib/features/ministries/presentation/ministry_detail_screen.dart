import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/state/refresh_tick.dart';
import '../data/ministries_repository.dart';
import '../domain/ministry.dart';
import 'ministries_providers.dart';
import 'ministry_form_screen.dart';
import 'ministry_members_screen.dart';

class MinistryDetailScreen extends ConsumerWidget {
  const MinistryDetailScreen({
    super.key,
    required this.orgId,
    required this.ministry,
  });

  final String orgId;
  final Ministry ministry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(ministryMembersProvider(ministry.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(ministry.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      MinistryFormScreen(orgId: orgId, ministry: ministry),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final repo = ref.read(ministriesRepositoryProvider);
              if (value == 'toggle') {
                await repo.toggleActive(ministry.id, !ministry.isActive);
                bumpRefreshTick(ref);
                if (context.mounted) Navigator.of(context).pop();
              } else if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Eliminar ministério'),
                    content: Text(
                      'Tens a certeza que queres eliminar "${ministry.name}"? Esta ação não pode ser desfeita.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await repo.deleteMinistry(ministry.id);
                  bumpRefreshTick(ref);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(ministry.isActive ? 'Desativar' : 'Ativar'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(ministry.icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ministry.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (!ministry.isActive)
                      const Text(
                        'Inativo',
                        style: TextStyle(color: Colors.white54),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Funções', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in ministry.functions)
                Chip(
                  label: Text('${functionEmoji(key)} ${functionLabel(key)}'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Membros', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        MinistryMembersScreen(orgId: orgId, ministry: ministry),
                  ),
                ),
                icon: const Icon(Icons.group_outlined),
                label: const Text('Gerir membros'),
              ),
            ],
          ),
          membersAsync.when(
            data: (members) => members.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Ainda sem membros.'),
                  )
                : Column(
                    children: [
                      for (final member in members)
                        Card(
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
                            subtitle: Text(
                              member.functions.map(functionLabel).join(', '),
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('Erro ao carregar membros: $error'),
          ),
        ],
      ),
    );
  }
}
