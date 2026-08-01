import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/domain/event.dart';
import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/utils/whatsapp.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../ministries/domain/ministry.dart';
import '../../ministries/domain/ministry_member.dart';
import '../../ministries/presentation/ministries_providers.dart';
import '../../events/data/events_repository.dart';
import '../../events/domain/event_ministry.dart';
import '../../events/domain/event_schedule.dart';
import '../../events/domain/scheduled_contact.dart';
import '../../events/presentation/events_providers.dart';
import '../../onboarding/domain/membership_role.dart';

final _ghostButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: Colors.white.withValues(alpha: 0.06),
  foregroundColor: Colors.white.withValues(alpha: 0.75),
  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);


/// Editor de escala de um evento — adiciona/remove ministérios e pessoas
/// incrementalmente (ao contrário do wizard de Eventos, que grava tudo de
/// uma vez), confirma presença própria e Publica & Notifica. Espelha
/// ScheduleClient.tsx.
class ScheduleEditorScreen extends ConsumerStatefulWidget {
  const ScheduleEditorScreen({
    super.key,
    required this.orgId,
    required this.event,
  });

  final String orgId;
  final Event event;

  @override
  ConsumerState<ScheduleEditorScreen> createState() =>
      _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends ConsumerState<ScheduleEditorScreen> {
  bool _publishing = false;

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(orgStoreProvider);
    final canEdit =
        membership?.role == MembershipRole.admin ||
        membership?.role == MembershipRole.leader;
    final ministriesAsync = ref.watch(eventMinistriesProvider(widget.event.id));
    final timeLabel =
        '${widget.event.time.hour.toString().padLeft(2, '0')}:${widget.event.time.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SpotlightBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
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
                            'Escalas',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text(
                      'ESCALA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.event.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(widget.event.date)} · $timeLabel'
                      '${widget.event.location != null ? ' · ${widget.event.location}' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusBadge(isPublished: widget.event.isPublished),
                        if (canEdit)
                          OutlinedButton.icon(
                            style: _ghostButtonStyle,
                            onPressed: () => _notifyWhatsApp(context),
                            icon: const Icon(Icons.send_outlined, size: 13),
                            label: const Text('Notificar por WhatsApp'),
                          ),
                        if (canEdit && !widget.event.isPublished)
                          OutlinedButton.icon(
                            style: _ghostButtonStyle,
                            onPressed: _publishing
                                ? null
                                : () => _publish(context),
                            icon: _publishing
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.campaign_outlined, size: 13),
                            label: Text(
                              _publishing ? 'A publicar...' : 'Publicar escala',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 20),
                    ministriesAsync.when(
                      data: (eventMinistries) {
                        if (eventMinistries.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 36,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 32,
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Nenhum ministério neste evento',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final eventMinistry in eventMinistries) ...[
                              _MinistrySlot(
                                eventMinistry: eventMinistry,
                                eventId: widget.event.id,
                                canEdit: canEdit,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('Erro: $error')),
                    ),
                    if (canEdit) ...[
                      const SizedBox(height: 4),
                      _AddMinistryButton(
                        orgId: widget.orgId,
                        event: widget.event,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _publish(BuildContext context) async {
    setState(() => _publishing = true);
    final repo = ref.read(eventsRepositoryProvider);
    try {
      await repo.publishEvent(widget.event.id, true);
      final notified = await repo.notifyEventSchedules(
        widget.event.id,
        widget.event.name,
      );
      bumpRefreshTick(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Escala publicada — $notified pessoa(s) notificada(s) na app.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _notifyWhatsApp(BuildContext context) async {
    final repo = ref.read(eventsRepositoryProvider);
    final contacts = await repo.fetchScheduledContacts(widget.event.id);
    if (!context.mounted) return;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ainda não há pessoas escaladas para notificar.'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WhatsAppContactsSheet(
        orgId: widget.orgId,
        event: widget.event,
        contacts: contacts,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isPublished});

  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    final color = isPublished ? const Color(0xFF6EE7B7) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isPublished ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isPublished ? 0.3 : 0.1),
        ),
      ),
      child: Text(
        isPublished ? 'Publicado' : 'Rascunho',
        style: TextStyle(
          color: isPublished ? color : Colors.white.withValues(alpha: 0.55),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddMinistryButton extends ConsumerWidget {
  const _AddMinistryButton({required this.orgId, required this.event});

  final String orgId;
  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministriesAsync = ref.watch(ministriesListProvider(orgId));
    final existingAsync = ref.watch(eventMinistriesProvider(event.id));
    return ministriesAsync.when(
      data: (ministries) {
        final existingIds =
            existingAsync.value?.map((e) => e.ministry.id).toSet() ?? {};
        final available = ministries
            .where((m) => m.isActive && !existingIds.contains(m.id))
            .toList();
        if (available.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: _ghostButtonStyle,
            onPressed: () => _pickMinistryToAdd(context, ref, available),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Adicionar ministério'),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _pickMinistryToAdd(
    BuildContext context,
    WidgetRef ref,
    List<Ministry> available,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final ministry in available)
              ListTile(
                title: Text('${ministry.icon} ${ministry.name}'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref
                      .read(eventsRepositoryProvider)
                      .addMinistryToEvent(event.id, ministry);
                  bumpRefreshTick(ref);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MinistrySlot extends ConsumerStatefulWidget {
  const _MinistrySlot({
    required this.eventMinistry,
    required this.eventId,
    required this.canEdit,
  });

  final EventMinistry eventMinistry;
  final String eventId;
  final bool canEdit;

  @override
  ConsumerState<_MinistrySlot> createState() => _MinistrySlotState();
}

class _MinistrySlotState extends ConsumerState<_MinistrySlot> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final Ministry ministry = widget.eventMinistry.ministry;
    final color = hexToColor(ministry.color);
    final schedulesAsync = ref.watch(
      eventSchedulesProvider(widget.eventMinistry.id),
    );
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD9161619),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _expanded ? Icons.expand_more : Icons.chevron_right,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ministry.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: color.withValues(alpha: 0.27),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_alt_outlined,
                                  size: 11,
                                  color: color,
                                ),
                                const SizedBox(width: 3),
                                schedulesAsync.when(
                                  data: (schedules) => Text(
                                    '${schedules.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, _) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.canEdit)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: Colors.white.withValues(alpha: 0.3),
                    onPressed: () async {
                      await ref
                          .read(eventsRepositoryProvider)
                          .removeMinistryFromEvent(widget.eventMinistry.id);
                      bumpRefreshTick(ref);
                    },
                  ),
              ],
            ),
          ),
          if (_expanded)
            schedulesAsync.when(
              data: (schedules) {
                return Column(
                  children: [
                    if (schedules.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Nenhuma pessoa escalada.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      )
                    else
                      for (final schedule in schedules)
                        _ScheduleRow(
                          schedule: schedule,
                          isSelf: schedule.userId == currentUserId,
                          canEdit: widget.canEdit,
                          ministry: ministry,
                          eventMinistryId: widget.eventMinistry.id,
                        ),
                    if (widget.canEdit)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _AddPersonButton(
                            eventMinistryId: widget.eventMinistry.id,
                            ministry: ministry,
                            schedules: schedules,
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro: $error'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends ConsumerWidget {
  const _ScheduleRow({
    required this.schedule,
    required this.isSelf,
    required this.canEdit,
    required this.ministry,
    required this.eventMinistryId,
  });

  final EventSchedule schedule;
  final bool isSelf;
  final bool canEdit;
  final Ministry ministry;
  final String eventMinistryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = schedule.fullName.isNotEmpty
        ? schedule.fullName
              .trim()
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            backgroundImage: schedule.avatarUrl != null
                ? NetworkImage(schedule.avatarUrl!)
                : null,
            child: schedule.avatarUrl == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                  schedule.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (schedule.functions.isNotEmpty)
                  Text(
                    schedule.functions
                        .map(
                          (fn) => '${functionEmoji(fn)} ${functionLabel(fn)}',
                        )
                        .join('  '),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _ConfirmCircle(schedule: schedule, isSelf: isSelf),
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 14),
              color: Colors.white.withValues(alpha: 0.3),
              onPressed: () => _editFunctions(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 15),
              color: Colors.white.withValues(alpha: 0.3),
              onPressed: () async {
                await ref
                    .read(eventsRepositoryProvider)
                    .removePersonFromSchedule(schedule.id);
                bumpRefreshTick(ref);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _editFunctions(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.read(ministryMembersProvider(ministry.id));
    final roster = membersAsync.value ?? const <MinistryMember>[];
    final person = roster.firstWhere(
      (m) => m.userId == schedule.userId,
      orElse: () => MinistryMember(
        userId: schedule.userId,
        fullName: schedule.fullName,
        functions: schedule.functions,
      ),
    );
    final available = {...person.functions, ...schedule.functions}.toList();
    final selected = {...schedule.functions};

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Funções',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                if (available.isEmpty)
                  Text(
                    'Esta pessoa não tem funções definidas neste ministério.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  )
                else
                  for (final fn in available)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(fn),
                      title: Text('${functionEmoji(fn)} ${functionLabel(fn)}'),
                      onChanged: (checked) => setModalState(() {
                        if (checked == true) {
                          selected.add(fn);
                        } else {
                          selected.remove(fn);
                        }
                      }),
                    ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: _ghostButtonStyle,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: _primaryButtonStyle,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await ref
                            .read(eventsRepositoryProvider)
                            .updateScheduleFunctions(
                              schedule.id,
                              selected.toList(),
                            );
                        bumpRefreshTick(ref);
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmCircle extends ConsumerWidget {
  const _ConfirmCircle({required this.schedule, required this.isSelf});

  final EventSchedule schedule;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color color;
    final IconData icon;
    if (schedule.confirmed == true) {
      color = const Color(0xFF6EE7B7);
      icon = Icons.check;
    } else if (schedule.confirmed == false) {
      color = const Color(0xFFF87171);
      icon = Icons.close;
    } else {
      color = Colors.white.withValues(alpha: 0.3);
      icon = Icons.remove;
    }

    final circle = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: schedule.confirmed == null
            ? Colors.white.withValues(alpha: 0.07)
            : color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 13, color: color),
    );

    if (!isSelf) return circle;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        await ref
            .read(eventsRepositoryProvider)
            .confirmSchedule(schedule.id, schedule.confirmed != true);
        bumpRefreshTick(ref);
      },
      child: circle,
    );
  }
}

class _AddPersonButton extends ConsumerWidget {
  const _AddPersonButton({
    required this.eventMinistryId,
    required this.ministry,
    required this.schedules,
  });

  final String eventMinistryId;
  final Ministry ministry;
  final List<EventSchedule> schedules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Colors.white.withValues(alpha: 0.55),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: () => _pickMemberToAdd(context, ref),
      icon: const Icon(Icons.person_add_alt_outlined, size: 14),
      label: const Text('Adicionar pessoa'),
    );
  }

  void _pickMemberToAdd(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.read(ministryMembersProvider(ministry.id));
    final members = membersAsync.value ?? const <MinistryMember>[];
    final assignedIds = schedules.map((s) => s.userId).toSet();
    final available = members
        .where((m) => !assignedIds.contains(m.userId))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: available.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todos os membros já estão escalados.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final person in available)
                    ListTile(
                      title: Text(person.fullName),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await ref
                            .read(eventsRepositoryProvider)
                            .addPersonToSchedule(
                              eventMinistryId,
                              person.userId,
                              person.functions,
                            );
                        bumpRefreshTick(ref);
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

class _WhatsAppContactsSheet extends ConsumerStatefulWidget {
  const _WhatsAppContactsSheet({
    required this.orgId,
    required this.event,
    required this.contacts,
  });

  final String orgId;
  final Event event;
  final List<ScheduledContact> contacts;

  @override
  ConsumerState<_WhatsAppContactsSheet> createState() =>
      _WhatsAppContactsSheetState();
}

class _WhatsAppContactsSheetState
    extends ConsumerState<_WhatsAppContactsSheet> {
  final Set<String> _selectedIds = {};
  final Set<String> _sentTo = {};

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(
      widget.contacts.where((c) => c.phone != null).map((c) => c.userId),
    );
  }

  Future<void> _sendNext() async {
    final membership = ref.read(orgStoreProvider);
    final next = widget.contacts.firstWhere(
      (c) => _selectedIds.contains(c.userId) && !_sentTo.contains(c.userId),
      orElse: () => const ScheduledContact(
        userId: '',
        name: '',
        confirmed: null,
        ministries: [],
      ),
    );
    if (next.userId.isEmpty) return;

    final message = scheduleMessage(
      name: next.name,
      orgName: membership?.organization.name ?? 'a tua igreja',
      ministry: next.ministries.join(' / '),
      eventName: widget.event.name,
      date: widget.event.date,
      time:
          '${widget.event.time.hour.toString().padLeft(2, '0')}:${widget.event.time.minute.toString().padLeft(2, '0')}',
      arrivalTime: widget.event.arrivalTime != null
          ? '${widget.event.arrivalTime!.hour.toString().padLeft(2, '0')}:${widget.event.arrivalTime!.minute.toString().padLeft(2, '0')}'
          : null,
    );
    final uri = Uri.parse(buildWhatsAppLink(next.phone, message));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    setState(() => _sentTo.add(next.userId));
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _selectedIds.difference(_sentTo).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enviar por WhatsApp',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final contact in widget.contacts)
                    CheckboxListTile(
                      value: _selectedIds.contains(contact.userId),
                      onChanged: contact.phone == null
                          ? null
                          : (checked) => setState(() {
                              if (checked == true) {
                                _selectedIds.add(contact.userId);
                              } else {
                                _selectedIds.remove(contact.userId);
                              }
                            }),
                      title: Text(contact.name),
                      subtitle: Text(
                        contact.phone == null
                            ? 'Sem telemóvel'
                            : (_sentTo.contains(contact.userId)
                                  ? 'Enviado'
                                  : contact.ministries.join(', ')),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: remaining == 0 ? null : _sendNext,
              child: Text(
                remaining == 0 ? 'Tudo enviado' : 'Enviar ($remaining)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
