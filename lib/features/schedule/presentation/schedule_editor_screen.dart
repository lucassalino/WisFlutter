import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/domain/event.dart';
import '../../../shared/state/org_store.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/whatsapp.dart';
import '../../ministries/domain/ministry.dart';
import '../../ministries/domain/ministry_member.dart';
import '../../ministries/presentation/ministries_providers.dart';
import '../../events/data/events_repository.dart';
import '../../events/domain/event_schedule.dart';
import '../../events/domain/scheduled_contact.dart';
import '../../events/presentation/events_providers.dart';
import '../../onboarding/domain/membership_role.dart';

/// Editor de escala de um evento — adiciona/remove ministérios e pessoas
/// incrementalmente (ao contrário do wizard de Eventos, que grava tudo de
/// uma vez), confirma presença própria e Publica & Notifica.
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
  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(orgStoreProvider);
    final canEdit =
        membership?.role == MembershipRole.admin ||
        membership?.role == MembershipRole.leader;
    final ministriesAsync = ref.watch(eventMinistriesProvider(widget.event.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.name),
        actions: canEdit
            ? [
                TextButton.icon(
                  onPressed: () => _publishAndNotify(context),
                  icon: const Icon(
                    Icons.campaign_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Publicar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ]
            : null,
      ),
      body: ministriesAsync.when(
        data: (eventMinistries) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final eventMinistry in eventMinistries)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      '${eventMinistry.ministry.icon} ${eventMinistry.ministry.name}',
                    ),
                    trailing: canEdit
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref
                                  .read(eventsRepositoryProvider)
                                  .removeMinistryFromEvent(eventMinistry.id);
                              bumpRefreshTick(ref);
                            },
                          )
                        : null,
                    children: [
                      _SchedulesSection(
                        eventMinistryId: eventMinistry.id,
                        ministry: eventMinistry.ministry,
                        canEdit: canEdit,
                      ),
                    ],
                  ),
                ),
              if (canEdit)
                _buildAddMinistryButton(
                  eventMinistries.map((e) => e.ministry.id).toSet(),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  Widget _buildAddMinistryButton(Set<String> existingIds) {
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));
    return ministriesAsync.when(
      data: (ministries) {
        final available = ministries
            .where((m) => m.isActive && !existingIds.contains(m.id))
            .toList();
        if (available.isEmpty) return const SizedBox.shrink();
        return OutlinedButton.icon(
          onPressed: () => _pickMinistryToAdd(available),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar ministério'),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _pickMinistryToAdd(List<Ministry> available) {
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
                      .addMinistryToEvent(widget.event.id, ministry);
                  bumpRefreshTick(ref);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishAndNotify(BuildContext context) async {
    final repo = ref.read(eventsRepositoryProvider);
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

    final contacts = await repo.fetchScheduledContacts(widget.event.id);
    if (!context.mounted || contacts.isEmpty) return;
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

class _SchedulesSection extends ConsumerWidget {
  const _SchedulesSection({
    required this.eventMinistryId,
    required this.ministry,
    required this.canEdit,
  });

  final String eventMinistryId;
  final Ministry ministry;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(eventSchedulesProvider(eventMinistryId));
    final membersAsync = ref.watch(ministryMembersProvider(ministry.id));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: schedulesAsync.when(
        data: (schedules) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (schedules.isEmpty) const Text('Ninguém escalado.'),
              for (final schedule in schedules)
                _ScheduleTile(
                  schedule: schedule,
                  isSelf: schedule.userId == currentUserId,
                  canEdit: canEdit,
                ),
              if (canEdit)
                membersAsync.maybeWhen(
                  data: (members) => Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          _pickMemberToAdd(context, ref, members, schedules),
                      icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                      label: const Text('Adicionar pessoa'),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text('Erro: $error'),
      ),
    );
  }

  void _pickMemberToAdd(
    BuildContext context,
    WidgetRef ref,
    List<MinistryMember> members,
    List<EventSchedule> schedules,
  ) {
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

class _ScheduleTile extends ConsumerWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.isSelf,
    required this.canEdit,
  });

  final EventSchedule schedule;
  final bool isSelf;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget statusIcon;
    if (schedule.confirmed == true) {
      statusIcon = const Icon(
        Icons.check_circle,
        color: Colors.greenAccent,
        size: 20,
      );
    } else if (schedule.confirmed == false) {
      statusIcon = const Icon(Icons.cancel, color: Colors.redAccent, size: 20);
    } else {
      statusIcon = const Icon(
        Icons.hourglass_empty,
        color: Colors.white38,
        size: 20,
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(schedule.fullName),
      subtitle: Text(schedule.functions.map(functionLabel).join(', ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelf) ...[
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
              ),
              onPressed: () async {
                await ref
                    .read(eventsRepositoryProvider)
                    .confirmSchedule(schedule.id, true);
                bumpRefreshTick(ref);
              },
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              onPressed: () async {
                await ref
                    .read(eventsRepositoryProvider)
                    .confirmSchedule(schedule.id, false);
                bumpRefreshTick(ref);
              },
            ),
          ] else
            statusIcon,
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () async {
                await ref
                    .read(eventsRepositoryProvider)
                    .removePersonFromSchedule(schedule.id);
                bumpRefreshTick(ref);
              },
            ),
        ],
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
