import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/state/org_store.dart';
import '../../auth/data/auth_repository.dart';
import '../../availability/presentation/availability_screen.dart';
import '../../calendar/presentation/calendar_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../events/presentation/events_list_screen.dart';
import '../../members/presentation/members_list_screen.dart';
import '../../ministries/presentation/ministries_list_screen.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../onboarding/domain/organization.dart';
import '../../onboarding/presentation/create_org_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../schedule/presentation/schedule_events_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../songs/presentation/songs_list_screen.dart';

enum AppDrawerItem {
  none,
  home,
  events,
  schedule,
  calendar,
  availability,
  members,
  ministries,
  songs,
  settings,
}

/// Sidebar/drawer partilhada por todas as tabs — espelha a sidebar do PWA
/// (logótipo + switcher de organização + navegação completa + rodapé com
/// utilizador). Acedida pelo hambúrguer no canto superior esquerdo.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key, required this.current});

  final AppDrawerItem current;

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _orgMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(orgStoreProvider);
    final orgId = membership?.organization.id;
    final user = Supabase.instance.client.auth.currentUser;
    final profileAsync = ref.watch(myProfileProvider);

    return Drawer(
      backgroundColor: const Color(0xFF050505),
      width: 300,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D3B66), Color(0xFF0F5C6E)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'W',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'WIS',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.white.withValues(alpha: 0.5),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _orgMenuOpen = !_orgMenuOpen),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (membership?.organization.name.isNotEmpty ??
                                      false)
                                  ? membership!.organization.name[0]
                                        .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              membership?.organization.name ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            _orgMenuOpen
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_orgMenuOpen) _OrgMenu(currentOrgId: orgId),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _DrawerItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Início',
                    active: widget.current == AppDrawerItem.home,
                    onTap: () => _go(context, orgId, AppDrawerItem.home),
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Eventos',
                    active: widget.current == AppDrawerItem.events,
                    onTap: () => _go(context, orgId, AppDrawerItem.events),
                  ),
                  _DrawerItem(
                    icon: Icons.checklist_outlined,
                    label: 'Escalas',
                    active: widget.current == AppDrawerItem.schedule,
                    onTap: () => _go(context, orgId, AppDrawerItem.schedule),
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendário',
                    active: widget.current == AppDrawerItem.calendar,
                    onTap: () => _go(context, orgId, AppDrawerItem.calendar),
                  ),
                  _DrawerItem(
                    icon: Icons.event_busy_outlined,
                    label: 'Indisponibilidade',
                    active: widget.current == AppDrawerItem.availability,
                    onTap: () =>
                        _go(context, orgId, AppDrawerItem.availability),
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'Pessoas',
                    active: widget.current == AppDrawerItem.members,
                    onTap: () => _go(context, orgId, AppDrawerItem.members),
                  ),
                  _DrawerItem(
                    icon: Icons.music_note_outlined,
                    label: 'Ministérios',
                    active: widget.current == AppDrawerItem.ministries,
                    onTap: () => _go(context, orgId, AppDrawerItem.ministries),
                  ),
                  _DrawerItem(
                    icon: Icons.menu_book_outlined,
                    label: 'Repertório',
                    active: widget.current == AppDrawerItem.songs,
                    onTap: () => _go(context, orgId, AppDrawerItem.songs),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Definições',
                    active: widget.current == AppDrawerItem.settings,
                    onTap: () => _go(context, orgId, AppDrawerItem.settings),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                ),
              ),
              child: Row(
                children: [
                  profileAsync.maybeWhen(
                    data: (profile) => CircleAvatar(
                      radius: 16,
                      backgroundImage: profile.avatarUrl != null
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: profile.avatarUrl == null
                          ? Text(
                              profile.fullName.isNotEmpty
                                  ? profile.fullName[0]
                                  : '?',
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                    ),
                    orElse: () => const CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.person, size: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profileAsync.maybeWhen(
                            data: (p) => p.fullName.isNotEmpty
                                ? p.fullName
                                : (user?.email ?? ''),
                            orElse: () => user?.email ?? '',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final unread = ref.watch(
                        unreadNotificationsCountProvider,
                      );
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_outlined,
                              size: 20,
                            ),
                            color: Colors.white.withValues(alpha: 0.5),
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsScreen(),
                                ),
                              );
                            },
                          ),
                          if (unread > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF87171),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 18),
                    color: Colors.white.withValues(alpha: 0.5),
                    tooltip: 'Terminar sessão',
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await ref.read(authRepositoryProvider).signOut();
                      ref.read(orgStoreProvider.notifier).clear();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String? orgId, AppDrawerItem item) {
    Navigator.of(context).pop();
    if (item == widget.current || orgId == null) return;
    final builder = switch (item) {
      AppDrawerItem.none => null,
      AppDrawerItem.home => (BuildContext context) => DashboardScreen(
        orgId: orgId,
      ),
      AppDrawerItem.events => (BuildContext context) => EventsListScreen(
        orgId: orgId,
      ),
      AppDrawerItem.schedule => (BuildContext context) => ScheduleEventsScreen(
        orgId: orgId,
      ),
      AppDrawerItem.calendar => (BuildContext context) => CalendarScreen(
        orgId: orgId,
      ),
      AppDrawerItem.availability =>
        (BuildContext context) => AvailabilityScreen(orgId: orgId),
      AppDrawerItem.members => (BuildContext context) => MembersListScreen(
        orgId: orgId,
      ),
      AppDrawerItem.ministries =>
        (BuildContext context) => MinistriesListScreen(orgId: orgId),
      AppDrawerItem.songs => (BuildContext context) => SongsListScreen(
        orgId: orgId,
      ),
      AppDrawerItem.settings =>
        (BuildContext context) => const SettingsScreen(),
    };
    if (builder == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }
}

/// Dropdown inline com as organizações do utilizador + "Nova organização" —
/// espelha `.sidebar-dark-popover` do PWA.
class _OrgMenu extends ConsumerWidget {
  const _OrgMenu({required this.currentOrgId});

  final String? currentOrgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipsAsync = ref.watch(myMembershipsProvider);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: const Color(0xF2121216),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          membershipsAsync.when(
            data: (memberships) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final membership in memberships)
                  InkWell(
                    onTap: () => _selectOrg(context, ref, membership),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              membership.organization.name.isNotEmpty
                                  ? membership.organization.name[0]
                                        .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              membership.organization.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (membership.organization.id == currentOrgId)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateOrgScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.add,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Nova organização',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectOrg(
    BuildContext context,
    WidgetRef ref,
    OrganizationMembership membership,
  ) async {
    if (membership.organization.id == currentOrgId) return;
    Navigator.of(context).pop();
    await ref.read(orgStoreProvider.notifier).setActive(membership);
    if (context.mounted) {
      context.go('/${membership.organization.id}/dashboard');
    }
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: active
                ? const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.white70, width: 2.5),
                    ),
                  )
                : null,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
