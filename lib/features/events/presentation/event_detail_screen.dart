import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/domain/event.dart';
import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../data/events_repository.dart';
import '../domain/event_schedule.dart';
import 'event_form_screen.dart';
import 'events_providers.dart';

enum _DetailTab { team, setlist, timeline }

final _topBarButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

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

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  _DetailTab _tab = _DetailTab.team;

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(orgStoreProvider);
    final isAdmin = membership?.role.isAdmin ?? false;
    final ministriesAsync = ref.watch(eventMinistriesProvider(widget.event.id));
    final setlistAsync = ref.watch(eventSetlistProvider(widget.event.id));
    final timelineAsync = ref.watch(eventTimelineProvider(widget.event.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SpotlightBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Eventos',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isAdmin) ...[
                      OutlinedButton.icon(
                        style: _topBarButtonStyle,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Exportação em PDF ainda não disponível na app.',
                                ),
                              ),
                            ),
                        icon: const Icon(Icons.print_outlined, size: 12),
                        label: const Text('Exportar'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: _topBarButtonStyle,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EventFormScreen(
                              orgId: widget.orgId,
                              event: widget.event,
                            ),
                          ),
                        ),
                        child: const Text('Editar evento'),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    _HeroCard(event: widget.event),
                    if ((widget.event.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _TextSection(
                        label: 'DESCRIÇÃO',
                        text: widget.event.description!,
                      ),
                    ],
                    if ((widget.event.observations ?? '').isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _TextSection(
                        label: 'OBSERVAÇÕES',
                        text: widget.event.observations!,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _TabBarRow(
                      current: _tab,
                      teamCount: ministriesAsync.value?.length ?? 0,
                      setlistCount: setlistAsync.value?.length ?? 0,
                      timelineCount: timelineAsync.value?.length ?? 0,
                      onChanged: (tab) => setState(() => _tab = tab),
                    ),
                    const SizedBox(height: 20),
                    switch (_tab) {
                      _DetailTab.team => _TeamTab(
                        orgId: widget.orgId,
                        event: widget.event,
                      ),
                      _DetailTab.setlist => _SetlistTab(
                        setlistAsync: setlistAsync,
                      ),
                      _DetailTab.timeline => _TimelineTab(
                        timelineAsync: timelineAsync,
                      ),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(event.color);
    final content = _HeroContent(event: event);

    if (event.coverImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.network(
              event.coverImageUrl!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      const Color(0xF00A0A0E),
                      const Color(0xF20A0A0E),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(padding: const EdgeInsets.all(20), child: content),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xD9161619),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.13), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 88,
            color: color,
            margin: const EdgeInsets.only(right: 16),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _EventBadge(
              label: event.isPublished ? 'PUBLICADO' : 'RASCUNHO',
              color: event.isPublished ? const Color(0xFF6EE7B7) : Colors.white,
              strong: event.isPublished,
            ),
            _EventBadge(
              label:
                  '${event.period.emoji} ${event.period.label.toUpperCase()}',
              color: const Color(0xFFA5B4FC),
              strong: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          event.name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _MetaItem(
              icon: Icons.calendar_today_outlined,
              text: DateFormat('dd/MM/yyyy').format(event.date),
            ),
            _MetaItem(icon: Icons.access_time, text: timeLabel),
            if (event.arrivalTime != null)
              _MetaItem(
                icon: Icons.timer_outlined,
                text:
                    'Chegada ${event.arrivalTime!.hour.toString().padLeft(2, '0')}:${event.arrivalTime!.minute.toString().padLeft(2, '0')}',
              ),
            if (event.location != null)
              _MetaItem(
                icon: Icons.location_on_outlined,
                text: event.location!,
              ),
          ],
        ),
      ],
    );
  }
}

class _EventBadge extends StatelessWidget {
  const _EventBadge({
    required this.label,
    required this.color,
    required this.strong,
  });

