import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../shell/presentation/app_drawer.dart';
import '../../shell/presentation/wis_header_bar.dart';
import '../data/invites_repository.dart';
import '../domain/org_member.dart';
import 'invite_member_screen.dart';
import 'member_detail_screen.dart';
import 'members_providers.dart';

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

const _roleColors = {
  'Administrador': Color(0xFFC4B5FD),
  'Líder': Color(0xFF93C5FD),
  'Membro': Color(0xB3FFFFFF),
};

class MembersListScreen extends ConsumerWidget {
  const MembersListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersListProvider(orgId));
    final membership = ref.watch(orgStoreProvider);
    final isAdmin = membership?.role.isAdmin ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const WisHeaderBar(),
      drawer: const AppDrawer(current: AppDrawerItem.members),
      body: SpotlightBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORGANIZAÇÃO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pessoas',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      membersAsync.maybeWhen(
                        data: (members) {
                          final active = members
                              .where((m) => m.isActive)
                              .length;
                          final inactive = members.length - active;
                          return Text(
                            members.isNotEmpty
                                ? '$active activo${active != 1 ? 's' : ''} · '
                                      '$inactive inactivo${inactive != 1 ? 's' : ''}'
                                : 'Membros da organização',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          );
                        },
                        orElse: () => Text(
                          'Membros da organização',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: _primaryButtonStyle,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            InviteMemberScreen(orgId: orgId),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Convidar'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: 24),
                      Icon(
                        Icons.people_outline,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum membro encontrado.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  );
                }
                final sorted = [...members]..sort(
                  (a, b) => a.fullName.toLowerCase().compareTo(
                    b.fullName.toLowerCase(),
                  ),
                );
                return Column(
                  children: [
                    for (final member in sorted) ...[
                      _MemberRow(
                        orgId: orgId,
                        member: member,
                        isAdmin: isAdmin,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Erro ao carregar pessoas: $error')),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              _PendingInvitesSection(orgId: orgId),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.orgId,
    required this.member,
    required this.isAdmin,
  });

  final String orgId;
  final OrgMember member;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleColor = _roleColors[member.role.label] ?? Colors.white;
    return Opacity(
      opacity: member.isActive ? 1 : 0.5,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MemberDetailScreen(
              orgId: orgId,
              member: member,
              isAdmin: isAdmin,
            ),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(
                0xFFA5B4FC,
              ).withValues(alpha: 0.15),
              backgroundImage: member.avatarUrl != null
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: member.avatarUrl == null
                  ? Text(
                      _initials(member.fullName),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!member.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(
                                0xFFF87171,
                              ).withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Text(
                            'Inactivo',
                            style: TextStyle(
                              color: Color(0xFFF87171),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 2),
                    Text(
                      member.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: roleColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                member.role.label,
                style: TextStyle(
                  color: roleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingInvitesSection extends ConsumerWidget {
  const _PendingInvitesSection({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(pendingInvitesProvider(orgId));
    return invitesAsync.when(
      data: (invites) {
        if (invites.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  'CONVITES PENDENTES (${invites.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final invite in invites) ...[
              GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCD34D).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFFFCD34D,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.mail_outline,
                        size: 16,
                        color: Color(0xFFFCD34D),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  invite.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFCD34D,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFCD34D,
                                    ).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Text(
                                  'Aguarda entrada',
                                  style: TextStyle(
                                    color: Color(0xFFFCD34D),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            invite.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: const Color(0xFFF87171),
                      onPressed: () async {
                        await ref
                            .read(invitesRepositoryProvider)
                            .deleteInvite(orgId, invite.id);
                        bumpRefreshTick(ref);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Text('Erro: $error'),
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
