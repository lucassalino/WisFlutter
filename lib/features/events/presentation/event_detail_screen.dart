import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/domain/event.dart';
import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../data/events_repository.dart';
import '../domain/event_schedule.dart';
import 'event_form_screen.dart';
import 'events_providers.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.orgId,
    required this.event,
  });

  final String orgId;
  final Event event;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(orgStoreProvider);
    final isAdmin = membership?.role.isAdmin ?? false;
    final timeLabel =
        '${widget.event.time.hour.toString().padLeft(2, '0')}:${widget.event.time.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.name),
        actions: isAdmin
            ? [
                IconButton(
                  icon: Icon(
                    widget.event.isPublished
                        ? Icons.unpublished_outlined
                        : Icons.publish_outlined,
                  ),
                  tooltip: widget.event.isPublished
                      ? 'Despublicar'
                      : 'Publicar',
                  onPressed: () async {
                    await ref
                        .read(eventsRepositoryProvider)
                        .publishEvent(
                          widget.event.id,
                          !widget.event.isPublished,
                        );
                    bumpRefreshTick(ref);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EventFormScreen(
                        orgId: widget.orgId,
                        event: widget.event,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminar evento'),
                        content: Text('Eliminar "${widget.event.name}"?'),
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
                      await ref
                          .read(eventsRepositoryProvider)
                          .deleteEvent(widget.event.id);
                      bumpRefreshTick(ref);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Equipa'),
            Tab(text: 'Setlist'),
            Tab(text: 'Roteiro'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    '${widget.event.date.day}/${widget.event.date.month}/${widget.event.date.year}',
                  ),
                ),
                Chip(label: Text(timeLabel)),
                if (widget.event.arrivalTime != null)
                  Chip(
                    label: Text(
                      'Chegada: ${widget.event.arrivalTime!.hour.toString().padLeft(2, '0')}:${widget.event.arrivalTime!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                if (widget.event.location != null)
                  Chip(label: Text(widget.event.location!)),
                Chip(
                  label: Text(
                    widget.event.isPublished ? 'Publicado' : 'Rascunho',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTeamTab(),
                _buildSetlistTab(),
                _buildTimelineTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab() {
    final ministriesAsync = ref.watch(eventMinistriesProvider(widget.event.id));
    return ministriesAsync.when(
      data: (eventMinistries) {
        if (eventMinistries.isEmpty) {
          return const Center(child: Text('Sem ministérios escalados.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final eventMinistry in eventMinistries)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${eventMinistry.ministry.icon} ${eventMinistry.ministry.name}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _buildSchedulesList(eventMinistry.id),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  Widget _buildSchedulesList(String eventMinistryId) {
    final schedulesAsync = ref.watch(eventSchedulesProvider(eventMinistryId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return schedulesAsync.when(
      data: (schedules) {
        if (schedules.isEmpty) return const Text('Ninguém escalado.');
        return Column(
          children: [
            for (final schedule in schedules)
              _buildScheduleTile(schedule, currentUserId),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('Erro: $error'),
    );
  }

  Widget _buildScheduleTile(EventSchedule schedule, String? currentUserId) {
    final isSelf = schedule.userId == currentUserId;
    Widget statusIcon;
    if (schedule.confirmed == true) {
      statusIcon = const Icon(Icons.check_circle, color: Colors.greenAccent);
    } else if (schedule.confirmed == false) {
      statusIcon = const Icon(Icons.cancel, color: Colors.redAccent);
    } else {
      statusIcon = const Icon(Icons.hourglass_empty, color: Colors.white38);
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(schedule.fullName),
      subtitle: Text(schedule.functions.map(functionLabel).join(', ')),
      trailing: isSelf
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                  ),
                  onPressed: () => _confirm(schedule, true),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _confirm(schedule, false),
                ),
              ],
            )
          : statusIcon,
    );
  }

  Future<void> _confirm(EventSchedule schedule, bool confirmed) async {
    await ref
        .read(eventsRepositoryProvider)
        .confirmSchedule(schedule.id, confirmed);
    bumpRefreshTick(ref);
  }

  Widget _buildSetlistTab() {
    final setlistAsync = ref.watch(eventSetlistProvider(widget.event.id));
    return setlistAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Sem músicas neste evento.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.song.name),
                  subtitle: Text(
                    [
                      if (item.song.artist != null) item.song.artist!,
                      if (item.eventKey != null) 'Tom: ${item.eventKey}',
                      if (item.song.bpm != null) '${item.song.bpm} BPM',
                    ].join(' · '),
                  ),
                ),
              ),
            if (items.any((item) => (item.song.youtubeUrl ?? '').isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _openYoutubePlaylist(items),
                  icon: const Icon(Icons.playlist_play),
                  label: const Text('Abrir playlist no YouTube'),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  Future<void> _openYoutubePlaylist(List<dynamic> items) async {
    final videoIds = <String>[];
    for (final item in items) {
      final url = item.song.youtubeUrl as String?;
      if (url == null || url.isEmpty) continue;
      final id = _extractYoutubeId(url);
      if (id != null) videoIds.add(id);
    }
    if (videoIds.isEmpty) return;
    final uri = Uri.parse(
      'https://www.youtube.com/watch_videos?video_ids=${videoIds.join(',')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? _extractYoutubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return uri.queryParameters['v'];
  }

  Widget _buildTimelineTab() {
    final timelineAsync = ref.watch(eventTimelineProvider(widget.event.id));
    return timelineAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Sem roteiro definido.'));
        }
        final sorted = [...items]
          ..sort((a, b) => a.timeLabel.compareTo(b.timeLabel));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in sorted)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(item.timeLabel),
                  title: Text(item.title),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}
