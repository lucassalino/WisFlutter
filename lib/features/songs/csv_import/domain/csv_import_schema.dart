import '../../../../shared/constants/ministry_constants.dart';

/// Campos-alvo do importador e o seu mapeamento a partir de um CSV
/// arbitrário — espelha `setlist-schema.ts` do ServiceFlow (agnóstico de
/// plataforma, só muda a camada de I/O do ficheiro).
enum TargetKey {
  name,
  artist,
  musicalKey,
  bpm,
  duration,
  bibleReference,
  youtubeUrl,
  spotifyUrl,
  chords,
  lyrics,
}

class TargetField {
  const TargetField({
    required this.key,
    required this.label,
    required this.required,
    required this.aliases,
  });

  final TargetKey key;
  final String label;
  final bool required;
  final List<String> aliases;
}

const targetFields = <TargetField>[
  TargetField(
    key: TargetKey.name,
    label: 'Nome da música',
    required: true,
    aliases: [
      'nome',
      'musica',
      'música',
      'song',
      'title',
      'titulo',
      'título',
      'name',
      'cancao',
      'canção',
    ],
  ),
  TargetField(
    key: TargetKey.artist,
    label: 'Artista',
    required: false,
    aliases: [
      'artista',
      'artist',
      'autor',
      'interprete',
      'intérprete',
      'banda',
      'cantor',
      'ministerio',
      'ministério',
    ],
  ),
  TargetField(
    key: TargetKey.musicalKey,
    label: 'Tom',
    required: false,
    aliases: ['tom', 'key', 'tonalidade', 'nota'],
  ),
  TargetField(
    key: TargetKey.bpm,
    label: 'BPM',
    required: false,
    aliases: ['bpm', 'andamento'],
  ),
  TargetField(
    key: TargetKey.duration,
    label: 'Duração',
    required: false,
    aliases: ['duracao', 'duração', 'duration', 'tempo', 'tempomusica', 'length'],
  ),
  TargetField(
    key: TargetKey.bibleReference,
    label: 'Referência bíblica',
    required: false,
    aliases: [
      'referencia',
      'referência',
      'referenciabiblica',
      'versiculo',
      'versículo',
      'biblia',
      'bíblia',
      'passagem',
      'texto',
    ],
  ),
  TargetField(
    key: TargetKey.youtubeUrl,
    label: 'YouTube',
    required: false,
    aliases: ['youtube', 'yt', 'ytlink', 'videoyoutube', 'video', 'vídeo'],
  ),
  TargetField(
    key: TargetKey.spotifyUrl,
    label: 'Spotify',
    required: false,
    aliases: ['spotify', 'spotifyurl', 'linkspotify'],
  ),
  TargetField(
    key: TargetKey.chords,
    label: 'Cifra',
    required: false,
    aliases: ['cifra', 'cifras', 'chords', 'acordes', 'cifraclub'],
  ),
  TargetField(
    key: TargetKey.lyrics,
    label: 'Letra',
    required: false,
    aliases: ['letra', 'letras', 'lyrics', 'letramusica'],
  ),
];

typedef RawRow = Map<String, String>;
typedef ColumnMapping = Map<TargetKey, String?>;

ColumnMapping emptyMapping() => {for (final f in targetFields) f.key: null};

