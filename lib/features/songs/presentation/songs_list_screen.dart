import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ministries/presentation/ministries_providers.dart';
import '../domain/song.dart';
import 'song_detail_screen.dart';
import 'song_form_screen.dart';
import 'songs_providers.dart';

class SongsListScreen extends ConsumerStatefulWidget {
  const SongsListScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<SongsListScreen> createState() => _SongsListScreenState();
}

class _SongsListScreenState extends ConsumerState<SongsListScreen> {
  bool _rankingView = false;
  String _search = '';
  String? _ministryFilter;

  @override
  Widget build(BuildContext context) {
    final ministriesAsync = ref.watch(ministriesListProvider(widget.orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repertório'),
        actions: [
          IconButton(
            tooltip: _rankingView ? 'Ver lista' : 'Ver ranking',
            icon: Icon(_rankingView ? Icons.list : Icons.leaderboard_outlined),
            onPressed: () => setState(() => _rankingView = !_rankingView),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_rankingView)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Pesquisar música ou artista',
                ),
                onChanged: (value) =>
                    setState(() => _search = value.toLowerCase()),
              ),
            ),
          if (!_rankingView)
            ministriesAsync.maybeWhen(
              data: (ministries) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _ministryFilter == null,
                        onSelected: (_) =>
                            setState(() => _ministryFilter = null),
                      ),
                      for (final ministry in ministries)
                        ChoiceChip(
                          label: Text(ministry.name),
                          selected: _ministryFilter == ministry.id,
                          onSelected: (_) =>
                              setState(() => _ministryFilter = ministry.id),
                        ),
                    ],
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          Expanded(child: _rankingView ? _buildRanking() : _buildList()),
        ],
      ),
      floatingActionButton: _rankingView
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SongFormScreen(orgId: widget.orgId),
                ),
              ),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildList() {
    final songsAsync = ref.watch(songsListProvider(widget.orgId));
    return songsAsync.when(
      data: (songs) {
        final filtered = songs.where((song) {
          final matchesSearch =
              _search.isEmpty ||
              song.name.toLowerCase().contains(_search) ||
              (song.artist ?? '').toLowerCase().contains(_search);
          final matchesMinistry =
              _ministryFilter == null || song.ministryId == _ministryFilter;
          return matchesSearch && matchesMinistry;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('Nenhuma música encontrada.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
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
          return const Center(child: Text('Ainda sem músicas tocadas.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(entry.song.name),
                subtitle: entry.lastPlayedDate != null
                    ? Text(
                        'Última vez: ${entry.lastPlayedDate!.day}/${entry.lastPlayedDate!.month}/${entry.lastPlayedDate!.year}',
                      )
                    : null,
                trailing: Text('${entry.timesPlayed}x'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        SongDetailScreen(orgId: widget.orgId, song: entry.song),
                  ),
                ),
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

class _SongTile extends StatelessWidget {
  const _SongTile({required this.orgId, required this.song});

  final String orgId;
  final Song song;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(song.name),
        subtitle: song.artist != null && song.artist!.isNotEmpty
            ? Text(song.artist!)
            : null,
        trailing: song.musicalKey != null
            ? Chip(label: Text(song.musicalKey!))
            : null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SongDetailScreen(orgId: orgId, song: song),
          ),
        ),
      ),
    );
  }
}
