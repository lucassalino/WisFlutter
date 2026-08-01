import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/state/refresh_tick.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../data/songs_repository.dart';
import '../domain/song.dart';
import 'song_form_screen.dart';

final _ghostButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: Colors.white.withValues(alpha: 0.06),
  foregroundColor: Colors.white.withValues(alpha: 0.75),
  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
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

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.orgId, required this.song});

  final String orgId;
  final Song song;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = [
      if (song.youtubeUrl != null && song.youtubeUrl!.isNotEmpty)
        (
          label: 'YouTube',
          url: song.youtubeUrl!,
          icon: Icons.smart_display,
          color: const Color(0xFFF87171),
        ),
      if (song.spotifyUrl != null && song.spotifyUrl!.isNotEmpty)
        (
          label: 'Spotify',
          url: song.spotifyUrl!,
          icon: Icons.library_music,
          color: const Color(0xFF6EE7B7),
        ),
      if (song.chords != null && song.chords!.isNotEmpty)
        (
          label: 'Cifra',
          url: song.chords!,
          icon: Icons.link,
          color: const Color(0xFFFCD34D),
        ),
      if (song.lyrics != null && song.lyrics!.isNotEmpty)
        (
          label: 'Letra',
          url: song.lyrics!,
          icon: Icons.description_outlined,
          color: const Color(0xFFA5B4FC),
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SpotlightBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          'Repertório',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: _ghostButtonStyle,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                SongFormScreen(orgId: orgId, song: song),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 13),
                        label: const Text('Editar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: _dangerButtonStyle,
                        onPressed: () => _confirmDelete(context, ref),
                        icon: const Icon(Icons.delete_outline, size: 13),
                        label: const Text('Remover'),
                      ),
                    ],
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
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (song.artist != null &&
                              song.artist!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              song.artist!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                          if (song.musicalKey != null || song.bpm != null) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (song.musicalKey != null)
                                  _InfoPill(text: 'Tom: ${song.musicalKey}'),
                                if (song.bpm != null)
                                  _InfoPill(text: '${song.bpm} BPM'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (links.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'LINKS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final link in links)
                          SizedBox(
                            width: cardWidth,
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              onTap: () => launchUrl(Uri.parse(link.url)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: link.color.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      link.icon,
                                      size: 18,
                                      color: link.color,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      link.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.open_in_new,
                                    size: 15,
                                    color: Colors.white.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
