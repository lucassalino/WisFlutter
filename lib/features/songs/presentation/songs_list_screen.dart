import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/spotlight_background.dart';
import '../../shell/presentation/app_drawer.dart';
import '../../shell/presentation/wis_header_bar.dart';
import '../csv_import/presentation/csv_import_screen.dart';
import '../domain/song.dart';
import 'song_detail_screen.dart';
import 'song_form_screen.dart';
import 'songs_providers.dart';

enum _SongsTab { list, ranking }

final _primaryButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

final _ghostButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: Colors.white.withValues(alpha: 0.06),
  foregroundColor: Colors.white.withValues(alpha: 0.75),
  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

const _rankBadgeColor = Color(0xFFA5B4FC);

class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  _SongsTab _tab = _SongsTab.list;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsListProvider(widget.orgId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const WisHeaderBar(),
      drawer: const AppDrawer(current: AppDrawerItem.songs),
      body: SpotlightBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    'Repertório',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  songsAsync.maybeWhen(
                    data: (songs) => Text(
                      '${songs.length} '
                      '${songs.length == 1 ? 'música' : 'músicas'} no repertório',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: _ghostButtonStyle,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  CsvImportScreen(orgId: widget.orgId),
                            ),
                          ),
                          icon: const Icon(Icons.upload_file_outlined, size: 14),
                          label: const Text('Importar CSV'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: _primaryButtonStyle,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  SongFormScreen(orgId: widget.orgId),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Nova Música'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TabSwitch(
                  value: _tab,
                  onChanged: (value) => setState(() => _tab = value),
                ),
              ),
            ),
            if (_tab == _SongsTab.list)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Pesquisar por nome ou artista...',
                  ),
                  onChanged: (value) =>
                      setState(() => _search = value.toLowerCase()),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _tab == _SongsTab.list ? _buildList() : _buildRanking(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final songsAsync = ref.watch(songsListProvider(widget.orgId));
    return songsAsync.when(
      data: (songs) {
        final filtered = songs.where((song) {
          return _search.isEmpty ||
              song.name.toLowerCase().contains(_search) ||
              (song.artist ?? '').toLowerCase().contains(_search);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'Nenhuma música encontrada.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _SongTile(orgId: widget.orgId, song: filtered[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Erro ao carregar músicas: $error')),
    );
  }

  Widget _buildRanking() {
    final rankingAsync = ref.watch(songsRankingProvider(widget.orgId));
    return rankingAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Text(
              'Ainda sem músicas tocadas.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final position = index + 1;
            return GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SongDetailScreen(orgId: widget.orgId, song: entry.song),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$positionº',
                      style: TextStyle(
                        fontSize: position <= 3 ? 20 : 17,
                        fontWeight: position <= 3
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: switch (position) {
                          1 => const Color(0xFFFBBF24),
                          2 => Colors.white.withValues(alpha: 0.85),
                          3 => const Color(0xFFF97316),
                          _ => Colors.white.withValues(alpha: 0.3),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.song.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (entry.song.artist != null &&
                                entry.song.artist!.isNotEmpty)
                              entry.song.artist!,
                            if (entry.lastPlayedDate != null)
                              'última vez '
                                  '${entry.lastPlayedDate!.day.toString().padLeft(2, '0')}/'
                                  '${entry.lastPlayedDate!.month.toString().padLeft(2, '0')}/'
                                  '${entry.lastPlayedDate!.year}',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _rankBadgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _rankBadgeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${entry.timesPlayed}× tocada',
                      style: TextStyle(
                        color: _rankBadgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Erro ao carregar ranking: $error')),
    );
  }
}

class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.value, required this.onChanged});

  final _SongsTab value;
  final ValueChanged<_SongsTab> onChanged;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabButton(
            icon: Icons.queue_music,
            label: 'Lista',
            selected: value == _SongsTab.list,
            onTap: () => onChanged(_SongsTab.list),
          ),
          _TabButton(
            icon: Icons.emoji_events_outlined,
            label: 'Ranking',
            selected: value == _SongsTab.ranking,
            onTap: () => onChanged(_SongsTab.ranking),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? Colors.black
                  : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.black
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.orgId, required this.song});

  final String orgId;
  final Song song;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SongDetailScreen(orgId: orgId, song: song),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.music_note,
              size: 18,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (song.artist != null && song.artist!.isNotEmpty)
                  Text(
                    song.artist!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (song.youtubeUrl != null)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.smart_display,
                size: 16,
                color: Color(0xFFF87171),
              ),
            ),
          if (song.spotifyUrl != null)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.library_music,
                size: 16,
                color: Color(0xFF6EE7B7),
              ),
            ),
          if (song.chords != null && song.chords!.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.link, size: 16, color: Color(0xFFFCD34D)),
            ),
          if (song.lyrics != null && song.lyrics!.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.description_outlined,
                size: 16,
                color: Color(0xFFA5B4FC),
              ),
            ),
          if (song.musicalKey != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                song.musicalKey!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
