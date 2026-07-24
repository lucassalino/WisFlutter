import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/domain/event.dart';
import '../../../shared/state/org_store.dart';
import '../../events/presentation/event_detail_screen.dart';
import '../../events/presentation/event_form_screen.dart';
import '../domain/birthday_person.dart';
import '../domain/dashboard_summary.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider(orgId));
    final firstName = _currentFirstName(ref);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardSummaryProvider(orgId).future),
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
      floatingActionButton: summaryAsync.value?.isAdmin == true
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventFormScreen(orgId: orgId),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Criar evento'),
            )
          : null,
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(
          'Olá, $firstName!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          _capitalize(dateLabel),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
        ),
        if (membership != null) ...[
          const SizedBox(height: 4),
          Text(
            membership.organization.name,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: WisColors.indigoAccent),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Próximos eventos',
                value: '${summary.upcomingEvents.length}',
                icon: Icons.event,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Confirmações pendentes',
                value: '${summary.pendingConfirmations}',
                icon: Icons.hourglass_empty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Próximos eventos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (summary.upcomingEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Sem eventos agendados de momento.')),
          )
        else
          ...summary.upcomingEvents.map(
            (event) => _EventCard(orgId: orgId, event: event),
          ),
        if (summary.birthdaysThisMonth.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Aniversariantes do mês',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...summary.birthdaysThisMonth.map(
            (person) => _BirthdayTile(person: person),
          ),
        ],
      ],
    );
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: WisColors.indigoAccent),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.orgId, required this.event});

  final String orgId;
  final Event event;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM', 'pt').format(event.date);
    final timeLabel =
        '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(orgId: orgId, event: event),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(event.period.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusBadge(isPublished: event.isPublished),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateLabel · $timeLabel${event.location != null ? ' · ${event.location}' : ''}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                    ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isPublished});

  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    final color = isPublished ? WisColors.greenAccent : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPublished ? 'Publicado' : 'Rascunho',
        style: TextStyle(
          color: color,
          fontSize: 11,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: person.avatarUrl != null
              ? NetworkImage(person.avatarUrl!)
              : null,
          child: person.avatarUrl == null
              ? const Icon(Icons.cake_outlined)
              : null,
        ),
        title: Text(person.name),
        trailing: Text('${person.day}'),
      ),
    );
  }
}
