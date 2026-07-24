class BirthdayPerson {
  const BirthdayPerson({
    required this.name,
    this.avatarUrl,
    required this.day,
    required this.month,
  });

  final String name;
  final String? avatarUrl;
  final int day;
  final int month;
}
