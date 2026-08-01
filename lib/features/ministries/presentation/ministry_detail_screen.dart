import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../data/ministries_repository.dart';
import '../domain/ministry.dart';
import '../domain/ministry_member.dart';
import 'ministries_providers.dart';
import 'ministry_form_screen.dart';
import 'ministry_members_screen.dart';

final _ghostButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: Colors.white.withValues(alpha: 0.06),
  foregroundColor: Colors.white.withValues(alpha: 0.75),
  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

final _warningButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: const Color(0xFFFCD34D).withValues(alpha: 0.1),
  foregroundColor: const Color(0xFFFCD34D),
  side: BorderSide(color: const Color(0xFFFCD34D).withValues(alpha: 0.3)),
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

class MinistryDetailScreen extends ConsumerWidget {
  const MinistryDetailScreen({
    super.key,
    required this.orgId,
    required this.ministry,
  });

  final String orgId;
  final Ministry ministry;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover ministério'),
        content: Text(
          'Tens a certeza que queres remover "${ministry.name}"? '
          'Esta ação não pode ser desfeita.',
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
      await ref.read(ministriesRepositoryProvider).deleteMinistry(ministry.id);
      bumpRefreshTick(ref);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(ministryMembersProvider(ministry.id));
    final color = hexToColor(ministry.color);
    final initial = ministry.name.isNotEmpty
        ? ministry.name[0].toUpperCase()
        : '?';
    final createdLabel = DateFormat(
      "d 'de' MMMM 'de' y",
      'pt',
    ).format(ministry.createdAt);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SpotlightBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
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
                      'Ministérios',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: _ghostButtonStyle,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MinistryFormScreen(
                          orgId: orgId,
                          ministry: ministry,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.tune, size: 13),
                    label: const Text('Editar ministério'),
                  ),
                  OutlinedButton.icon(
                    style: _ghostButtonStyle,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MinistryMembersScreen(
                          orgId: orgId,
                          ministry: ministry,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 13),
                    label: const Text('Gerir participantes'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: _warningButtonStyle,
                    onPressed: () async {
                      await ref
                          .read(ministriesRepositoryProvider)
                          .toggleActive(ministry.id, !ministry.isActive);
                      bumpRefreshTick(ref);
                    },
                    icon: Icon(
                      ministry.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 13,
                    ),
                    label: Text(ministry.isActive ? 'Desactivar' : 'Activar'),
                  ),
                  OutlinedButton.icon(
                    style: _dangerButtonStyle,
                    onPressed: () => _confirmDelete(context, ref),
                    icon: const Icon(Icons.delete_outline, size: 13),
                    label: const Text('Remover'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ministry.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: ministry.isActive
                                      ? const Color(
                                          0xFF6EE7B7,
                                        ).withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: ministry.isActive
                                        ? const Color(
                                            0xFF6EE7B7,
                                          ).withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Text(
                                  ministry.isActive ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                    color: ministry.isActive
                                        ? const Color(0xFF6EE7B7)
                                        : Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Criado a $createdLabel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                        membersAsync.maybeWhen(
                          data: (members) => Text(
                            'PARTICIPANTES · ${members.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          orElse: () => Text(
                            'PARTICIPANTES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => MinistryMembersScreen(
                                orgId: orgId,
                                ministry: ministry,
                              ),
                            ),
                          ),
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
                    membersAsync.when(
                      data: (members) {
                        if (members.isEmpty) {
                          return Text(
                            'Ainda sem participantes.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final member in members) ...[
                              _ParticipantRow(member: member),
                              const SizedBox(height: 8),
                            ],
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Text('Erro: $error'),
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
                    Text(
                      'FUNÇÕES DISPONÍVEIS · ${ministry.functions.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (ministry.functions.isEmpty)
                      Text(
                        'Nenhuma função configurada.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final fn in ministry.functions) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    functionEmoji(fn),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    functionLabel(fn),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
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

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.member});

  final MinistryMember member;

  @override
  Widget build(BuildContext context) {
    final fullName = member.fullName;
    final avatarUrl = member.avatarUrl;
    final functions = member.functions;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(_initials(fullName), style: const TextStyle(fontSize: 11))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (functions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final fn in functions)
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
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
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
