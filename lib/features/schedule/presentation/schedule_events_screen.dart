import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../events/presentation/events_providers.dart';
import 'schedule_editor_screen.dart';

/// Tab "Escala" — lista de eventos; ao selecionar um, abre o editor de
/// ministérios/slots (ScheduleEditorScreen). Espelha ScheduleClient.tsx.
class ScheduleEventsScreen extends ConsumerWidget {
  const ScheduleEventsScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsListProvider(orgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Escala')),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('Sem eventos ainda.'));
          }
          final sorted = [...events]..sort((a, b) => a.date.compareTo(b.date));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final event = sorted[index];
              final dateLabel = DateFormat(
                'd MMM yyyy',
                'pt',
              ).format(event.date);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(
                    event.period.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(event.name),
                  subtitle: Text(dateLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ScheduleEditorScreen(orgId: orgId, event: event),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar eventos: $error')),
      ),
    );
  }
}
