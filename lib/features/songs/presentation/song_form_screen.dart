import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/ministry_constants.dart';
import '../../../shared/state/refresh_tick.dart';
import '../../ministries/presentation/ministries_providers.dart';
import '../data/songs_repository.dart';
import '../domain/song.dart';

/// Criar ou editar uma música — o campo Nome pesquisa o catálogo global
/// (`catalog_songs`) por nome/artista; ao escolher uma sugestão, preenche
/// artista, letra, cifra, links e BPM automaticamente. Espelha
/// SongFormPanel.tsx.
class SongFormScreen extends ConsumerStatefulWidget {
  const SongFormScreen({super.key, required this.orgId, this.song});

  final String orgId;
  final Song? song;

  @override
  ConsumerState<SongFormScreen> createState() => _SongFormScreenState();
}

class _SongFormScreenState extends ConsumerState<SongFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _artistController;
  late final TextEditingController _bpmController;
  late final TextEditingController _youtubeController;
  late final TextEditingController _spotifyController;
  late final TextEditingController _lyricsController;
  late final TextEditingController _chordsController;
  String? _musicalKey;
  String? _ministryId;
  bool _submitting = false;
  String? _error;

  List<CatalogSuggestion> _suggestions = [];
  Timer? _debounce;

  bool get _isEditing => widget.song != null;

  @override
  void initState() {
    super.initState();
    final song = widget.song;
    _nameController = TextEditingController(text: song?.name ?? '');
    _artistController = TextEditingController(text: song?.artist ?? '');
    _bpmController = TextEditingController(text: song?.bpm?.toString() ?? '');
    _youtubeController = TextEditingController(text: song?.youtubeUrl ?? '');
    _spotifyController = TextEditingController(text: song?.spotifyUrl ?? '');
    _lyricsController = TextEditingController(text: song?.lyrics ?? '');
    _chordsController = TextEditingController(text: song?.chords ?? '');
    _musicalKey = song?.musicalKey;
    _ministryId = song?.ministryId;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _artistController.dispose();
    _bpmController.dispose();
    _youtubeController.dispose();
    _spotifyController.dispose();
    _lyricsController.dispose();
    _chordsController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await ref
          .read(songsRepositoryProvider)
          .searchCatalog(value);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  void _applySuggestion(CatalogSuggestion suggestion) {
    setState(() {
      _nameController.text = suggestion.name;
      _artistController.text = suggestion.artist;
      _lyricsController.text = suggestion.lyrics ?? _lyricsController.text;
      _chordsController.text = suggestion.chords ?? _chordsController.text;
      _youtubeController.text =
          suggestion.youtubeUrl ?? _youtubeController.text;
      _spotifyController.text =
          suggestion.spotifyUrl ?? _spotifyController.text;
      if (suggestion.bpm != null) {
        _bpmController.text = suggestion.bpm.toString();
      }
      _suggestions = [];
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final payload = SongPayload(
      name: _nameController.text.trim(),
      artist: _artistController.text.trim().isEmpty
          ? null
          : _artistController.text.trim(),
      musicalKey: _musicalKey,
      bpm: int.tryParse(_bpmController.text.trim()),
      lyrics: _lyricsController.text.trim().isEmpty
          ? null
          : _lyricsController.text.trim(),
      chords: _chordsController.text.trim().isEmpty
          ? null
          : _chordsController.text.trim(),
      youtubeUrl: _youtubeController.text.trim().isEmpty
          ? null
          : _youtubeController.text.trim(),
      spotifyUrl: _spotifyController.text.trim().isEmpty
          ? null
          : _spotifyController.text.trim(),
      ministryId: _ministryId,
    );
    try {
      final repo = ref.read(songsRepositoryProvider);
      if (_isEditing) {
        await repo.updateSong(widget.song!.id, widget.orgId, payload);
      } else {
        await repo.createSong(widget.orgId, payload);
      }
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
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar música' : 'Nova música')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              onChanged: _onNameChanged,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Introduz um nome'
                  : null,
            ),
            if (_suggestions.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: 4),
                child: Column(
                  children: [
                    for (final suggestion in _suggestions)
                      ListTile(
                        dense: true,
                        title: Text(suggestion.name),
                        subtitle: suggestion.artist.isNotEmpty
                            ? Text(suggestion.artist)
                            : null,
                        onTap: () => _applySuggestion(suggestion),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artista'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _musicalKey,
                    decoration: const InputDecoration(labelText: 'Tom'),
                    items: [
                      for (final key in songKeys)
                        DropdownMenuItem(value: key, child: Text(key)),
                    ],
                    onChanged: (value) => setState(() => _musicalKey = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bpmController,
                    decoration: const InputDecoration(labelText: 'BPM'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ministriesAsync.when(
              data: (ministries) => DropdownButtonFormField<String?>(
                initialValue: _ministryId,
                decoration: const InputDecoration(labelText: 'Ministério'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sem ministério'),
                  ),
                  for (final ministry in ministries)
                    DropdownMenuItem(
                      value: ministry.id,
                      child: Text(ministry.name),
                    ),
                ],
                onChanged: (value) => setState(() => _ministryId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _youtubeController,
              decoration: const InputDecoration(labelText: 'Link do YouTube'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _spotifyController,
              decoration: const InputDecoration(labelText: 'Link do Spotify'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _chordsController,
              decoration: const InputDecoration(labelText: 'Cifra'),
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lyricsController,
              decoration: const InputDecoration(labelText: 'Letra'),
              maxLines: 8,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Guardar' : 'Criar'),
            ),
          ],
        ),
      ),
    );
  }
}
