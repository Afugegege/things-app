import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/date_formatter.dart';

void main() {
  final refDate = DateTime(2026, 3, 12, 10, 0); // Thursday, March 12, 2026

  group('DateHelper tests', () {
    test('parses relative keywords', () {
      final today = DateHelper.parseFlexibleDate('today', referenceDate: refDate);
      expect(today?.day, 12);

      final yesterday = DateHelper.parseFlexibleDate('yesterday', referenceDate: refDate);
      expect(yesterday?.day, 11);
      expect(yesterday?.month, 3);

      final tomorrow = DateHelper.parseFlexibleDate('tomorrow', referenceDate: refDate);
      expect(tomorrow?.day, 13);

      final twoDaysAgo = DateHelper.parseFlexibleDate('2 days ago', referenceDate: refDate);
      expect(twoDaysAgo?.day, 10);
    });

    test('parses ISO strings and date formats', () {
      final iso = DateHelper.parseFlexibleDate('2026-03-05T14:30:00Z');
      expect(iso?.year, 2026);
      expect(iso?.month, 3);
      expect(iso?.day, 5);

      final ymd = DateHelper.parseFlexibleDate('2026-03-05');
      expect(ymd?.day, 5);

      final slash = DateHelper.parseFlexibleDate('15/03/2026');
      expect(slash?.day, 15);
      expect(slash?.month, 3);
    });

    test('extracts dates from freeform user prompt', () {
      final ex1 = DateHelper.extractDateFromText('I recorded an expense of \$50 on food yesterday', referenceDate: refDate);
      expect(ex1?.day, 11);

      final ex2 = DateHelper.extractDateFromText('Spent 20 euro on coffee 2 days ago', referenceDate: refDate);
      expect(ex2?.day, 10);

      final ex3 = DateHelper.extractDateFromText('dinner on 2026-03-05', referenceDate: refDate);
      expect(ex3?.day, 5);
      expect(ex3?.month, 3);
    });

    test('formats friendly dates', () {
      final y = DateTime.now().subtract(const Duration(days: 1));
      expect(DateHelper.formatFriendlyDate(y), 'Yesterday');

      final today = DateTime.now();
      expect(DateHelper.formatFriendlyDate(today), 'Today');
    });
  });
}
