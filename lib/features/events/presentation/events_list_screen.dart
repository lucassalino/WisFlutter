import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/domain/event.dart';
import '../../../shared/state/org_store.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'events_providers.dart';

enum _EventFilter { all, published, drafts }

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  _EventFilter _filter = _EventFilter.all;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsListProvider(widget.orgId));
    final membership = ref.watch(orgStoreProvider);
    final isAdmin = membership?.role.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _filter == _EventFilter.all,
                    onSelected: (_) =>
                        setState(() => _filter = _EventFilter.all),
                  ),
                  ChoiceChip(
                    label: const Text('Publicados'),
                    selected: _filter == _EventFilter.published,
                    onSelected: (_) =>
                        setState(() => _filter = _EventFilter.published),
                  ),
                  ChoiceChip(
                    label: const Text('Rascunhos'),
                    selected: _filter == _EventFilter.drafts,
                    onSelected: (_) =>
                        setState(() => _filter = _EventFilter.drafts),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                final filtered = events.where((e) {
                  return switch (_filter) {
                    _EventFilter.all => true,
                    _EventFilter.published => e.isPublished,
                    _EventFilter.drafts => !e.isPublished,
                  };
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Sem eventos.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _EventCard(orgId: widget.orgId, event: filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Erro ao carregar eventos: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventFormScreen(orgId: widget.orgId),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.orgId, required this.event});

  final String orgId;
  final Event event;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM yyyy', 'pt').format(event.date);
    final timeLabel =
        '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(event.period.emoji, style: const TextStyle(fontSize: 24)),
        title: Text(event.name),
        subtitle: Text(
          '$dateLabel · $timeLabel${event.location != null ? ' · ${event.location}' : ''}',
        ),
        trailing: Chip(
          label: Text(event.isPublished ? 'Publicado' : 'Rascunho'),
          visualDensity: VisualDensity.compact,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(orgId: orgId, event: event),
          ),
        ),
      ),
    );
  }
}
