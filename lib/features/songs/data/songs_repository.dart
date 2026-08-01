import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/song.dart';

final songsRepositoryProvider = Provider<SongsRepository>((ref) {
  return SongsRepository(ref.watch(supabaseClientProvider));
});

class SongPayload {
  const SongPayload({
    required this.name,
    this.artist,
    this.musicalKey,
    this.bpm,
    this.duration,
    this.bibleReference,
    this.lyrics,
    this.chords,
    this.youtubeUrl,
    this.spotifyUrl,
    this.ministryId,
  });

  final String name;
  final String? artist;
  final String? musicalKey;
  final int? bpm;
  final String? duration;
  final String? bibleReference;
  final String? lyrics;
  final String? chords;
  final String? youtubeUrl;
  final String? spotifyUrl;
  final String? ministryId;

  Map<String, dynamic> toMap() => {
    'name': name,
    'artist': artist,
    'musical_key': musicalKey,
    'bpm': bpm,
    'duration': duration,
    'bible_reference': bibleReference,
    'lyrics': lyrics,
    'chords': chords,
    'youtube_url': youtubeUrl,
    'spotify_url': spotifyUrl,
    'ministry_id': ministryId,
  };
}

/// Campos partilhados no catálogo global (o Tom NÃO é partilhado — é por
/// evento). Espelha SHARED_KEYS em src/actions/songs.ts.
const _sharedCatalogKeys = [
  'lyrics',
  'chords',
  'youtube_url',
  'spotify_url',
  'bpm',
];

bool _isEmpty(dynamic value) => value == null || value == '';

class SongsRepository {
  SongsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Song>> fetchSongs(String orgId) async {
    final rows = await _client
        .from('songs')
        .select()
        .eq('org_id', orgId)
        .order('name');
    return (rows as List)
        .map((row) => Song.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<CatalogSuggestion>> searchCatalog(String term) async {
    final query = term.trim().replaceAll(RegExp('[,()]'), ' ').trim();
    if (query.length < 2) return [];
    final like = '%$query%';
    final rows = await _client
        .from('catalog_songs')
        .select(
          'id, name, artist, lyrics, chords, youtube_url, spotify_url, bpm',
        )
        .or('name.ilike.$like,artist.ilike.$like')
        .order('name')
        .limit(10);
    return (rows as List)
        .map((row) => CatalogSuggestion.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  String _escapeIlike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_]'), (match) => '\\${match.group(0)}');

  /// Liga uma música ao catálogo global pela chave (nome + artista) —
  /// espelha `resolveCatalog` em src/actions/songs.ts: se já existir,
  /// contribui só os campos vazios; senão cria a entrada. Devolve o id.
  Future<String?> _resolveCatalog(
    SongPayload payload,
    String orgId,
    String userId,
  ) async {
    final name = payload.name.trim();
    final artist = (payload.artist ?? '').trim();
    if (name.isEmpty) return null;

    final found = await _client
        .from('catalog_songs')
        .select()
        .ilike('name', _escapeIlike(name))
        .ilike('artist', _escapeIlike(artist))
        .limit(1)
        .maybeSingle();

    if (found != null) {
      final patch = <String, dynamic>{};
      final payloadMap = payload.toMap();
      for (final key in _sharedCatalogKeys) {
        if (_isEmpty(found[key]) && !_isEmpty(payloadMap[key])) {
          patch[key] = payloadMap[key];
        }
      }
      if (patch.isNotEmpty) {
        patch['updated_at'] = DateTime.now().toIso8601String();
        await _client
            .from('catalog_songs')
            .update(patch)
            .eq('id', found['id'] as String);
      }
      return found['id'] as String;
    }

    try {
      final created = await _client
          .from('catalog_songs')
          .insert({
            'name': name,
            'artist': artist,
            'lyrics': payload.lyrics,
            'chords': payload.chords,
            'youtube_url': payload.youtubeUrl,
            'spotify_url': payload.spotifyUrl,
            'bpm': payload.bpm,
            'source_org_id': orgId,
            'created_by': userId,
          })
          .select('id')
          .single();
      return created['id'] as String;
    } catch (_) {
      // Corrida: outra igreja criou a mesma entrada entretanto — procurar de novo.
      final retry = await _client
          .from('catalog_songs')
          .select('id')
          .ilike('name', _escapeIlike(name))
          .ilike('artist', _escapeIlike(artist))
          .limit(1)
          .maybeSingle();
      return retry?['id'] as String?;
    }
  }

  Future<Song> createSong(String orgId, SongPayload payload) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    final catalogId = await _resolveCatalog(payload, orgId, userId);
    final row = await _client
        .from('songs')
        .insert({
          ...payload.toMap(),
          'org_id': orgId,
          'catalog_song_id': catalogId,
        })
        .select()
        .single();
    return Song.fromMap(row);
  }

  Future<void> updateSong(String id, String orgId, SongPayload payload) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sessão expirada');
    await _client
        .from('songs')
        .update({
          ...payload.toMap(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
    final catalogId = await _resolveCatalog(payload, orgId, userId);
    if (catalogId != null) {
      await _client
          .from('songs')
          .update({'catalog_song_id': catalogId})
          .eq('id', id);
    }
  }

  Future<void> deleteSong(String id) async {
    await _client.from('songs').delete().eq('id', id);
  }

  /// Ranking de músicas mais tocadas: conta ocorrências em `event_setlists`
  /// por música da organização, ordenado por nº de vezes (desc).
  Future<List<SongRankingEntry>> fetchSongsRanking(String orgId) async {
    final songs = await fetchSongs(orgId);
    if (songs.isEmpty) return [];

    final setlistRows = await _client
        .from('event_setlists')
        .select('song_id, event:events(date)')
        .inFilter('song_id', songs.map((s) => s.id).toList());

    final counts = <String, int>{};
    final lastDates = <String, DateTime>{};
    for (final row in setlistRows as List) {
      final songId = row['song_id'] as String;
      counts[songId] = (counts[songId] ?? 0) + 1;
      final eventDate =
          (row['event'] as Map<String, dynamic>?)?['date'] as String?;
      if (eventDate != null) {
        final date = DateTime.parse(eventDate);
        final current = lastDates[songId];
        if (current == null || date.isAfter(current)) lastDates[songId] = date;
      }
    }

    final entries = songs
        .map(
          (song) => SongRankingEntry(
            song: song,
            timesPlayed: counts[song.id] ?? 0,
            lastPlayedDate: lastDates[song.id],
          ),
        )
        .where((entry) => entry.timesPlayed > 0)
        .toList();
    entries.sort((a, b) {
      final byCount = b.timesPlayed.compareTo(a.timesPlayed);
      return byCount != 0 ? byCount : a.song.name.compareTo(b.song.name);
    });
    return entries;
  }
}
