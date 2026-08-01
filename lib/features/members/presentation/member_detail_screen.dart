import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../ministries/domain/ministry.dart';
import '../../ministries/presentation/ministries_providers.dart';
import '../../onboarding/domain/membership_role.dart';
import '../data/members_repository.dart';
import '../domain/org_member.dart';
import 'member_ministries_screen.dart';
import 'members_providers.dart';

final _ghostButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: Colors.white.withValues(alpha: 0.06),
  foregroundColor: Colors.white.withValues(alpha: 0.75),
  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

final _dangerButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: const Color(0xFFF87171).withValues(alpha: 0.1),
  foregroundColor: const Color(0xFFF87171),
  side: BorderSide(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

const _roleColors = {
  'Administrador': Color(0xFFC4B5FD),
  'Líder': Color(0xFF93C5FD),
  'Membro': Color(0xB3FFFFFF),
};

/// Perfil de uma pessoa da organização — espelha MemberDetailPanel.tsx,
/// mais a gestão de cargo e remoção (que na app web fica na lista, mas
/// aqui foi movida para o detalhe a pedido do utilizador).
class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({
    super.key,
    required this.orgId,
    required this.member,
    required this.isAdmin,
  });

  final String orgId;
  final OrgMember member;
  final bool isAdmin;

  Future<void> _pickRole(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<MembershipRole>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final role in MembershipRole.values)
              ListTile(
                title: Text(role.label),
                trailing: role == member.role
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(role),
              ),
          ],
        ),
      ),
    );
    if (selected != null && selected != member.role) {
      await ref
          .read(membersRepositoryProvider)
          .updateMemberRole(member.membershipId, selected);
      bumpRefreshTick(ref);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover membro?'),
        content: Text(
          'Tens a certeza que queres remover "${member.fullName}" da organização? '
          'Esta ação é permanente e remove também as suas participações em '
          'ministérios e escalas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(membersRepositoryProvider)
          .removeMember(member.membershipId, orgId, member.userId);
      bumpRefreshTick(ref);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(
      memberMinistriesProvider(member.userId),
    );
    final ministriesAsync = ref.watch(ministriesListProvider(orgId));
    final roleColor = _roleColors[member.role.label] ?? Colors.white;
    final joinedLabel = DateFormat(
      "d 'de' MMMM 'de' y",
      'pt',
    ).format(member.joinedAt);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final canManage = isAdmin && member.userId != currentUserId;

    void openMinistriesEditor() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MemberMinistriesScreen(
            orgId: orgId,
            userId: member.userId,
            memberName: member.fullName,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SpotlightBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          'Pessoas',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (canManage) ...[
                        OutlinedButton.icon(
                          style: _dangerButtonStyle,
                          onPressed: () => _confirmRemove(context, ref),
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            size: 13,
                          ),
                          label: const Text('Remover'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isAdmin)
                        OutlinedButton.icon(
                          style: _ghostButtonStyle,
                          onPressed: openMinistriesEditor,
                          icon: const Icon(Icons.edit_outlined, size: 13),
                          label: const Text('Gerir ministérios'),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
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
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA5B4FC),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      member.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        InkWell(
                          onTap: canManage
                              ? () => _pickRole(context, ref)
                              : null,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: roleColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  member.role.label,
                                  style: TextStyle(
                                    color: roleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (canManage) ...[
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.expand_more,
                                    size: 14,
                                    color: roleColor.withValues(alpha: 0.7),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (!member.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
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
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                    const SizedBox(height: 14),
                    if (isAdmin) ...[
                      Text(
                        member.email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'Desde $joinedLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        assignmentsAsync.maybeWhen(
                          data: (assignments) => Text(
                            'MINISTÉRIOS · ${assignments.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          orElse: () => Text(
                            'MINISTÉRIOS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        if (isAdmin)
                          InkWell(
                            onTap: openMinistriesEditor,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Editar',
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
                    const SizedBox(height: 14),
                    assignmentsAsync.when(
                      data: (assignments) => ministriesAsync.when(
                        data: (ministries) {
                          if (assignments.isEmpty) {
                            return Column(
                              children: [
                                Text(
                                  'Nenhum ministério atribuído.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    style: _ghostButtonStyle,
                                    onPressed: openMinistriesEditor,
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 13,
                                    ),
                                    label: const Text('Atribuir ministérios'),
                                  ),
                                ],
                              ],
                            );
                          }
                          return Column(
                            children: [
                              for (final assignment in assignments) ...[
                                _MinistryTile(
                                  assignment: assignment,
                                  ministries: ministries,
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Text('Erro: $error'),
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Text('Erro: $error'),
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

String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.map((w) => w[0]).take(2).join().toUpperCase();
}

class _MinistryTile extends StatelessWidget {
  const _MinistryTile({required this.assignment, required this.ministries});

  final ({String ministryId, List<String> functions}) assignment;
  final List<Ministry> ministries;

  @override
  Widget build(BuildContext context) {
    Ministry? ministry;
    for (final m in ministries) {
      if (m.id == assignment.ministryId) {
        ministry = m;
        break;
      }
    }
    if (ministry == null) return const SizedBox.shrink();
    final color = hexToColor(ministry.color);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ministry.name.isNotEmpty
                  ? ministry.name[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ministry.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (assignment.functions.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final fn in assignment.functions)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            '${functionEmoji(fn)} ${functionLabel(fn)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Text(
                    'Sem função atribuída',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.28),
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
