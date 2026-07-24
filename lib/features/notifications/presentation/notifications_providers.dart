import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/refresh_tick.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

final notificationsListProvider = FutureProvider<List<AppNotification>>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(notificationsRepositoryProvider).fetchNotifications();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsListProvider).value ?? const [];
  return notifications.where((n) => !n.isRead).length;
});
