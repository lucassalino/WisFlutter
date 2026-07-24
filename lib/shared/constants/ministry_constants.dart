/// Espelha src/lib/constants.ts do ServiceFlow — mantém os mesmos valores
/// (chaves, emojis, cores) porque já existem organizações com dados gravados
/// usando este catálogo exato.
library;

class MemberFunction {
  const MemberFunction(this.key, this.label, this.emoji);
  final String key;
  final String label;
  final String emoji;
}

const memberFunctions = <MemberFunction>[
  MemberFunction('coordination', 'Coordenação', '🎯'),
  MemberFunction('worship_leader', 'Ministro (Vocal)', '🙌'),
  MemberFunction('back_vocal', 'Backvocal', '🎙️'),
  MemberFunction('drummer', 'Bateria', '🥁'),
  MemberFunction('bass', 'Baixo', '🎸'),
  MemberFunction('acoustic', 'Violão', '🪕'),
  MemberFunction('keys', 'Teclado/Piano', '🎹'),
  MemberFunction('guitarist', 'Guitarra', '🎸'),
  MemberFunction('percussion', 'Percussão', '🪘'),
  MemberFunction('violin', 'Violino', '🎻'),
  MemberFunction('trumpet', 'Trompete', '🎺'),
  MemberFunction('flute', 'Flauta', '🪈'),
  MemberFunction('sound_operator', 'Mesa de som', '🎚️'),
  MemberFunction('media', 'Mídia', '💻'),
  MemberFunction('live_stream', 'Transmissão', '📡'),
  MemberFunction('camera_operator', 'Câmera', '📹'),
  MemberFunction('projection', 'Projeção/Slides', '🖥️'),
  MemberFunction('photography', 'Fotografia', '📷'),
  MemberFunction('lighting', 'Iluminação', '💡'),
  MemberFunction('preacher', 'Pregador', '📢'),
  MemberFunction('teacher', 'Professor', '📚'),
  MemberFunction('intercessor', 'Intercessor', '🙏'),
  MemberFunction('vigil_leader', 'Líder de vigília', '🌙'),
  MemberFunction('dance', 'Dança', '💃'),
  MemberFunction('drama', 'Teatro', '🎭'),
  MemberFunction('reception', 'Recepção', '👋'),
  MemberFunction('kitchen', 'Cozinha', '🍳'),
  MemberFunction('decoration', 'Decoração', '🎨'),
  MemberFunction('security', 'Segurança', '🔐'),
  MemberFunction('auxiliary', 'Auxiliar', '🤝'),
];

const _customFnSep = '\x1f';

/// Codifica uma função personalizada no mesmo formato usado pela app web:
/// `custom<US><emoji><US><label>` — cabe no array `functions text[]` sem
/// precisar de alterar o schema.
String encodeCustomFunction(String emoji, String label) =>
    'custom$_customFnSep$emoji$_customFnSep${label.trim()}';

bool isCustomFunction(String key) => key.startsWith('custom$_customFnSep');

({String emoji, String label})? _decodeCustomFunction(String key) {
  if (!isCustomFunction(key)) return null;
  final parts = key.split(_customFnSep);
  final emoji = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : '•';
  final label = parts.length > 2 ? parts.sublist(2).join(_customFnSep) : '';
  return (emoji: emoji, label: label.isNotEmpty ? label : 'Função');
}

String functionLabel(String key) {
  final custom = _decodeCustomFunction(key);
  if (custom != null) return custom.label;
  return memberFunctions
      .firstWhere(
        (f) => f.key == key,
        orElse: () => MemberFunction(key, key, '•'),
      )
      .label;
}

String functionEmoji(String key) {
  final custom = _decodeCustomFunction(key);
  if (custom != null) return custom.emoji;
  return memberFunctions
      .firstWhere(
        (f) => f.key == key,
        orElse: () => MemberFunction(key, key, '•'),
      )
      .emoji;
}

const ministryIconChoices = [
  '🎵',
  '❤️',
  '📖',
  '🎤',
  '📷',
  '🔊',
  '✝️',
  '⭐',
  '🙏',
  '🎁',
];

const ministryColorChoices = [
  '#3A3A38',
  '#4A5A6A',
  '#4A6A5A',
  '#6A4A5A',
  '#6A5A4A',
  '#5A4A6A',
  '#4A6A6A',
  '#6A6A4A',
];

const functionIconChoices = [
  '🎤',
  '🎙️',
  '🎧',
  '🎵',
  '🎶',
  '🎼',
  '🙌',
  '👏',
  '🎸',
  '🥁',
  '🎹',
  '🎻',
  '🎺',
  '🎷',
  '🪕',
  '🪘',
  '🪗',
  '🪈',
  '🎚️',
  '🎛️',
  '🔊',
  '🔈',
  '💻',
  '🖥️',
  '⌨️',
  '🖱️',
  '📽️',
  '📹',
  '📷',
  '📸',
  '🎥',
  '🎬',
  '📺',
  '💡',
  '🔦',
  '📡',
  '🛰️',
  '🔌',
  '🔋',
  '📱',
  '📢',
  '🗣️',
  '📖',
  '📚',
  '✏️',
  '📝',
  '✝️',
  '🙏',
  '🌙',
  '🕊️',
  '📜',
  '🎓',
  '💃',
  '🕺',
  '🎭',
  '🎨',
  '🖌️',
  '🎪',
  '🎈',
  '👋',
  '🤝',
  '🍽️',
  '🍳',
  '☕',
  '🧹',
  '🧺',
  '🔐',
  '🛡️',
  '🚗',
  '🅿️',
  '🧭',
  '📋',
  '📌',
  '🗂️',
  '💳',
  '🎫',
  '🏷️',
  '🧒',
  '👶',
  '❤️',
  '💚',
  '⭐',
  '🌟',
  '🔥',
  '🎯',
  '✅',
  '📣',
  '🌱',
  '🕯️',
];

const songKeys = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
  'Cm',
  'C#m',
  'Dm',
  'D#m',
  'Em',
  'Fm',
  'F#m',
  'Gm',
  'G#m',
  'Am',
  'A#m',
  'Bm',
];
