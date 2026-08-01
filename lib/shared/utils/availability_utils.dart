import '../../features/availability/domain/unavailability_entry.dart';

const weekdayLabels = [
  'Domingo',
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
];

const _weekdayLabelsPlural = [
  'domingos',
  'segundas-feiras',
  'terças-feiras',
  'quartas-feiras',
  'quintas-feiras',
  'sextas-feiras',
  'sábados',
];

const periodOptions = {'manha': 'Manhã', 'tarde': 'Tarde', 'noite': 'Noite'};

String _periodSuffix(String? period) => switch (period) {
  'manha' => ' de manhã',
  'tarde' => ' de tarde',
  'noite' => ' de noite',
  _ => '',
};

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Texto legível de uma indisponibilidade — espelha `describeUnavailability`
/// do PWA, mas usa datas numéricas (d/MM) para caber no espaço do ecrã móvel.
String describeUnavailability(UnavailabilityEntry entry) {
  final reasonSuffix = (entry.reason != null && entry.reason!.isNotEmpty)
      ? ' — ${entry.reason}'
      : '';
  if (entry.kind == UnavailabilityKind.dateRange) {
    final start = entry.startDate!;
    final end = entry.endDate!;
    return 'Indisponível de ${start.day}/${_pad2(start.month)} '
        'a ${end.day}/${_pad2(end.month)}$reasonSuffix';
  }
  if (entry.period == null) {
    return 'Indisponível todas as '
        '${_weekdayLabelsPlural[entry.weekday!]}$reasonSuffix';
  }
  return 'Indisponível à ${weekdayLabels[entry.weekday!].toLowerCase()}'
      '${_periodSuffix(entry.period)}$reasonSuffix';
}
