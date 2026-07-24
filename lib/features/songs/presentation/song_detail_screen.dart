import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/state/refresh_tick.dart';
import '../data/songs_repository.dart';
import '../domain/song.dart';
import 'song_form_screen.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.orgId, required this.song});

  final String orgId;
  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(song.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SongFormScreen(orgId: orgId, song: song),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar música'),
                  content: Text('Eliminar "${song.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(songsRepositoryProvider).deleteSong(song.id);
                bumpRefreshTick(ref);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (song.artist != null && song.artist!.isNotEmpty)
            Text(song.artist!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              if (song.musicalKey != null)
                Chip(label: Text('Tom: ${song.musicalKey}')),
              if (song.bpm != null) Chip(label: Text('${song.bpm} BPM')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (song.youtubeUrl != null && song.youtubeUrl!.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(song.youtubeUrl!)),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('YouTube'),
                ),
              const SizedBox(width: 12),
              if (song.spotifyUrl != null && song.spotifyUrl!.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(song.spotifyUrl!)),
                  icon: const Icon(Icons.music_note_outlined),
                  label: const Text('Spotify'),
                ),
            ],
          ),
          if (song.chords != null && song.chords!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Cifra', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(
              song.chords!,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
          if (song.lyrics != null && song.lyrics!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Letra', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(song.lyrics!),
          ],
        ],
      ),
    );
  }
}
