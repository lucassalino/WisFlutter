import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/data/roster_repository.dart';
import '../../../shared/domain/org_member_option.dart';
import '../../../shared/state/refresh_tick.dart';
import '../data/ministries_repository.dart';
import '../domain/ministry.dart';
import '../domain/ministry_member.dart';
import 'ministries_providers.dart';

/// Adicionar/remover pessoas de um ministério e escolher as suas funções —
/// só as funções que o próprio ministério tem (`ministry.functions`).
class MinistryMembersScreen extends ConsumerStatefulWidget {
  const MinistryMembersScreen({
    super.key,
    required this.orgId,
    required this.ministry,
  });

  final String orgId;
  final Ministry ministry;

  @override
  ConsumerState<MinistryMembersScreen> createState() =>
      _MinistryMembersScreenState();
}

class _MinistryMembersScreenState extends ConsumerState<MinistryMembersScreen> {
  Map<String, Set<String>>? _selection;
  bool _saving = false;

  void _ensureInitialized(
    List<OrgMemberOption> roster,
    List<MinistryMember> currentMembers,
  ) {
    if (_selection != null) return;
    _selection = {
      for (final member in currentMembers) member.userId: {...member.functions},
    };
  }

  Future<void> _save(List<OrgMemberOption> roster) async {
    setState(() => _saving = true);
    final members = [
      for (final entry in _selection!.entries)
        MinistryMember(
          userId: entry.key,
          fullName: roster.firstWhere((r) => r.userId == entry.key).fullName,
          functions: entry.value.toList(),
        ),
    ];
    try {
      await ref
          .read(ministriesRepositoryProvider)
          .replaceMinistryMembers(widget.ministry.id, members);
      bumpRefreshTick(ref);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar os membros.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(_rosterProvider(widget.orgId));
    final membersAsync = ref.watch(ministryMembersProvider(widget.ministry.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Membros — ${widget.ministry.name}'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _saving || rosterAsync.value == null
                ? null
                : () => _save(rosterAsync.value!),
          ),
        ],
      ),
      body: rosterAsync.when(
        data: (roster) => membersAsync.when(
          data: (currentMembers) {
            _ensureInitialized(roster, currentMembers);
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: roster.length,
              itemBuilder: (context, index) {
                final person = roster[index];
                final included = _selection!.containsKey(person.userId);
                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(
                        0xFFA5B4FC,
                      ).withValues(alpha: 0.15),
                      backgroundImage: person.avatarUrl != null
                          ? NetworkImage(person.avatarUrl!)
                          : null,
                      child: person.avatarUrl == null
                          ? Text(
                              _initials(person.fullName),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA5B4FC),
                              ),
                            )
                          : null,
                    ),
                    title: Text(person.fullName),
                    trailing: Checkbox(
                      value: included,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selection![person.userId] = {};
                        } else {
                          _selection!.remove(person.userId);
                        }
                      }),
                    ),
                    children: included
                        ? [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final key in widget.ministry.functions)
                                    FilterChip(
                                      label: Text(
                                        '${functionEmoji(key)} ${functionLabel(key)}',
                                      ),
                                      selected: _selection![person.userId]!
                                          .contains(key),
                                      onSelected: (selected) => setState(() {
                                        if (selected) {
                                          _selection![person.userId]!.add(key);
                                        } else {
                                          _selection![person.userId]!.remove(
                                            key,
                                          );
                                        }
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          ]
                        : const [],
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
    );
  }
}

final _rosterProvider = FutureProvider.family<List<OrgMemberOption>, String>((
  ref,
  orgId,
) {
  return ref.watch(rosterRepositoryProvider).fetchActiveMembers(orgId);
});

String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.map((w) => w[0]).take(2).join().toUpperCase();
}
