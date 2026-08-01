import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/data/storage_repository.dart';
import '../../../shared/domain/event.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../../shared/utils/hex_color.dart';
import '../../../shared/utils/image_picker_helper.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../ministries/domain/ministry.dart';
import '../../ministries/domain/ministry_member.dart';
import '../../ministries/presentation/ministries_providers.dart';
import '../../songs/domain/song.dart';
import '../../songs/presentation/songs_providers.dart';
import '../data/events_repository.dart';
import '../domain/event_timeline_item.dart';

const _stepMeta = [
  (label: 'Informações', eyebrow: 'NOME, DATA, HORÁRIO E LOCAL'),
  (label: 'Ministérios', eyebrow: 'QUAIS EQUIPAS PARTICIPAM'),
  (label: 'Integrantes', eyebrow: 'ESCALA DE MEMBROS'),
  (label: 'Setlist', eyebrow: 'MÚSICAS DO EVENTO'),
  (label: 'Roteiro', eyebrow: 'HORÁRIOS DO EVENTO'),
];

final _cardDecoration = BoxDecoration(
  color: Colors.white.withValues(alpha: 0.04),
  border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
  borderRadius: BorderRadius.circular(14),
);

final _ghostButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: Colors.white.withValues(alpha: 0.06),
  foregroundColor: Colors.white.withValues(alpha: 0.6),
  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

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

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  int _step = 0;
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _observationsController = TextEditingController();
  final _timelineTitleController = TextEditingController();
  final _songSearchController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  TimeOfDay? _arrivalTime;
  bool _isPublished = false;
  String? _coverImageUrl;
  bool _uploadingCover = false;

  Set<String> _selectedMinistryIds = {};
  Map<String, List<EventScheduleAssignment>> _membersByMinistry = {};
  List<String> _songIds = [];
  Map<String, String> _songKeys = {};
  String _songSearch = '';
  List<EventTimelineItem> _timeline = [];
  TimeOfDay? _newTimelineTime;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
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
      _coverImageUrl = event.coverImageUrl;
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
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _observationsController.dispose();
    _timelineTitleController.dispose();
    _songSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final file = await pickAndCropImage(
      context,
      preset: CropAspectRatioPreset.ratio16x9,
    );
    if (file == null) return;
    setState(() => _uploadingCover = true);
    try {
      final url = await ref
          .read(storageRepositoryProvider)
          .uploadEventCover(widget.orgId, file);
      if (mounted) setState(() => _coverImageUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar a imagem.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _step = 0;
        _error = 'Introduz um nome para o evento';
      });
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
      coverImageUrl: _coverImageUrl,
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
    final meta = _stepMeta[_step];

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
                            'Eventos',
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
                      _isEditing ? 'Editar evento' : 'Novo evento',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.88, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 28),
                        child: Row(
                          children: [
                            for (var i = 0; i < _stepMeta.length; i++) ...[
                              _StepPill(
                                index: i,
                                label: _stepMeta[i].label,
                                active: _step == i,
                                onTap: () => setState(() => _step = i),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      meta.eyebrow,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    switch (_step) {
                      0 => _buildInfoStep(),
                      1 => _buildMinistriesStep(),
                      2 => _buildMembersStep(),
                      3 => _buildSetlistStep(),
                      _ => _buildTimelineStep(),
                    },
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: _ghostButtonStyle,
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: _primaryButtonStyle,
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  _isEditing
                                      ? 'Gravar alterações'
                                      : 'Criar evento',
                                ),
                              ],
                            ),
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

  // ── Passo 1: Informação ──────────────────────────────────────────────

  Widget _buildInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Nome', required: true),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Nome do evento'),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Data', required: true),
                  _PickerField(
                    text:
                        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Horário', required: true),
                  _PickerField(
                    text: _time.format(context),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (picked != null) setState(() => _time = picked);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldLabel('Hora de chegada da equipa'),
        _PickerField(
          text: _arrivalTime?.format(context),
          placeholder: '--:--',
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _arrivalTime ?? _time,
            );
            if (picked != null) setState(() => _arrivalTime = picked);
          },
          onClear: _arrivalTime != null
              ? () => setState(() => _arrivalTime = null)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          'Opcional — a que horas a equipa deve chegar (ensaio/passagem de som).',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 16),
        _FieldLabel('Local'),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(hintText: 'Local do evento'),
        ),
        const SizedBox(height: 16),
        _FieldLabel('Descrição'),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(hintText: 'Descrição do evento'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _FieldLabel('Observações'),
        TextField(
          controller: _observationsController,
          decoration: const InputDecoration(hintText: 'Observações internas'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(() => _isPublished = !_isPublished),
          child: Row(
            children: [
              Checkbox(
                value: _isPublished,
                onChanged: (value) =>
                    setState(() => _isPublished = value ?? false),
              ),
              const SizedBox(width: 4),
              Text(
                'Publicar evento',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FieldLabel('Imagem de capa'),
        GestureDetector(
          onTap: _uploadingCover ? null : _pickCoverImage,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                style: BorderStyle.solid,
              ),
              image: _coverImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_coverImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: _uploadingCover
                ? const CircularProgressIndicator()
                : _coverImageUrl == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clica para adicionar imagem',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                          onPressed: () =>
                              setState(() => _coverImageUrl = null),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Passo 2: Ministérios ─────────────────────────────────────────────

  Widget _buildMinistriesStep() {
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));
    return ministriesAsync.when(
      data: (ministries) {
        final active = ministries.where((m) => m.isActive).toList();
        if (active.isEmpty) {
          return const _EmptyBox(
            icon: Icons.grid_view_outlined,
            message: 'Nenhum ministério ativo.',
          );
        }
        return Container(
          decoration: _cardDecoration,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < active.length; i++)
                _MinistryCheckRow(
                  ministry: active[i],
                  checked: _selectedMinistryIds.contains(active[i].id),
                  showDivider: i < active.length - 1,
                  onToggle: () => setState(() {
                    final id = active[i].id;
                    if (_selectedMinistryIds.contains(id)) {
                      _selectedMinistryIds.remove(id);
                      _membersByMinistry.remove(id);
                    } else {
                      _selectedMinistryIds.add(id);
                    }
                  }),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  // ── Passo 3: Integrantes ─────────────────────────────────────────────

  Widget _buildMembersStep() {
    if (_selectedMinistryIds.isEmpty) {
      return _EmptyBox(
        icon: Icons.people_outline,
        message: 'Nenhum ministério selecionado.',
        actionLabel: '← Selecionar ministérios',
        onAction: () => setState(() => _step = 1),
      );
    }
    final totalSelected = _membersByMinistry.values.fold<int>(
      0,
      (acc, list) => acc + list.length,
    );
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));
    return ministriesAsync.when(
      data: (ministries) {
        final selected = ministries
            .where((m) => _selectedMinistryIds.contains(m.id))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (totalSelected > 0) ...[
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$totalSelected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' membro${totalSelected != 1 ? 's' : ''} selecionado${totalSelected != 1 ? 's' : ''}',
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 12),
            ],
            for (final ministry in selected) ...[
              _MinistryMembersCard(
                ministry: ministry,
                assigned: _membersByMinistry[ministry.id] ?? const [],
                onToggleMember: (userId) => setState(() {
                  final list = _membersByMinistry[ministry.id] ?? [];
                  final has = list.any((a) => a.userId == userId);
                  if (has) {
                    list.removeWhere((a) => a.userId == userId);
                  } else {
                    list.add(
                      EventScheduleAssignment(
                        userId: userId,
                        functions: const [],
                      ),
                    );
                  }
                  _membersByMinistry[ministry.id] = list;
                }),
                onToggleFunction: (userId, fn) => setState(() {
                  final list = _membersByMinistry[ministry.id]!;
                  final index = list.indexWhere((a) => a.userId == userId);
                  final assignment = list[index];
                  final updated = {...assignment.functions};
                  if (updated.contains(fn)) {
                    updated.remove(fn);
                  } else {
                    updated.add(fn);
                  }
                  list[index] = EventScheduleAssignment(
                    userId: userId,
                    functions: updated.toList(),
                  );
                }),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  // ── Passo 4: Setlist ─────────────────────────────────────────────────

  Widget _buildSetlistStep() {
    final songsAsync = ref.watch(songsListProvider(widget.orgId));
    return songsAsync.when(
      data: (songs) {
        final filtered = _songSearch.isEmpty
            ? songs
            : songs
                  .where(
                    (s) =>
                        s.name.toLowerCase().contains(_songSearch) ||
                        (s.artist?.toLowerCase().contains(_songSearch) ??
                            false),
                  )
                  .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _songSearchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Pesquisar músicas...',
              ),
              onChanged: (value) =>
                  setState(() => _songSearch = value.toLowerCase()),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 340),
              decoration: _cardDecoration,
              clipBehavior: Clip.antiAlias,
              child: filtered.isEmpty
                  ? _EmptyBox(
                      icon: Icons.queue_music_outlined,
                      message: _songSearch.isNotEmpty
                          ? 'Nenhuma música encontrada.'
                          : 'Nenhuma música criada ainda.',
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var i = 0; i < filtered.length; i++)
                            _SongCheckRow(
                              song: filtered[i],
                              checked: _songIds.contains(filtered[i].id),
                              showDivider: i < filtered.length - 1,
                              onToggle: () => _toggleSong(filtered[i]),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              'SETLIST SELECCIONADO (${_songIds.length})',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 10),
            if (_songIds.isEmpty)
              const _EmptyBox(
                icon: Icons.music_note_outlined,
                message: 'Nenhuma música seleccionada',
              )
            else
              Container(
                decoration: _cardDecoration,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < _songIds.length; i++)
                      _SelectedSongRow(
                        index: i + 1,
                        song: songs.firstWhere(
                          (s) => s.id == _songIds[i],
                          orElse: () => Song(
                            id: _songIds[i],
                            orgId: widget.orgId,
                            name: 'Música',
                          ),
                        ),
                        selectedKey: _songKeys[_songIds[i]],
                        showDivider: i < _songIds.length - 1,
                        onKeyChanged: (key) =>
                            setState(() => _songKeys[_songIds[i]] = key),
                        onRemove: () => setState(() {
                          _songKeys.remove(_songIds[i]);
                          _songIds.removeAt(i);
                        }),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }

  void _toggleSong(Song song) {
    setState(() {
      if (_songIds.contains(song.id)) {
        _songIds.remove(song.id);
        _songKeys.remove(song.id);
      } else {
        _songIds.add(song.id);
        if (song.musicalKey != null) _songKeys[song.id] = song.musicalKey!;
      }
    });
  }

  // ── Passo 5: Roteiro ─────────────────────────────────────────────────

  Widget _buildTimelineStep() {
    final sorted = [..._timeline]..sort(EventTimelineItem.compare);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Opcional — os momentos do evento (chegada, ensaio, devocional, início do culto…), por ordem de hora.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Hora'),
                  _PickerField(
                    text: _newTimelineTime?.format(context),
                    placeholder: '--:--',
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            _newTimelineTime ??
                            const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) {
                        setState(() => _newTimelineTime = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Momento'),
                  TextField(
                    controller: _timelineTitleController,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Início do ensaio',
                    ),
                    onSubmitted: (_) => _addTimelineItem(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: _ghostButtonStyle,
          onPressed: _addTimelineItem,
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Adicionar momento'),
        ),
        const SizedBox(height: 16),
        if (sorted.isEmpty)
          const _EmptyBox(
            icon: Icons.access_time,
            message: 'Nenhum momento adicionado',
          )
        else
          Container(
            decoration: _cardDecoration,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < sorted.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: i < sorted.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            sorted[i].timeLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            sorted[i].title,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          color: Colors.white.withValues(alpha: 0.3),
                          onPressed: () =>
                              setState(() => _timeline.remove(sorted[i])),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _addTimelineItem() {
    if (_newTimelineTime == null ||
        _timelineTitleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche a hora e o título do momento')),
      );
      return;
    }
    setState(() {
      _timeline.add(
        EventTimelineItem(
          time: _newTimelineTime!,
          title: _timelineTitleController.text.trim(),
        ),
      );
      _timelineTitleController.clear();
      _newTimelineTime = null;
    });
  }
}

// ── Widgets partilhados ────────────────────────────────────────────────────

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.index,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          '${index + 1}. $label',
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? Colors.black : Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(color: Color(0xFFF87171), fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.text,
    this.placeholder = '',
    required this.onTap,
    this.onClear,
  });

  final String? text;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

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
            if (onClear != null)
              InkWell(
                onTap: onClear,
                child: Icon(
                  Icons.clear,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              style: _ghostButtonStyle,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MinistryCheckRow extends StatelessWidget {
  const _MinistryCheckRow({
    required this.ministry,
    required this.checked,
    required this.showDivider,
    required this.onToggle,
  });

  final Ministry ministry;
  final bool checked;
  final bool showDivider;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(ministry.color);
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: checked
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.transparent,
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Checkbox(value: checked, onChanged: (_) => onToggle()),
            const SizedBox(width: 4),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color.withValues(alpha: 0.19)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ministry.name.isNotEmpty ? ministry.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                ministry.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (checked)
              const Icon(Icons.check, size: 15, color: Color(0xFF6EE7B7)),
          ],
        ),
      ),
    );
  }
}

class _MinistryMembersCard extends ConsumerWidget {
  const _MinistryMembersCard({
    required this.ministry,
    required this.assigned,
    required this.onToggleMember,
    required this.onToggleFunction,
  });

  final Ministry ministry;
  final List<EventScheduleAssignment> assigned;
  final void Function(String userId) onToggleMember;
  final void Function(String userId, String fn) onToggleFunction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(ministryMembersProvider(ministry.id));
    final color = hexToColor(ministry.color);
    final assignedIds = assigned.map((a) => a.userId).toSet();

    return Container(
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    ministry.name.isNotEmpty
                        ? ministry.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ministry.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (assigned.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${assigned.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Nenhum membro neste ministério. Adiciona pessoas ao ministério primeiro.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final member in members)
                    _MemberCheckRow(
                      member: member,
                      checked: assignedIds.contains(member.userId),
                      functions: assigned
                          .firstWhere(
                            (a) => a.userId == member.userId,
                            orElse: () => const EventScheduleAssignment(
                              userId: '',
                              functions: [],
                            ),
                          )
                          .functions,
                      onToggle: () => onToggleMember(member.userId),
                      onToggleFunction: (fn) =>
                          onToggleFunction(member.userId, fn),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(14),
              child: LinearProgressIndicator(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Erro: $error'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCheckRow extends StatelessWidget {
  const _MemberCheckRow({
    required this.member,
    required this.checked,
    required this.functions,
    required this.onToggle,
    required this.onToggleFunction,
  });

  final MinistryMember member;
  final bool checked;
  final List<String> functions;
  final VoidCallback onToggle;
  final ValueChanged<String> onToggleFunction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: checked
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              child: Row(
                children: [
                  Checkbox(value: checked, onChanged: (_) => onToggle()),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    backgroundImage: member.avatarUrl != null
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                    child: member.avatarUrl == null
                        ? Text(
                            member.fullName.isNotEmpty
                                ? member.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 10),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      member.fullName,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (checked && functions.isNotEmpty)
                    Text(
                      '${functions.length} fn',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (checked)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: member.functions.isEmpty
                  ? Text(
                      'Esta pessoa não tem funções neste ministério.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < member.functions.length; i += 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _FunctionCheck(
                                    fn: member.functions[i],
                                    checked: functions.contains(
                                      member.functions[i],
                                    ),
                                    onToggle: () =>
                                        onToggleFunction(member.functions[i]),
                                  ),
                                ),
                                if (i + 1 < member.functions.length)
                                  Expanded(
                                    child: _FunctionCheck(
                                      fn: member.functions[i + 1],
                                      checked: functions.contains(
                                        member.functions[i + 1],
                                      ),
                                      onToggle: () => onToggleFunction(
                                        member.functions[i + 1],
                                      ),
                                    ),
                                  )
                                else
                                  const Spacer(),
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

class _FunctionCheck extends StatelessWidget {
  const _FunctionCheck({
    required this.fn,
    required this.checked,
    required this.onToggle,
  });

  final String fn;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: checked,
            onChanged: (_) => onToggle(),
            visualDensity: VisualDensity.compact,
          ),
          Flexible(
            child: Text(
              '${functionEmoji(fn)} ${functionLabel(fn)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SongCheckRow extends StatelessWidget {
  const _SongCheckRow({
    required this.song,
    required this.checked,
    required this.showDivider,
    required this.onToggle,
  });

  final Song song;
  final bool checked;
  final bool showDivider;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: checked
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Checkbox(value: checked, onChanged: (_) => onToggle()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (song.artist != null)
                    Text(
                      song.artist!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (song.musicalKey != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  song.musicalKey!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedSongRow extends StatelessWidget {
  const _SelectedSongRow({
    required this.index,
    required this.song,
    required this.selectedKey,
    required this.showDivider,
    required this.onKeyChanged,
    required this.onRemove,
  });

  final int index;
  final Song song;
  final String? selectedKey;
  final bool showDivider;
  final ValueChanged<String> onKeyChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              )
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$index',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (song.artist != null)
                  Text(
                    song.artist!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedKey,
                hint: const Text('Tom', style: TextStyle(fontSize: 12)),
                isDense: true,
                dropdownColor: const Color(0xFF1A1A20),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                items: [
                  for (final key in songKeys)
                    DropdownMenuItem(value: key, child: Text(key)),
                ],
                onChanged: (value) {
                  if (value != null) onKeyChanged(value);
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 15),
            color: Colors.white.withValues(alpha: 0.3),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