const _diacritics = {
  'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Normaliza para comparar cabeçalhos: sem acentos, minúsculas, só
/// letras/dígitos.
String normalizeHeader(String s) {
  final lower = s.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
}

/// Remove acentos sem descartar outros caracteres (ao contrário de
/// [normalizeHeader]) — usado para reconhecer "Ré"/"Dó"/"Lá"/… antes de
/// comparar com os nomes de nota em latim.
String _stripDiacritics(String s) {
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString();
}

/// Auto-associa cabeçalhos do CSV a campos-alvo (exato primeiro, depois
/// parcial) — espelha `autoMap` do ServiceFlow.
ColumnMapping autoMap(List<String> headers) {
  final mapping = emptyMapping();
  final normalizedHeaders = [
    for (final h in headers) (raw: h, norm: normalizeHeader(h)),
  ];
  bool taken(String h) => mapping.values.contains(h);

  for (final field in targetFields) {
    final aliases = field.aliases.map(normalizeHeader).toSet();
    final exact = normalizedHeaders
        .cast<({String raw, String norm})?>()
        .firstWhere(
          (h) => aliases.contains(h!.norm) && !taken(h.raw),
          orElse: () => null,
        );
    final partial =
        exact ??
        normalizedHeaders.cast<({String raw, String norm})?>().firstWhere(
          (h) =>
              !taken(h!.raw) &&
              aliases.any(
                (a) => a.length >= 2 && (h.norm.contains(a) || a.contains(h.norm)),
              ),
          orElse: () => null,
        );
    if (partial != null) mapping[field.key] = partial.raw;
  }
  return mapping;
}

bool isMappingValid(ColumnMapping mapping) {
  return targetFields
      .where((f) => f.required)
      .every((f) => mapping[f.key] != null);
}

class SongDraft {
  const SongDraft({
    required this.name,
    this.artist,
    this.musicalKey,
    this.bpm,
    this.duration,
    this.bibleReference,
    this.youtubeUrl,
    this.spotifyUrl,
    this.chords,
    this.lyrics,
  });

  final String name;
  final String? artist;
  final String? musicalKey;
  final int? bpm;
  final String? duration;
  final String? bibleReference;
  final String? youtubeUrl;
  final String? spotifyUrl;
  final String? chords;
  final String? lyrics;
}

/// Normaliza para comparar tons: minúsculas, sem espaços, mas preserva
/// `#`/`b` — ao contrário de [normalizeHeader], que os descartaria e faria
/// "C#" colidir com "C".
String _normalizeKeyCompare(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// Normaliza um tom livre (dó/ré/…, com ou sem acidente/menor) para o
/// catálogo fechado [songKeys] — espelha `normalizeMusicalKey`.
String? normalizeMusicalKey(String? value) {
  if (value == null) return null;
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final direct = raw.replaceAll(RegExp(r'\s+'), '');

  for (final key in songKeys) {
    if (_normalizeKeyCompare(key) == _normalizeKeyCompare(direct)) return key;
  }

  const pt = {
    'do': 'C', 'c': 'C',
    're': 'D', 'd': 'D',
    'mi': 'E', 'e': 'E',
    'fa': 'F', 'f': 'F',
    'sol': 'G', 'g': 'G',
    'la': 'A', 'a': 'A',
    'si': 'B', 'b': 'B',
  };
  // Nomes latinos enumerados explicitamente (não um `[a-zA-Z]+` guloso):
  // um `+` genérico engoliria o "m" de menor em sufixos como "Lam"/"Solm",
  // deixando o grupo de acidente/menor sempre vazio. Os acentos ("Ré",
  // "Dó", "Lá"…) são removidos antes de comparar com a lista fixa.
  final match = RegExp(
    r'^(sol|do|re|mi|fa|la|si|[a-g])([#b♯♭]?)(m|min|menor)?$',
    caseSensitive: false,
  ).firstMatch(_stripDiacritics(direct.toLowerCase()));
  if (match != null) {
    final base = pt[match.group(1)!.toLowerCase()];
    if (base != null) {
      final accRaw = match.group(2) ?? '';
      final acc = accRaw == '♯' ? '#' : (accRaw == '♭' ? 'b' : accRaw);
      final isMinor = match.group(3) != null;
      final candidate = '$base$acc${isMinor ? 'm' : ''}';
      for (final key in songKeys) {
        if (_normalizeKeyCompare(key) == _normalizeKeyCompare(candidate)) return key;
      }
      return candidate;
    }
  }
  return raw;
}

/// Converte uma linha do CSV num rascunho de música, aplicando o
/// mapeamento de colunas — linhas sem nome são ignoradas.
SongDraft? rowToDraft(RawRow row, ColumnMapping mapping) {
  String get(TargetKey key) {
    final header = mapping[key];
    return header != null ? (row[header] ?? '').trim() : '';
  }

  final name = get(TargetKey.name);
  if (name.isEmpty) return null;

  final bpmDigits = get(TargetKey.bpm).replaceAll(RegExp(r'[^0-9]'), '');
  final bpm = bpmDigits.isNotEmpty ? int.tryParse(bpmDigits) : null;

  String? orNull(String value) => value.isEmpty ? null : value;

  return SongDraft(
    name: name,
    artist: orNull(get(TargetKey.artist)),
    musicalKey: normalizeMusicalKey(get(TargetKey.musicalKey)),
    bpm: bpm,
    duration: orNull(get(TargetKey.duration)),
    bibleReference: orNull(get(TargetKey.bibleReference)),
    youtubeUrl: orNull(get(TargetKey.youtubeUrl)),
    spotifyUrl: orNull(get(TargetKey.spotifyUrl)),
    chords: orNull(get(TargetKey.chords)),
    lyrics: orNull(get(TargetKey.lyrics)),
  );
}

/// Extrai o id do vídeo de um link do YouTube (só links diretos, não de
/// pesquisa).
String? youtubeVideoId(String? url) {
  if (url == null || url.isEmpty) return null;
  final patterns = [
    RegExp(r'[?&]v=([A-Za-z0-9_-]{11})'),
    RegExp(r'youtu\.be/([A-Za-z0-9_-]{11})'),
    RegExp(r'/embed/([A-Za-z0-9_-]{11})'),
    RegExp(r'/shorts/([A-Za-z0-9_-]{11})'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(url);
    if (match != null) return match.group(1);
  }
  return null;
}

String? youtubeThumbnail(String? url) {
  final id = youtubeVideoId(url);
  return id != null ? 'https://img.youtube.com/vi/$id/hqdefault.jpg' : null;
}
