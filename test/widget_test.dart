import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wis/shared/domain/event.dart';

void main() {
  group('EventDayPeriod.fromTimeOfDay', () {
    test('05:00–11:59 is morning', () {
      expect(
        EventDayPeriod.fromTimeOfDay(const TimeOfDay(hour: 5, minute: 0)),
        EventDayPeriod.morning,
      );
      expect(
        EventDayPeriod.fromTimeOfDay(const TimeOfDay(hour: 11, minute: 59)),
        EventDayPeriod.morning,
      );
    });

    test('12:00–17:59 is afternoon', () {
      expect(
        EventDayPeriod.fromTimeOfDay(const TimeOfDay(hour: 12, minute: 0)),
        EventDayPeriod.afternoon,
      );
      expect(
        EventDayPeriod.fromTimeOfDay(const TimeOfDay(hour: 17, minute: 59)),
        EventDayPeriod.afternoon,
      );
    });

    test('18:00–04:59 is night', () {
      expect(
        EventDayPeriod.fromTimeOfDay(const TimeOfDay(hour: 18, minute: 0)),
        EventDayPeriod.night,
      );
      expect(
        EventDayPeriod.fromTimeOfDay(const TimeOfDay(hour: 4, minute: 59)),
        EventDayPeriod.night,
      );
      expect(
        EventDayPeriod.fromTimeOfDay(const TimeOfDay(hour: 0, minute: 0)),
        EventDayPeriod.night,
      );
    });
  });
}
