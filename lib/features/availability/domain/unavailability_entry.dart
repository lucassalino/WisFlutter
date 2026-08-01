/// Espelha a tabela `member_unavailability` — período pontual (data a data)
/// ou recorrente (dia da semana, com período opcional). O `reason` é
/// mascarado no cliente (não é uma fronteira de segurança real, ver
/// [OrgMember] para o mesmo padrão já usado no email) para quem não é o
/// dono da entrada nem admin/líder da organização.
enum UnavailabilityKind {
  dateRange,
  weekly;

  static UnavailabilityKind fromString(String value) => switch (value) {
    'weekly' => UnavailabilityKind.weekly,
    _ => UnavailabilityKind.dateRange,
  };

  String get value => switch (this) {
    UnavailabilityKind.dateRange => 'date_range',
    UnavailabilityKind.weekly => 'weekly',
  };
}

class UnavailabilityEntry {
  const UnavailabilityEntry({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.kind,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.weekday,
    this.period,
    this.reason,
  });

  final String id;
  final String orgId;
  final String userId;
  final UnavailabilityKind kind;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;

  /// 0 = domingo … 6 = sábado (mesma convenção do `Date.getDay()` do JS).
  final int? weekday;

  /// `manha` | `tarde` | `noite` | null (dia todo).
  final String? period;
  final String? reason;

  UnavailabilityEntry withMaskedReason() => UnavailabilityEntry(
    id: id,
    orgId: orgId,
    userId: userId,
    kind: kind,
    createdAt: createdAt,
    startDate: startDate,
    endDate: endDate,
    weekday: weekday,
    period: period,
    reason: null,
  );

  /// Diz se esta entrada cobre [date] — usado para marcar o calendário e
  /// para a secção "indisponibilidade da equipa".
  bool coversDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (kind == UnavailabilityKind.dateRange) {
      if (startDate == null || endDate == null) return false;
      return !day.isBefore(startDate!) && !day.isAfter(endDate!);
    }
    final jsWeekday = day.weekday % 7; // Dart: seg=1..dom=7 → JS: dom=0..sáb=6
    return weekday == jsWeekday;
  }

  factory UnavailabilityEntry.fromMap(Map<String, dynamic> map) =>
      UnavailabilityEntry(
        id: map['id'] as String,
        orgId: map['org_id'] as String,
        userId: map['user_id'] as String,
        kind: UnavailabilityKind.fromString(map['kind'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        startDate: map['start_date'] != null
            ? DateTime.parse(map['start_date'] as String)
            : null,
        endDate: map['end_date'] != null
            ? DateTime.parse(map['end_date'] as String)
            : null,
        weekday: map['weekday'] as int?,
        period: map['period'] as String?,
        reason: map['reason'] as String?,
      );
}
