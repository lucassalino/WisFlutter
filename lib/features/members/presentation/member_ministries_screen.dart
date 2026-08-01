import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../ministries/data/ministries_repository.dart';
import '../../ministries/presentation/ministries_providers.dart';
import 'members_providers.dart';

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

/// Atribui/remove [userId] em ministérios da organização e escolhe as
/// funções em cada um — perspectiva "por pessoa" (espelha
/// MemberMinistriesPanel.tsx), ao contrário de [MinistryMembersScreen] que
/// parte de um único ministério e substitui todo o seu elenco.
class MemberMinistriesScreen extends ConsumerStatefulWidget {
  const MemberMinistriesScreen({
    super.key,
    required this.orgId,
    required this.userId,
    required this.memberName,
  });

  final String orgId;
  final String userId;
  final String memberName;

  @override
  ConsumerState<MemberMinistriesScreen> createState() =>
      _MemberMinistriesScreenState();
}

class _MemberMinistriesScreenState
    extends ConsumerState<MemberMinistriesScreen> {
  Map<String, Set<String>>? _selection;
  Set<String>? _initialMinistryIds;
  bool _saving = false;

  void _ensureInitialized(
    List<({String ministryId, List<String> functions})> assignments,
  ) {
    if (_selection != null) return;
    _selection = {
      for (final a in assignments) a.ministryId: {...a.functions},
    };
    _initialMinistryIds = _selection!.keys.toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(ministriesRepositoryProvider);
    try {
      final finalIds = _selection!.keys.toSet();
      final removed = _initialMinistryIds!.difference(finalIds);
      for (final ministryId in removed) {
        await repo.removeMemberFromMinistry(ministryId, widget.userId);
      }
      for (final entry in _selection!.entries) {
        await repo.setMemberFunctions(
          entry.key,
          widget.userId,
          entry.value.toList(),
        );
      }
      bumpRefreshTick(ref);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar.')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));
    final assignmentsAsync = ref.watch(
      memberMinistriesProvider(widget.userId),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Ministérios de ${widget.memberName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: ElevatedButton(
                style: _primaryButtonStyle,
                onPressed: _saving || _selection == null ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ),
        ],
      ),
      body: SpotlightBackground(
        child: ministriesAsync.when(
          data: (ministries) => assignmentsAsync.when(
            data: (assignments) {
              _ensureInitialized(assignments);
              final active = ministries.where((m) => m.isActive).toList();
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: active.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final ministry = active[index];
                  final color = hexToColor(ministry.color);
                  final included = _selection!.containsKey(ministry.id);
                  return GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                ministry.icon,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ministry.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Switch(
                              value: included,
                              onChanged: (value) => setState(() {
                                if (value) {
                                  _selection![ministry.id] = {};
                                } else {
                                  _selection!.remove(ministry.id);
                                }
                              }),
                            ),
                          ],
                        ),
                        if (included && ministry.functions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final key in ministry.functions)
                                FilterChip(
                                  label: Text(
                                    '${functionEmoji(key)} ${functionLabel(key)}',
                                  ),
                                  selected: _selection![ministry.id]!.contains(
                                    key,
                                  ),
                                  onSelected: (selected) => setState(() {
                                    if (selected) {
                                      _selection![ministry.id]!.add(key);
                                    } else {
                                      _selection![ministry.id]!.remove(key);
                                    }
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Erro: $error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
        ),
      ),
    );
  }
}
