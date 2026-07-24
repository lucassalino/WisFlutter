class Song {
  const Song({
    required this.id,
    required this.orgId,
    this.ministryId,
    required this.name,
    this.artist,
    this.musicalKey,
    this.bpm,
    this.lyrics,
    this.chords,
    this.youtubeUrl,
    this.spotifyUrl,
    this.catalogSongId,
  });

  final String id;
  final String orgId;
  final String? ministryId;
  final String name;
  final String? artist;
  final String? musicalKey;
  final int? bpm;
  final String? lyrics;
  final String? chords;
  final String? youtubeUrl;
  final String? spotifyUrl;
  final String? catalogSongId;

  factory Song.fromMap(Map<String, dynamic> map) => Song(
    id: map['id'] as String,
    orgId: map['org_id'] as String,
    ministryId: map['ministry_id'] as String?,
    name: map['name'] as String,
    artist: map['artist'] as String?,
    musicalKey: map['musical_key'] as String?,
    bpm: map['bpm'] as int?,
    lyrics: map['lyrics'] as String?,
    chords: map['chords'] as String?,
    youtubeUrl: map['youtube_url'] as String?,
    spotifyUrl: map['spotify_url'] as String?,
    catalogSongId: map['catalog_song_id'] as String?,
  );
}

/// Sugestão do catálogo global partilhado (`catalog_songs`), usada no
/// autocomplete ao criar/editar uma música.
class CatalogSuggestion {
  const CatalogSuggestion({
    required this.id,
    required this.name,
    required this.artist,
    this.lyrics,
    this.chords,
    this.youtubeUrl,
    this.spotifyUrl,
    this.bpm,
  });

  final String id;
  final String name;
  final String artist;
  final String? lyrics;
  final String? chords;
  final String? youtubeUrl;
  final String? spotifyUrl;
  final int? bpm;

  factory CatalogSuggestion.fromMap(Map<String, dynamic> map) =>
      CatalogSuggestion(
        id: map['id'] as String,
        name: map['name'] as String,
        artist: map['artist'] as String? ?? '',
        lyrics: map['lyrics'] as String?,
        chords: map['chords'] as String?,
        youtubeUrl: map['youtube_url'] as String?,
        spotifyUrl: map['spotify_url'] as String?,
        bpm: map['bpm'] as int?,
      );
}

class SongRankingEntry {
  const SongRankingEntry({
    required this.song,
    required this.timesPlayed,
    this.lastPlayedDate,
  });

  final Song song;
  final int timesPlayed;
  final DateTime? lastPlayedDate;
}
