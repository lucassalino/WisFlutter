import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/domain/event.dart';
import '../../../shared/state/org_store.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../events/presentation/event_detail_screen.dart';
import '../../events/presentation/event_form_screen.dart';
import '../../events/presentation/events_list_screen.dart';
import '../../shell/presentation/app_drawer.dart';
import '../../shell/presentation/wis_header_bar.dart';
import '../domain/birthday_person.dart';
import '../domain/dashboard_summary.dart';
import 'dashboard_providers.dart';

const _monthNames = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider(orgId));
    final firstName = _currentFirstName(ref);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const WisHeaderBar(),
      drawer: const AppDrawer(current: AppDrawerItem.home),
      body: SpotlightBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.refresh(dashboardSummaryProvider(orgId).future),
            child: summaryAsync.when(
              data: (summary) => _DashboardBody(
                orgId: orgId,
                firstName: firstName,
                summary: summary,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Erro ao carregar o dashboard: $error')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _currentFirstName(WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim().split(' ').first;
    }
    return user?.email?.split('@').first ?? 'Bem-vindo';
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.orgId,
    required this.firstName,
    required this.summary,
  });

  final String orgId;
  final String firstName;
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(orgStoreProvider);
    final dateLabel = DateFormat(
      "EEEE, d 'de' MMMM",
      'pt',
    ).format(DateTime.now());
    final eventsCount = summary.upcomingEvents.length;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          _capitalize(dateLabel).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Olá, $firstName!',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${membership?.organization.name ?? ''} · ${eventsCount > 0 ? '$eventsCount evento${eventsCount != 1 ? 's' : ''} próximo${eventsCount != 1 ? 's' : ''}' : 'tudo tranquilo por aqui'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PRÓXIMOS EVENTOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EventsListScreen(orgId: orgId),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver todos',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.upcomingEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 44,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum evento agendado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        if (summary.isAdmin) ...[
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    EventFormScreen(orgId: orgId),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Criar evento'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 15),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                ...summary.upcomingEvents.map(
                  (event) => _EventRow(orgId: orgId, event: event),
                ),
            ],
          ),
        ),
        if (summary.birthdaysThisMonth.isNotEmpty) ...[
          const SizedBox(height: 16),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    children: [
                      const Text('🎂', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        'ANIVERSARIANTES DE ${_monthNames[now.month - 1].toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: summary.birthdaysThisMonth
                        .map((person) => _BirthdayTile(person: person))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.orgId, required this.event});

  final String orgId;
  final Event event;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(event.color);
    final month = DateFormat(
      'MMM',
      'pt',
    ).format(event.date).replaceAll('.', '').toUpperCase();
    final day = event.date.day;
    final timeLabel =
        '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EventDetailScreen(orgId: orgId, event: event),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    month,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: color,
                    ),
                  ),
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 2,
              height: 32,
              color: color,
              margin: const EdgeInsets.only(right: 4),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          event.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StatusBadge(isPublished: event.isPublished),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      if (event.location != null) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            event.location!,
                            style: TextStyle(
                              fontSize: 12,
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
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isPublished});

  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isPublished ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPublished ? 'Publicado' : 'Rascunho',
        style: TextStyle(
          color: Colors.white.withValues(alpha: isPublished ? 1 : 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BirthdayTile extends StatelessWidget {
  const _BirthdayTile({required this.person});

  final BirthdayPerson person;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFFCD34D).withValues(alpha: 0.15),
            backgroundImage: person.avatarUrl != null
                ? NetworkImage(person.avatarUrl!)
                : null,
            child: person.avatarUrl == null
                ? const Text('🎂', style: TextStyle(fontSize: 16))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '🎂 ${person.day} de ${_monthNames[person.month - 1]}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
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
