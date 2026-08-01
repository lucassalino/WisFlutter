import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/roster_repository.dart';
import '../../../shared/domain/org_member_option.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/availability_utils.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../shell/presentation/app_drawer.dart';
import '../../shell/presentation/wis_header_bar.dart';
import '../data/availability_repository.dart';
import '../domain/unavailability_entry.dart';
import 'availability_providers.dart';

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
);

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  UnavailabilityKind _kind = UnavailabilityKind.dateRange;
  DateTimeRange? _range;
  DateTime? _weekdayDate;
  String? _period;
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _pickWeekdayDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: _weekdayDate ?? DateTime.now(),
    );
    if (picked != null) setState(() => _weekdayDate = picked);
  }

  Future<void> _pickPeriod() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('O dia todo'),
              trailing: _period == null
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () => Navigator.of(context).pop<String?>(null),
            ),
            for (final entry in periodOptions.entries)
              ListTile(
                title: Text(entry.value),
                trailing: _period == entry.key
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(entry.key),
              ),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _period = selected);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final reason = _reasonController.text.trim().isEmpty
        ? null
        : _reasonController.text.trim();
    final repo = ref.read(availabilityRepositoryProvider);
    setState(() => _submitting = true);
    try {
      if (_kind == UnavailabilityKind.dateRange) {
        if (_range == null) {
          setState(() => _error = 'Escolhe o período');
          return;
        }
        await repo.addDateRangeUnavailability(
          orgId: widget.orgId,
          startDate: _range!.start,
          endDate: _range!.end,
          reason: reason,
        );
      } else {
        if (_weekdayDate == null) {
          setState(() => _error = 'Escolhe uma data');
          return;
        }
        await repo.addWeeklyUnavailability(
          orgId: widget.orgId,
          weekday: _weekdayDate!.weekday % 7,
          period: _period,
          reason: reason,
        );
      }
      _reasonController.clear();
      setState(() {
        _range = null;
        _weekdayDate = null;
        _period = null;
      });
      bumpRefreshTick(ref);
    } catch (_) {
      setState(() => _error = 'Não foi possível guardar. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myEntriesAsync = ref.watch(myUnavailabilityProvider(widget.orgId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const WisHeaderBar(),
      drawer: const AppDrawer(current: AppDrawerItem.availability),
      body: SpotlightBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              'Indisponibilidade',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Marca os teus períodos de indisponibilidade — só tu e quem '
              'escala veem o motivo',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marca aqui os períodos em que não podes servir — '
                    'férias, viagens, ou um dia da semana que nunca te dá '
                    'jeito. Fica visível para quem escala, como aviso.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _KindSwitch(
                    value: _kind,
                    onChanged: (value) => setState(() => _kind = value),
                  ),
                  const SizedBox(height: 16),
                  if (_kind == UnavailabilityKind.dateRange) ...[
                    const _FieldLabel('De — até'),
                    _PickerField(
                      text: _range == null
                          ? null
                          : '${_range!.start.day}/${_range!.start.month} '
                                'a ${_range!.end.day}/${_range!.end.month}',
                      placeholder: 'Escolhe o período',
                      onTap: _pickRange,
                    ),
                  ] else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Dia da semana'),
                        _PickerField(
                          text: _weekdayDate == null
                              ? null
                              : weekdayLabels[_weekdayDate!.weekday % 7],
                          placeholder: 'Escolhe uma data',
                          onTap: _pickWeekdayDate,
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Período'),
                        _PickerField(
                          text: _period == null
                              ? 'O dia todo'
                              : periodOptions[_period],
                          onTap: _pickPeriod,
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Motivo (opcional)'),
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Férias, trabalho...',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: _primaryButtonStyle,
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Adicionar'),
                  ),
                  const SizedBox(height: 16),
                  myEntriesAsync.when(
                    data: (entries) {
                      if (entries.isEmpty) {
                        return Text(
                          'Sem indisponibilidades registadas.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final entry in entries) ...[
                            _OwnEntryRow(entry: entry),
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
            const SizedBox(height: 24),
            _TeamUnavailabilitySection(orgId: widget.orgId),
          ],
        ),
      ),
    );
  }
}

class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.value, required this.onChanged});

  final UnavailabilityKind value;
  final ValueChanged<UnavailabilityKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _KindTab(
              label: 'Pontual',
              selected: value == UnavailabilityKind.dateRange,
              onTap: () => onChanged(UnavailabilityKind.dateRange),
            ),
          ),
          Expanded(
            child: _KindTab(
              label: 'Recorrente',
              selected: value == UnavailabilityKind.weekly,
              onTap: () => onChanged(UnavailabilityKind.weekly),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindTab extends StatelessWidget {
  const _KindTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.black
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.text,
    this.placeholder = '',
    required this.onTap,
  });

  final String? text;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text ?? placeholder,
                style: TextStyle(
                  fontSize: 14,
                  color: text != null
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnEntryRow extends ConsumerWidget {
  const _OwnEntryRow({required this.entry});

  final UnavailabilityEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_busy, size: 16, color: Color(0xFFF87171)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              describeUnavailability(entry),
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: Colors.white.withValues(alpha: 0.35),
            onPressed: () async {
              await ref
                  .read(availabilityRepositoryProvider)
                  .removeUnavailability(entry.id);
              bumpRefreshTick(ref);
            },
          ),
        ],
      ),
    );
  }
}

class _TeamUnavailabilitySection extends ConsumerWidget {
  const _TeamUnavailabilitySection({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgUnavailAsync = ref.watch(orgUnavailabilityProvider(orgId));
    final rosterAsync = ref.watch(activeRosterProvider(orgId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.people_outline,
              size: 15,
              color: Color(0xFFA5B4FC),
            ),
            const SizedBox(width: 8),
            Text(
              'INDISPONIBILIDADE DA EQUIPA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        rosterAsync.when(
          data: (roster) => orgUnavailAsync.when(
            data: (byUser) {
              final members = roster
                  .where((m) => (byUser[m.userId]?.isNotEmpty ?? false))
                  .toList();
              if (members.isEmpty) {
                return Text(
                  'Ninguém registou indisponibilidades ainda.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                );
              }
              return Column(
                children: [
                  for (final member in members) ...[
                    _TeamMemberCard(
                      member: member,
                      entries: byUser[member.userId]!,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Erro: $error'),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Erro: $error'),
        ),
      ],
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({required this.member, required this.entries});

  final OrgMemberOption member;
  final List<UnavailabilityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFA5B4FC).withValues(alpha: 0.15),
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Text(
                    _initials(member.fullName),
                    style: const TextStyle(
                      fontSize: 11,
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
                Text(
                  member.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.event_busy,
                          size: 12,
                          color: Color(0xFFF87171),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            describeUnavailability(entry),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
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

String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.map((w) => w[0]).take(2).join().toUpperCase();
}
