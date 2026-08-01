import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/org_store.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../settings/presentation/settings_screen.dart';

/// Cabeçalho partilhado por todas as tabs principais — espelha
/// `MobileHeader.tsx` do PWA: hambúrguer + logótipo/nome da organização à
/// esquerda, sino de notificações + avatar do utilizador à direita.
class WisHeaderBar extends ConsumerWidget implements PreferredSizeWidget {
  const WisHeaderBar({super.key, this.extraActions = const []});

  /// Ações extra (ex.: alternar ranking) inseridas antes do sino de
  /// notificações.
  final List<Widget> extraActions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(orgStoreProvider);
    final orgName = membership?.organization.name ?? 'WIS';
    final profileAsync = ref.watch(myProfileProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              orgName.isNotEmpty ? orgName[0].toUpperCase() : 'W',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              orgName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        ...extraActions,
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 20),
              color: Colors.white.withValues(alpha: 0.75),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 16),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
            child: profileAsync.maybeWhen(
              data: (profile) => CircleAvatar(
                radius: 14,
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        profile.fullName.isNotEmpty ? profile.fullName[0] : '?',
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
              orElse: () => const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
            ),
          ),
        ),
      ],
    );
  }
}
