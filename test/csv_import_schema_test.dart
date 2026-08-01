import 'package:flutter_test/flutter_test.dart';
import 'package:wis/features/songs/csv_import/domain/csv_import_schema.dart';

void main() {
  group('autoMap', () {
    test('matches aliases regardless of accents/case', () {
      final mapping = autoMap(['Nome', 'Artista', 'Tom', 'BPM', 'Duração', 'YouTube']);
      expect(mapping[TargetKey.name], 'Nome');
      expect(mapping[TargetKey.artist], 'Artista');
      expect(mapping[TargetKey.musicalKey], 'Tom');
      expect(mapping[TargetKey.bpm], 'BPM');
      expect(mapping[TargetKey.duration], 'Duração');
      expect(mapping[TargetKey.youtubeUrl], 'YouTube');
    });

    test('leaves unmapped fields null when no header matches', () {
      final mapping = autoMap(['Coluna Desconhecida']);
      expect(mapping[TargetKey.name], isNull);
      expect(mapping.values.every((v) => v == null), isTrue);
    });

    test('does not map the same header to two fields', () {
      final mapping = autoMap(['musica']);
      expect(mapping[TargetKey.name], 'musica');
      expect(mapping[TargetKey.artist], isNull);
    });
  });

  group('isMappingValid', () {
    test('false when required Nome is unmapped', () {
      expect(isMappingValid(emptyMapping()), isFalse);
    });

    test('true once Nome is mapped', () {
      final mapping = emptyMapping();
      mapping[TargetKey.name] = 'Nome';
      expect(isMappingValid(mapping), isTrue);
    });
  });

  group('normalizeMusicalKey', () {
    test('passes through an already-valid key', () {
      expect(normalizeMusicalKey('C#m'), 'C#m');
    });

    test('converts Portuguese note names to the closed catalog', () {
      expect(normalizeMusicalKey('Ré'), 'D');
      expect(normalizeMusicalKey('sol'), 'G');
      expect(normalizeMusicalKey('lam'), 'Am');
    });

    test('returns null for empty input', () {
      expect(normalizeMusicalKey(''), isNull);
      expect(normalizeMusicalKey(null), isNull);
    });
  });

  group('rowToDraft', () {
    test('ignores rows without a name', () {
      final mapping = autoMap(['Nome', 'Artista']);
      final draft = rowToDraft({'Nome': '', 'Artista': 'Alguém'}, mapping);
      expect(draft, isNull);
    });

    test('builds a draft from a mapped row', () {
      final mapping = autoMap(['Nome', 'Artista', 'Tom', 'BPM']);
      final draft = rowToDraft(
        {'Nome': 'Ruja o Leão', 'Artista': 'Isaías Saad', 'Tom': 'C#m', 'BPM': '96 bpm'},
        mapping,
      );
      expect(draft, isNotNull);
      expect(draft!.name, 'Ruja o Leão');
      expect(draft.artist, 'Isaías Saad');
      expect(draft.musicalKey, 'C#m');
      expect(draft.bpm, 96);
    });
  });

  group('youtube helpers', () {
    test('extracts the video id from common URL shapes', () {
      expect(youtubeVideoId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(
        youtubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('builds a thumbnail URL when a video id is found', () {
      expect(
        youtubeThumbnail('https://youtu.be/dQw4w9WgXcQ'),
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
    });

    test('returns null for search URLs without a direct video id', () {
      expect(youtubeThumbnail('https://youtube.com/results?search_query=louvor'), isNull);
    });
  });
}