  final String label;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: strong ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: strong ? 0.3 : 0.1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: strong ? color : Colors.white.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _TabBarRow extends StatelessWidget {
  const _TabBarRow({
    required this.current,
    required this.teamCount,
    required this.setlistCount,
    required this.timelineCount,
    required this.onChanged,
  });

  final _DetailTab current;
  final int teamCount;
  final int setlistCount;
  final int timelineCount;
  final ValueChanged<_DetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TabItem(
              icon: Icons.people_outline,
              label: 'Ministérios & Equipa',
              count: teamCount,
              active: current == _DetailTab.team,
              onTap: () => onChanged(_DetailTab.team),
            ),
            _TabItem(
              icon: Icons.queue_music_outlined,
              label: 'Setlist',
              count: setlistCount,
              active: current == _DetailTab.setlist,
              onTap: () => onChanged(_DetailTab.setlist),
            ),
            _TabItem(
              icon: Icons.access_time,
              label: 'Roteiro',
              count: timelineCount,
              active: current == _DetailTab.timeline,
              onTap: () => onChanged(_DetailTab.timeline),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        margin: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: active ? 0.15 : 0.07),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyTabBox extends StatelessWidget {
  const _EmptyTabBox({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamTab extends ConsumerWidget {
  const _TeamTab({required this.orgId, required this.event});

  final String orgId;
  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministriesAsync = ref.watch(eventMinistriesProvider(event.id));
    return ministriesAsync.when(
      data: (eventMinistries) {
        if (eventMinistries.isEmpty) {
          return const _EmptyTabBox(
            icon: Icons.people_outline,
            message: 'Nenhum ministério atribuído a este evento.',
          );
        }
        return Column(
          children: [
            for (final em in eventMinistries) ...[
              _MinistrySection(eventMinistry: em),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}

class _MinistrySection extends ConsumerWidget {
  const _MinistrySection({required this.eventMinistry});

  final dynamic eventMinistry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(
      eventSchedulesProvider(eventMinistry.id as String),
    );
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final color = hexToColor(eventMinistry.ministry.color as String?);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD9161619),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: schedulesAsync.when(
              data: (schedules) {
                final confirmed = schedules
                    .where((s) => s.confirmed == true)
                    .length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventMinistry.ministry.name as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${schedules.length} pessoa${schedules.length != 1 ? 's' : ''}'
                      '${schedules.isNotEmpty ? ' · $confirmed confirmado${confirmed != 1 ? 's' : ''}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                );
              },
              loading: () => Text(
                eventMinistry.ministry.name as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              error: (_, _) => Text(
                eventMinistry.ministry.name as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          schedulesAsync.when(
            data: (schedules) {
              if (schedules.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nenhuma pessoa escalada',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final schedule in schedules)
                    _ScheduleRow(
                      schedule: schedule,
                      isSelf: schedule.userId == currentUserId,
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erro: $error'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends ConsumerWidget {
  const _ScheduleRow({required this.schedule, required this.isSelf});

  final EventSchedule schedule;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameWords = schedule.fullName.trim().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final initials = nameWords.isNotEmpty
        ? nameWords.map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            backgroundImage: schedule.avatarUrl != null
                ? NetworkImage(schedule.avatarUrl!)
                : null,
            child: schedule.avatarUrl == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelf ? '${schedule.fullName} (tu)' : schedule.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (schedule.functions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final fn in schedule.functions)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              functionLabel(fn),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ConfirmControl(schedule: schedule, isSelf: isSelf),
        ],
      ),
    );
  }
}

class _ConfirmControl extends ConsumerWidget {
  const _ConfirmControl({required this.schedule, required this.isSelf});

  final EventSchedule schedule;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isSelf) {
      final confirmed = schedule.confirmed;
      final label = confirmed == true
          ? 'Confirmado'
          : confirmed == false
          ? 'Recusou'
          : 'Por confirmar';
      final color = confirmed == true
          ? const Color(0xFF6EE7B7)
          : confirmed == false
          ? const Color(0xFFF87171)
          : Colors.white;
      final strong = confirmed != null;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: strong ? 0.13 : 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: strong ? 0.25 : 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: strong ? color : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final isConfirmed = schedule.confirmed == true;
    return OutlinedButton(
      onPressed: () async {
        await ref
            .read(eventsRepositoryProvider)
            .confirmSchedule(schedule.id, !isConfirmed);
        bumpRefreshTick(ref);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isConfirmed
            ? const Color(0xFF6EE7B7).withValues(alpha: 0.15)
            : Colors.white,
        foregroundColor: isConfirmed ? const Color(0xFF6EE7B7) : Colors.black,
        side: BorderSide(
          color: isConfirmed ? const Color(0x4D6EE7B7) : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConfirmed)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.check, size: 13),
            ),
          Text(isConfirmed ? 'Presença confirmada' : 'Confirmar presença'),
        ],
      ),
    );
  }
}

class _SetlistTab extends StatelessWidget {
  const _SetlistTab({required this.setlistAsync});

  final AsyncValue<List<dynamic>> setlistAsync;

  @override
  Widget build(BuildContext context) {
    return setlistAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyTabBox(
            icon: Icons.queue_music_outlined,
            message: 'Nenhuma música no setlist.',
          );
        }
        final hasYoutube = items.any(
          (item) => (item.song.youtubeUrl as String? ?? '').isNotEmpty,
        );
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _SetlistRow(item: items[i], index: i + 1),
              const SizedBox(height: 8),
            ],
            if (hasYoutube)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _openYoutubePlaylist(items),
                  icon: const Icon(
                    Icons.smart_display,
                    size: 16,
                    color: Color(0xFFF87171),
                  ),
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
}

class _SetlistRow extends StatelessWidget {
  const _SetlistRow({required this.item, required this.index});

  final dynamic item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final song = item.song;
    final key = item.eventKey as String? ?? song.musicalKey as String?;
    final bpm = song.bpm;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xD9161619),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$index',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFCD34D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.music_note,
              size: 16,
              color: Color(0xFFFCD34D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.name as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if ((song.artist as String?)?.isNotEmpty ?? false)
                  Text(
                    song.artist as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (key != null) _SmallChip(text: key),
          if (bpm != null) ...[
            const SizedBox(width: 6),
            _SmallChip(text: '$bpm BPM'),
          ],
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.timelineAsync});

  final AsyncValue<List<dynamic>> timelineAsync;

  @override
  Widget build(BuildContext context) {
    return timelineAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyTabBox(
            icon: Icons.access_time,
            message: 'Nenhum momento definido para este evento.',
          );
        }
        final sorted = [...items]
          ..sort(
            (a, b) => (a.timeLabel as String).compareTo(b.timeLabel as String),
          );
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < sorted.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: i < sorted.length - 1
                        ? Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(
                          sorted[i].timeLabel as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          sorted[i].title as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}
