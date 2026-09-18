import 'package:intl/intl.dart';

class DateHelper {
  /// Parses an ISO string, relative date keyword, or formatted date string into a [DateTime].
  /// Returns null if unable to parse.
  static DateTime? parseFlexibleDate(dynamic input, {DateTime? referenceDate}) {
    if (input == null) return null;
    if (input is DateTime) return input;

    final str = input.toString().trim();
    if (str.isEmpty) return null;

    final ref = referenceDate ?? DateTime.now();
    final lower = str.toLowerCase();

    // 1. Direct keywords
    if (lower == 'today' || lower == 'now') {
      return DateTime(ref.year, ref.month, ref.day, ref.hour, ref.minute);
    }
    if (lower == 'yesterday' || lower == 'last night') {
      final y = ref.subtract(const Duration(days: 1));
      return DateTime(y.year, y.month, y.day, 12, 0);
    }
    if (lower == 'tomorrow') {
      final t = ref.add(const Duration(days: 1));
      return DateTime(t.year, t.month, t.day, 12, 0);
    }
    if (lower == 'day before yesterday') {
      final d = ref.subtract(const Duration(days: 2));
      return DateTime(d.year, d.month, d.day, 12, 0);
    }

    // 2. "X days ago"
    final daysAgoMatch = RegExp(r'^(\d+)\s+days?\s+ago$').firstMatch(lower);
    if (daysAgoMatch != null) {
      final days = int.parse(daysAgoMatch.group(1)!);
      final d = ref.subtract(Duration(days: days));
      return DateTime(d.year, d.month, d.day, 12, 0);
    }

    // 3. "last [weekday]"
    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (lower == 'last ${entry.key}' || lower == entry.key) {
        int targetWeekday = entry.value;
        int diff = ref.weekday - targetWeekday;
        if (diff <= 0) diff += 7;
        final d = ref.subtract(Duration(days: diff));
        return DateTime(d.year, d.month, d.day, 12, 0);
      }
    }

    // 4. Standard ISO 8601 parsing
    final isoParsed = DateTime.tryParse(str);
    if (isoParsed != null) return isoParsed;

    // 5. Formats like YYYY/MM/DD, DD/MM/YYYY, MM/DD/YYYY, YYYY-MM-DD
    final formats = [
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'dd-MM-yyyy',
      'MM-dd-yyyy',
      'yyyy-MM-dd HH:mm',
      'yyyy/MM/dd HH:mm',
      'dd/MM/yyyy HH:mm',
      'MMMM d, yyyy',
      'MMM d, yyyy',
      'd MMMM yyyy',
      'd MMM yyyy',
      'MMMM d',
      'MMM d',
      'd MMMM',
      'd MMM',
    ];

    for (final fmt in formats) {
      try {
        final d = DateFormat(fmt).parseLoose(str);
        // If year was omitted, default to reference year
        if (!fmt.contains('y')) {
          return DateTime(ref.year, d.month, d.day, d.hour, d.minute);
        }
        return d;
      } catch (_) {}
    }

    return null;
  }

  /// Scans freeform text (like a user prompt) to extract any mentioned date.
  /// Example: "I spent 50 on food yesterday" -> yesterday's date
  static DateTime? extractDateFromText(String text, {DateTime? referenceDate}) {
    if (text.trim().isEmpty) return null;
    final ref = referenceDate ?? DateTime.now();
    final lower = text.toLowerCase();

    // Check keywords in text
    if (RegExp(r'\byesterday\b|\blast night\b').hasMatch(lower)) {
      final y = ref.subtract(const Duration(days: 1));
      return DateTime(y.year, y.month, y.day, 12, 0);
    }
    if (RegExp(r'\btoday\b').hasMatch(lower)) {
      return DateTime(ref.year, ref.month, ref.day, ref.hour, ref.minute);
    }
    if (RegExp(r'\btomorrow\b').hasMatch(lower)) {
      final t = ref.add(const Duration(days: 1));
      return DateTime(t.year, t.month, t.day, 12, 0);
    }
    if (RegExp(r'\bday before yesterday\b').hasMatch(lower)) {
      final d = ref.subtract(const Duration(days: 2));
      return DateTime(d.year, d.month, d.day, 12, 0);
    }

    // "X days ago"
    final daysAgo = RegExp(r'\b(\d+)\s+days?\s+ago\b').firstMatch(lower);
    if (daysAgo != null) {
      final days = int.parse(daysAgo.group(1)!);
      final d = ref.subtract(Duration(days: days));
      return DateTime(d.year, d.month, d.day, 12, 0);
    }

    // "last [weekday]" or "on [weekday]"
    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (RegExp('\\b(last|on)\\s+${entry.key}\\b').hasMatch(lower)) {
        int targetWeekday = entry.value;
        int diff = ref.weekday - targetWeekday;
        if (diff <= 0) diff += 7;
        final d = ref.subtract(Duration(days: diff));
        return DateTime(d.year, d.month, d.day, 12, 0);
      }
    }

    // Explicit date patterns: YYYY-MM-DD or YYYY/MM/DD
    final isoMatch = RegExp(r'\b(\d{4}[-/]\d{1,2}[-/]\d{1,2})\b').firstMatch(text);
    if (isoMatch != null) {
      final parsed = parseFlexibleDate(isoMatch.group(1), referenceDate: ref);
      if (parsed != null) return parsed;
    }

    // DD/MM/YYYY or MM/DD/YYYY
    final slashMatch = RegExp(r'\b(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})\b').firstMatch(text);
    if (slashMatch != null) {
      final parsed = parseFlexibleDate(slashMatch.group(1), referenceDate: ref);
      if (parsed != null) return parsed;
    }

    // "on 12th March", "March 5th", "on 5 March"
    final monthNameMatch = RegExp(
      r'\b(on\s+)?((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}(?:st|nd|rd|th)?(?:\s*,?\s*\d{4})?|\d{1,2}(?:st|nd|rd|th)?\s+(?:of\s+)?(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*(?:\s*,?\s*\d{4})?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (monthNameMatch != null) {
      String cleanMatch = monthNameMatch.group(2)!
          .replaceAll(RegExp(r'(st|nd|rd|th|of)'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final parsed = parseFlexibleDate(cleanMatch, referenceDate: ref);
      if (parsed != null) return parsed;
    }

    return null;
  }

  /// Returns a user-friendly relative or formatted date string.
  /// e.g. "Today", "Yesterday", "Tomorrow", "Mar 11, 2026"
  static String formatFriendlyDate(DateTime date, {bool includeTime = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    String dateStr;
    if (diff == 0) {
      dateStr = 'Today';
    } else if (diff == -1) {
      dateStr = 'Yesterday';
    } else if (diff == 1) {
      dateStr = 'Tomorrow';
    } else if (date.year == now.year) {
      dateStr = DateFormat('MMM d').format(date);
    } else {
      dateStr = DateFormat('MMM d, yyyy').format(date);
    }

    if (includeTime && (date.hour != 0 || date.minute != 0)) {
      final timeStr = DateFormat('h:mm a').format(date);
      return '$dateStr at $timeStr';
    }
    return dateStr;
  }
}
