import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/state/org_store.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';
import '../../events/data/events_repository.dart';
import '../../schedule/presentation/schedule_editor_screen.dart';
import 'notifications_providers.dart';

/// Espelha o popover de notificações da app web: sino com contador,
/// lista, marcar todas como lidas, e clicar numa notificação de escala
/// abre o evento correspondente para confirmar presença.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final orgId = ref.watch(orgStoreProvider)?.organization.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(notificationsListProvider);
            },
            child: const Text('Marcar todas como lidas'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('Sem notificações.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: notification.isRead
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: Icon(
                    notification.isRead
                        ? Icons.notifications_none
                        : Icons.notifications,
                  ),
                  title: Text(notification.message),
                  subtitle: Text(
                    DateFormat(
                      'd MMM yyyy, HH:mm',
                      'pt',
                    ).format(notification.sentAt),
                  ),
                  onTap: () =>
                      _openNotification(context, ref, orgId, notification),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao carregar notificações: $error')),
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    String? orgId,
    AppNotification notification,
  ) async {
    if (!notification.isRead) {
      await ref.read(notificationsRepositoryProvider).markRead(notification.id);
      ref.invalidate(notificationsListProvider);
    }
    if (notification.eventId == null || orgId == null || !context.mounted) {
      return;
    }

    final event = await ref
        .read(eventsRepositoryProvider)
        .fetchEventById(notification.eventId!);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScheduleEditorScreen(orgId: orgId, event: event),
      ),
    );
  }
}
