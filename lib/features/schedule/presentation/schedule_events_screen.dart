import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../events/presentation/events_providers.dart';
import '../../shell/presentation/app_drawer.dart';
import '../../shell/presentation/wis_header_bar.dart';
import 'schedule_editor_screen.dart';

/// Tab "Escala" — lista de eventos; ao selecionar um, abre o editor de
/// ministérios/slots (ScheduleEditorScreen). Espelha ScheduleClient.tsx.
/// Mostra só as próprias escalas futuras, para todos os utilizadores
/// (incluindo admins/líderes) — a gestão de eventos continua disponível no
/// separador Eventos, mesmo para eventos onde a pessoa não está escalada.
class ScheduleEventsScreen extends ConsumerWidget {
  const ScheduleEventsScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsListProvider(orgId));
    final scheduledIdsAsync = ref.watch(myScheduledEventIdsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const WisHeaderBar(),
      drawer: const AppDrawer(current: AppDrawerItem.schedule),
      body: SpotlightBackground(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Escalas',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Expanded(
              child: eventsAsync.when(
                data: (events) {
                  if (scheduledIdsAsync.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final scheduledIds = scheduledIdsAsync.value ?? const {};
                  final today = DateTime.now();
                  final todayDate = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );
                  final visible = events
                      .where(
                        (e) =>
                            !e.date.isBefore(todayDate) &&
                            scheduledIds.contains(e.id),
                      )
                      .toList();
                  if (visible.isEmpty) {
                    return Center(
                      child: Text(
                        'Ainda não estás escalado em nenhum evento futuro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    );
                  }
                  final sorted = [...visible]
                    ..sort((a, b) => a.date.compareTo(b.date));
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = sorted[index];
                      final dateLabel = DateFormat(
                        'dd/MM/yyyy',
                        'pt',
                      ).format(event.date);
                      final timeLabel =
                          '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';
                      return GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ScheduleEditorScreen(
                              orgId: orgId,
                              event: event,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final color = event.isPublished
                                    ? const Color(0xFF6EE7B7)
                                    : Colors.white;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(
                                      alpha: event.isPublished ? 0.15 : 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: color.withValues(
                                        alpha: event.isPublished ? 0.3 : 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    event.isPublished
                                        ? 'Publicado'
                                        : 'Rascunho',
                                    style: TextStyle(
                                      color: event.isPublished
                                          ? color
                                          : Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Erro ao carregar eventos: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
