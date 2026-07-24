import 'birthday_person.dart';
import 'event.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.isAdmin,
    required this.upcomingEvents,
    required this.pendingConfirmations,
    required this.birthdaysThisMonth,
  });

  final bool isAdmin;
  final List<Event> upcomingEvents;
  final int pendingConfirmations;
  final List<BirthdayPerson> birthdaysThisMonth;
}
