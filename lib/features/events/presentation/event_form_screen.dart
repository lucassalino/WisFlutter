import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/domain/event.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../ministries/domain/ministry.dart';
import '../../ministries/domain/ministry_member.dart';
import '../../ministries/presentation/ministries_providers.dart';
import '../../songs/domain/song.dart';
import '../../songs/presentation/songs_providers.dart';
import '../data/events_repository.dart';
import '../domain/event_timeline_item.dart';

/// Criar/editar evento — wizard com 5 passos (Informação, Ministérios,
/// Integrantes, Setlist, Roteiro) e um único botão Gravar/Criar que grava
/// tudo de uma vez (`replaceEventSetup`). Espelha EventCreatePanel.tsx /
/// EventEditPanel.tsx.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, required this.orgId, this.event});

  final String orgId;
  final Event? event;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _observationsController = TextEditingController();
  final _timelineTitleController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  TimeOfDay? _arrivalTime;
  bool _isPublished = false;

  Set<String> _selectedMinistryIds = {};
  Map<String, List<EventScheduleAssignment>> _membersByMinistry = {};
  List<String> _songIds = [];
  Map<String, String> _songKeys = {};
  List<EventTimelineItem> _timeline = [];
  TimeOfDay _newTimelineTime = const TimeOfDay(hour: 9, minute: 0);

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final event = widget.event;
    if (event != null) {
      _nameController.text = event.name;
      _locationController.text = event.location ?? '';
      _descriptionController.text = event.description ?? '';
      _observationsController.text = event.observations ?? '';
      _date = event.date;
      _time = event.time;
      _arrivalTime = event.arrivalTime;
      _isPublished = event.isPublished;
      _loadExistingSetup(event.id);
    } else {
      _loading = false;
    }
  }

  Future<void> _loadExistingSetup(String eventId) async {
    final setup = await ref
        .read(eventsRepositoryProvider)
        .fetchEventSetup(eventId);
    if (!mounted) return;
    setState(() {
      _selectedMinistryIds = setup.ministryIds.toSet();
      _membersByMinistry = setup.membersByMinistry;
      _songIds = setup.songIds;
      _songKeys = setup.songKeys;
      _timeline = setup.timeline;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _observationsController.dispose();
    _timelineTitleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      _tabController.index = 0;
      setState(() => _error = 'Introduz um nome para o evento');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final payload = EventPayload(
      name: _nameController.text.trim(),
      date: _date,
      time: _time,
      arrivalTime: _arrivalTime,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      color: null,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      observations: _observationsController.text.trim().isEmpty
          ? null
          : _observationsController.text.trim(),
      isPublished: _isPublished,
    );

    try {
      final repo = ref.read(eventsRepositoryProvider);
      final eventId = _isEditing
          ? widget.event!.id
          : (await repo.createEvent(widget.orgId, payload)).id;
      if (_isEditing) await repo.updateEvent(eventId, payload);

      await repo.replaceEventSetup(
        eventId,
        [
          for (final ministryId in _selectedMinistryIds)
            EventMinistrySetup(
              ministryId: ministryId,
              members: _membersByMinistry[ministryId] ?? const [],
            ),
        ],
        _songIds,
        _songKeys,
        _timeline,
      );
      bumpRefreshTick(ref);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _error = 'Não foi possível guardar. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar evento' : 'Novo evento'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Informação'),
            Tab(text: 'Ministérios'),
            Tab(text: 'Integrantes'),
            Tab(text: 'Setlist'),
            Tab(text: 'Roteiro'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildMinistriesTab(),
                _buildMembersTab(),
                _buildSetlistTab(),
                _buildTimelineTab(),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Guardar' : 'Criar'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Passo 1: Informação ──────────────────────────────────────────────

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome do evento'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('${_date.day}/${_date.month}/${_date.year}'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) setState(() => _time = picked);
                },
                icon: const Icon(Icons.access_time_outlined),
                label: Text(_time.format(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _arrivalTime ?? _time,
                  );
                  if (picked != null) setState(() => _arrivalTime = picked);
                },
                icon: const Icon(Icons.login_outlined),
                label: Text(
                  _arrivalTime != null
                      ? 'Chegada: ${_arrivalTime!.format(context)}'
                      : 'Hora de chegada',
                ),
              ),
            ),
            if (_arrivalTime != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _arrivalTime = null),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(labelText: 'Local'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: 'Descrição'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _observationsController,
          decoration: const InputDecoration(labelText: 'Observações'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _isPublished,
          onChanged: (value) => setState(() => _isPublished = value),
          title: const Text('Publicado'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // ── Passo 2: Ministérios ─────────────────────────────────────────────

  Widget _buildMinistriesTab() {
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));
    return ministriesAsync.when(
      data: (ministries) {
        final active = ministries.where((m) => m.isActive).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final ministry in active)
              CheckboxListTile(
                value: _selectedMinistryIds.contains(ministry.id),
                title: Text('${ministry.icon} ${ministry.name}'),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selectedMinistryIds.add(ministry.id);
                  } else {
                    _selectedMinistryIds.remove(ministry.id);
                    _membersByMinistry.remove(ministry.id);
                  }
                }),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  // ── Passo 3: Integrantes ─────────────────────────────────────────────

  Widget _buildMembersTab() {
    if (_selectedMinistryIds.isEmpty) {
      return const Center(
        child: Text('Seleciona ministérios no passo anterior.'),
      );
    }
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));
    return ministriesAsync.when(
      data: (ministries) {
        final selected = ministries
            .where((m) => _selectedMinistryIds.contains(m.id))
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final ministry in selected)
              _buildMinistryMembersCard(ministry),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  Widget _buildMinistryMembersCard(Ministry ministry) {
    final membersAsync = ref.watch(ministryMembersProvider(ministry.id));
    final assigned = _membersByMinistry[ministry.id] ?? const [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ministry.icon} ${ministry.name}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                membersAsync.maybeWhen(
                  data: (members) => IconButton(
                    icon: const Icon(Icons.person_add_alt_outlined),
                    onPressed: () =>
                        _pickMemberToAssign(ministry.id, members, assigned),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            membersAsync.when(
              data: (members) {
                if (assigned.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Ninguém escalado ainda.'),
                  );
                }
                return Column(
                  children: [
                    for (final assignment in assigned)
                      _buildAssignmentTile(ministry, members, assignment),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Text('Erro: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentTile(
    Ministry ministry,
    List<MinistryMember> members,
    EventScheduleAssignment assignment,
  ) {
    final person = members.firstWhere(
      (m) => m.userId == assignment.userId,
      orElse: () => MinistryMember(
        userId: assignment.userId,
        fullName: 'Pessoa',
        functions: [],
      ),
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(person.fullName),
      subtitle: Wrap(
        spacing: 6,
        children: [
          for (final key in person.functions)
            FilterChip(
              label: Text(
                '${functionEmoji(key)} ${functionLabel(key)}',
                style: const TextStyle(fontSize: 12),
              ),
              selected: assignment.functions.contains(key),
              onSelected: (selected) => setState(() {
                final list = _membersByMinistry[ministry.id]!;
                final index = list.indexWhere(
                  (a) => a.userId == assignment.userId,
                );
                final updatedFunctions = {...assignment.functions};
                if (selected) {
                  updatedFunctions.add(key);
                } else {
                  updatedFunctions.remove(key);
                }
                list[index] = EventScheduleAssignment(
                  userId: assignment.userId,
                  functions: updatedFunctions.toList(),
                );
              }),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() {
          _membersByMinistry[ministry.id]!.removeWhere(
            (a) => a.userId == assignment.userId,
          );
        }),
      ),
    );
  }

  void _pickMemberToAssign(
    String ministryId,
    List<MinistryMember> members,
    List<EventScheduleAssignment> assigned,
  ) {
    final assignedIds = assigned.map((a) => a.userId).toSet();
    final available = members
        .where((m) => !assignedIds.contains(m.userId))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: available.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todos os membros deste ministério já estão escalados.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final person in available)
                    ListTile(
                      title: Text(person.fullName),
                      onTap: () {
                        setState(() {
                          (_membersByMinistry[ministryId] ??= []).add(
                            EventScheduleAssignment(
                              userId: person.userId,
                              functions: const [],
                            ),
                          );
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
      ),
    );
  }

  // ── Passo 4: Setlist ─────────────────────────────────────────────────

  Widget _buildSetlistTab() {
    final songsAsync = ref.watch(songsListProvider(widget.orgId));
    return songsAsync.when(
      data: (songs) {
        final available = songs.where((s) => !_songIds.contains(s.id)).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_songIds.isNotEmpty) ...[
              Text('Repertório', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              for (final songId in _songIds) _buildSetlistTile(songs, songId),
              const SizedBox(height: 16),
            ],
            Text(
              'Adicionar música',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            for (final song in available)
              ListTile(
                dense: true,
                title: Text(song.name),
                subtitle: song.artist != null ? Text(song.artist!) : null,
                trailing: const Icon(Icons.add),
                onTap: () => setState(() {
                  _songIds.add(song.id);
                  if (song.musicalKey != null) {
                    _songKeys[song.id] = song.musicalKey!;
                  }
                }),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  Widget _buildSetlistTile(List<Song> songs, String songId) {
    final song = songs.firstWhere(
      (s) => s.id == songId,
      orElse: () => Song(id: songId, orgId: widget.orgId, name: 'Música'),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(song.name),
        subtitle: song.artist != null ? Text(song.artist!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: _songKeys[songId],
              hint: const Text('Tom'),
              items: [
                for (final key in songKeys)
                  DropdownMenuItem(value: key, child: Text(key)),
              ],
              onChanged: (value) => setState(() {
                if (value != null) _songKeys[songId] = value;
              }),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _songIds.remove(songId);
                _songKeys.remove(songId);
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Passo 5: Roteiro ─────────────────────────────────────────────────

  Widget _buildTimelineTab() {
    final sorted = [..._timeline]..sort(EventTimelineItem.compare);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in sorted)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Text(item.timeLabel),
              title: Text(item.title),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _timeline.remove(item)),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _newTimelineTime,
                );
                if (picked != null) setState(() => _newTimelineTime = picked);
              },
              child: Text(_newTimelineTime.format(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _timelineTitleController,
                decoration: const InputDecoration(
                  labelText: 'Título (ex: Devocional)',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                if (_timelineTitleController.text.trim().isEmpty) return;
                setState(() {
                  _timeline.add(
                    EventTimelineItem(
                      time: _newTimelineTime,
                      title: _timelineTitleController.text.trim(),
                    ),
                  );
                  _timelineTitleController.clear();
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
