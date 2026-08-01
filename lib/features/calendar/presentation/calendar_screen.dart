import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/roster_repository.dart';
import '../../../shared/domain/event.dart';
import '../../../shared/domain/org_member_option.dart';
import '../../../shared/utils/availability_utils.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../availability/domain/unavailability_entry.dart';
import '../../availability/presentation/availability_providers.dart';
import '../../events/presentation/event_detail_screen.dart';
import '../../events/presentation/events_providers.dart';
import '../../shell/presentation/app_drawer.dart';
import '../../shell/presentation/wis_header_bar.dart';

const _defaultEventColor = Color(0xFFA5B4FC);
const _unavailColor = Color(0xFFF87171);

const _monthLabels = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const _weekdayHeaderLabels = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

const _fullWeekdayLabels = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _cursor;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _cursor = DateTime(today.year, today.month);
    _selectedDate = DateTime(today.year, today.month, today.day);
  }

  void _goToMonth(int delta) {
    setState(() => _cursor = DateTime(_cursor.year, _cursor.month + delta));
  }

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _cursor = DateTime(today.year, today.month);
      _selectedDate = DateTime(today.year, today.month, today.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsListProvider(widget.orgId));
    final orgUnavailAsync = ref.watch(orgUnavailabilityProvider(widget.orgId));
    final rosterAsync = ref.watch(activeRosterProvider(widget.orgId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const WisHeaderBar(),
      drawer: const AppDrawer(current: AppDrawerItem.calendar),
      body: SpotlightBackground(
        child: eventsAsync.when(
          data: (events) => orgUnavailAsync.when(
            data: (orgUnavailByUser) => rosterAsync.when(
              data: (roster) => _buildBody(context, events, orgUnavailByUser, {
                for (final member in roster) member.userId: member,
              }),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Erro ao carregar: $error')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Erro ao carregar: $error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro ao carregar: $error')),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<Event> events,
    Map<String, List<UnavailabilityEntry>> orgUnavailByUser,
    Map<String, OrgMemberOption> membersById,
  ) {
    final teamUnavailEntries = orgUnavailByUser.values
        .expand((e) => e)
        .toList();
    final eventsThisMonth = events
        .where(
          (e) => e.date.year == _cursor.year && e.date.month == _cursor.month,
        )
        .length;

    final firstOfMonth = DateTime(_cursor.year, _cursor.month);
    final daysInMonth = DateTime(_cursor.year, _cursor.month + 1, 0).day;
    final startOffset = (firstOfMonth.weekday - 1) % 7; // seg=0..dom=6
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    final cells = <DateTime?>[
      for (var i = 0; i < totalCells; i++)
        i < startOffset || i >= startOffset + daysInMonth
            ? null
            : DateTime(_cursor.year, _cursor.month, i - startOffset + 1),
    ];

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final selectedEvents =
        events.where((e) => _isSameDay(e.date, _selectedDate)).toList()
          ..sort((a, b) {
            final aMinutes = a.time.hour * 60 + a.time.minute;
            final bMinutes = b.time.hour * 60 + b.time.minute;
            return aMinutes.compareTo(bMinutes);
          });
    final selectedUnavail = teamUnavailEntries
        .where((e) => e.coversDate(_selectedDate))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'AGENDA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Calendário',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          '$eventsThisMonth ${eventsThisMonth == 1 ? 'evento' : 'eventos'} '
          'em ${_monthLabels[_cursor.month - 1].toLowerCase()}',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    _monthLabels[_cursor.month - 1],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_cursor.year}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _goToToday,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'Hoje',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    color: Colors.white.withValues(alpha: 0.6),
                    onPressed: () => _goToMonth(-1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    color: Colors.white.withValues(alpha: 0.6),
                    onPressed: () => _goToMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final label in _weekdayHeaderLabels)
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 0.8,
                ),
                itemCount: cells.length,
                itemBuilder: (context, index) {
                  final date = cells[index];
                  if (date == null) return const SizedBox.shrink();
                  final isSelected = _isSameDay(date, _selectedDate);
                  final isToday = _isSameDay(date, todayDate);
                  final dayEvents = events
                      .where((e) => _isSameDay(e.date, date))
                      .toList();
                  final hasUnavail = teamUnavailEntries.any(
                    (e) => e.coversDate(date),
                  );
                  return _DayCell(
                    date: date,
                    isSelected: isSelected,
                    isToday: isToday,
                    events: dayEvents,
                    hasUnavailability: hasUnavail,
                    onTap: () => setState(() => _selectedDate = date),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_fullWeekdayLabels[_selectedDate.weekday % 7].toUpperCase()}, '
                '${_selectedDate.day} DE '
                '${_monthLabels[_selectedDate.month - 1].toUpperCase()}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              if (selectedUnavail.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final entry in selectedUnavail) ...[
                  _UnavailablePersonCard(
                    member: membersById[entry.userId],
                    entry: entry,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 14),
              if (selectedEvents.isEmpty)
                Text(
                  'Sem eventos neste dia.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                )
              else
                Column(
                  children: [
                    for (final event in selectedEvents) ...[
                      _EventRow(orgId: widget.orgId, event: event),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _UnavailablePersonCard extends StatelessWidget {
  const _UnavailablePersonCard({required this.member, required this.entry});

  final OrgMemberOption? member;
  final UnavailabilityEntry entry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFA5B4FC).withValues(alpha: 0.15),
            backgroundImage: member?.avatarUrl != null
                ? NetworkImage(member!.avatarUrl!)
                : null,
            child: member?.avatarUrl == null
                ? Text(
                    _initials(member?.fullName ?? '?'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFA5B4FC),
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
                  member?.fullName ?? 'Alguém',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.event_busy,
                      size: 14,
                      color: _unavailColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        describeUnavailability(entry),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.map((w) => w[0]).take(2).join().toUpperCase();
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.events,
    required this.hasUnavailability,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final List<Event> events;
  final bool hasUnavailability;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = isSelected
        ? Colors.white.withValues(alpha: 0.14)
        : isToday
        ? _defaultEventColor.withValues(alpha: 0.12)
        : hasUnavailability
        ? _unavailColor.withValues(alpha: 0.06)
        : Colors.transparent;
    final border = isSelected
        ? Colors.white.withValues(alpha: 0.25)
        : isToday
        ? _defaultEventColor.withValues(alpha: 0.3)
        : Colors.transparent;
    final numberColor = isSelected
        ? Colors.white
        : isToday
        ? _defaultEventColor
        : Colors.white.withValues(alpha: 0.65);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: numberColor,
              ),
            ),
            if (events.isNotEmpty || hasUnavailability) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasUnavailability) const _DayDot(color: _unavailColor),
                  for (final event in events.take(hasUnavailability ? 2 : 3))
                    _DayDot(
                      color: hexToColor(
                        event.color,
                        fallback: _defaultEventColor,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.orgId, required this.event});

  final String orgId;
  final Event event;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(event.color, fallback: _defaultEventColor);
    final timeLabel =
        '${event.time.hour.toString().padLeft(2, '0')}:'
        '${event.time.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EventDetailScreen(orgId: orgId, event: event),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: event.isPublished
                        ? const Color(0xFF6EE7B7).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    event.isPublished ? 'Publicado' : 'Rascunho',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: event.isPublished
                          ? const Color(0xFF6EE7B7)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${event.period.emoji} ${event.period.label}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 4),
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                if (event.location != null) ...[
                  const SizedBox(width: 10),
                  Icon(
                    Icons.place_outlined,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4),
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
    );
  }
}
