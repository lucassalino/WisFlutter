import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/domain/event.dart';
import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../shell/presentation/app_drawer.dart';
import '../../shell/presentation/wis_header_bar.dart';
import '../data/events_repository.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'events_providers.dart';

enum _EventFilter { all, upcoming, past, published, drafts }

const _filterLabels = {
  _EventFilter.all: 'Todos',
  _EventFilter.upcoming: 'Próximos',
  _EventFilter.past: 'Passados',
  _EventFilter.published: 'Publicados',
  _EventFilter.drafts: 'Rascunhos',
};

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  _EventFilter _filter = _EventFilter.upcoming;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsListProvider(widget.orgId));
    final membership = ref.watch(orgStoreProvider);
    final isAdmin = membership?.role.isAdmin ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const WisHeaderBar(),
      drawer: const AppDrawer(current: AppDrawerItem.events),
      body: SpotlightBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GESTÃO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Eventos',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Gere os eventos da organização',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            EventFormScreen(orgId: widget.orgId),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Novo Evento'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Pesquisar por nome ou local...',
              ),
              onChanged: (value) =>
                  setState(() => _search = value.toLowerCase()),
            ),
            const SizedBox(height: 10),
            _FilterDropdown(
              value: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 20),
            eventsAsync.when(
              data: (events) {
                final today = DateTime.now();
                final todayDate = DateTime(today.year, today.month, today.day);
                final filtered = events.where((e) {
                  if (_search.isNotEmpty) {
                    final matches =
                        e.name.toLowerCase().contains(_search) ||
                        (e.location?.toLowerCase().contains(_search) ?? false);
                    if (!matches) return false;
                  }
                  return switch (_filter) {
                    _EventFilter.all => true,
                    _EventFilter.upcoming => !e.date.isBefore(todayDate),
                    _EventFilter.past => e.date.isBefore(todayDate),
                    _EventFilter.published => e.isPublished,
                    _EventFilter.drafts => !e.isPublished,
                  };
                }).toList()..sort((a, b) => a.date.compareTo(b.date));

                if (filtered.isEmpty) {
                  return _EmptyState(
                    filtered: events.isNotEmpty,
                    isAdmin: isAdmin,
                    orgId: widget.orgId,
                  );
                }
                return Column(
                  children: [
                    for (final event in filtered) ...[
                      _EventCard(
                        orgId: widget.orgId,
                        event: event,
                        isAdmin: isAdmin,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) =>
                  Center(child: Text('Erro ao carregar eventos: $error')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.onChanged});

  final _EventFilter value;
  final ValueChanged<_EventFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final selected = await showModalBottomSheet<_EventFilter>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in _filterLabels.entries)
                  ListTile(
                    title: Text(entry.value),
                    trailing: entry.key == value
                        ? const Icon(Icons.check, size: 18)
                        : null,
                    onTap: () => Navigator.of(context).pop(entry.key),
                  ),
              ],
            ),
          ),
        );
        if (selected != null) onChanged(selected);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_filterLabels[value]!, style: const TextStyle(fontSize: 14)),
            Icon(
              Icons.expand_more,
              size: 18,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filtered,
    required this.isAdmin,
    required this.orgId,
  });

  final bool filtered;
  final bool isAdmin;
  final String orgId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: const Color(0xD9161619),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 40,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            filtered
                ? 'Nenhum evento encontrado.'
                : 'Nenhum evento criado ainda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          if (isAdmin && !filtered) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventFormScreen(orgId: orgId),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16),
                  SizedBox(width: 8),
                  Text('Criar primeiro evento'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({
    required this.orgId,
    required this.event,
    required this.isAdmin,
  });

  final String orgId;
  final Event event;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = hexToColor(event.color);
    final dateLabel = DateFormat('d MMM yyyy', 'pt').format(event.date);
    final timeLabel =
        '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';

    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EventDetailScreen(orgId: orgId, event: event),
        ),
      ),
      child: Row(
        children: [
          if (event.coverImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                event.coverImageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          else
            SizedBox(
              height: 40,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusBadge(isPublished: event.isPublished),
                    const SizedBox(width: 6),
                    _PeriodBadge(event: event),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                    if (event.location != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          event.location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              color: Colors.white.withValues(alpha: 0.35),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      EventFormScreen(orgId: orgId, event: event),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              color: Colors.white.withValues(alpha: 0.35),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover evento?'),
        content: Text('Tens a certeza que queres remover "${event.name}"?'),
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
    if (confirmed != true) return;
    await ref.read(eventsRepositoryProvider).deleteEvent(event.id);
    if (context.mounted) bumpRefreshTick(ref);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isPublished});

  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    final color = isPublished ? const Color(0xFF6EE7B7) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isPublished ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isPublished ? 0.25 : 0.1),
        ),
      ),
      child: Text(
        isPublished ? 'Publicado' : 'Rascunho',
        style: TextStyle(
          color: isPublished ? color : Colors.white.withValues(alpha: 0.45),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PeriodBadge extends StatelessWidget {
  const _PeriodBadge({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFA5B4FC);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${event.period.emoji} ${event.period.label.toUpperCase()}',
        style: const TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
