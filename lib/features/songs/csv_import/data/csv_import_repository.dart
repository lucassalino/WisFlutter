import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/songs_repository.dart';
import '../domain/csv_import_schema.dart';

final csvImportRepositoryProvider = Provider<CsvImportRepository>((ref) {
  return CsvImportRepository(ref.watch(songsRepositoryProvider));
});

enum ImportedSongStatus { matched, created }

class ImportedSong {
  const ImportedSong({
    required this.index,
    required this.songId,
    required this.name,
    required this.musicalKey,
    required this.status,
  });

  final int index;
  final String songId;
  final String name;
  final String? musicalKey;
  final ImportedSongStatus status;
}

class ImportResult {
  const ImportResult({
    required this.songs,
    required this.createdCount,
    required this.matchedCount,
  });

  final List<ImportedSong> songs;
  final int createdCount;
  final int matchedCount;
}

const _diacritics = {
  'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

String _norm(String? s) {
  final lower = (s ?? '').toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Deduplica pelo repertório da própria organização (nome+artista) e
/// reaproveita `SongsRepository.createSong` — que já resolve o catálogo
/// global — para tudo o que for novo. Espelha `importSongs` do ServiceFlow.
class CsvImportRepository {
  CsvImportRepository(this._songsRepository);

  final SongsRepository _songsRepository;

  Future<ImportResult> importSongs(String orgId, List<SongDraft> drafts) async {
    final existing = await _songsRepository.fetchSongs(orgId);
    final byKey = <String, String>{
      for (final s in existing) '${_norm(s.name)}|${_norm(s.artist)}': s.id,
    };

    final songs = <ImportedSong>[];
    var created = 0;
    var matched = 0;

    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      final name = draft.name.trim();
      if (name.isEmpty) continue;
      final key = '${_norm(name)}|${_norm(draft.artist)}';
      final hit = byKey[key];
      if (hit != null) {
        songs.add(
          ImportedSong(
            index: i,
            songId: hit,
            name: name,
            musicalKey: draft.musicalKey,
            status: ImportedSongStatus.matched,
          ),
        );
        matched++;
        continue;
      }

      final song = await _songsRepository.createSong(
        orgId,
        SongPayload(
          name: name,
          artist: draft.artist,
          musicalKey: draft.musicalKey,
          bpm: draft.bpm,
          duration: draft.duration,
          bibleReference: draft.bibleReference,
          youtubeUrl: draft.youtubeUrl,
          spotifyUrl: draft.spotifyUrl,
          chords: draft.chords,
          lyrics: draft.lyrics,
        ),
      );
      byKey[key] = song.id;
      songs.add(
        ImportedSong(
          index: i,
          songId: song.id,
          name: name,
          musicalKey: draft.musicalKey,
          status: ImportedSongStatus.created,
        ),
      );
      created++;
    }

    return ImportResult(songs: songs, createdCount: created, matchedCount: matched);
  }
}
