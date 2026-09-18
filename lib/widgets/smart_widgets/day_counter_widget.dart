import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../models/note_model.dart';

class DayCounterWidget extends StatelessWidget {
  final Event? event;
  final Note? note;
  final String? customTitle;
  final DateTime? customDate;
  final bool? isCountUp;

  const DayCounterWidget({
    super.key,
    this.event,
    this.note,
    this.customTitle,
    this.customDate,
    this.isCountUp,
  });

  @override
  Widget build(BuildContext context) {
    String title = "Day Counter";
    DateTime date = DateTime.now();

    if (event != null) {
      title = event!.title;
      date = event!.date;
    } else if (note != null) {
      title = note!.title.isNotEmpty ? note!.title : "Milestone";
      final parsed = DateTime.tryParse(note!.plainTextContent.trim());
      date = parsed ?? note!.createdAt;
    } else if (customTitle != null && customDate != null) {
      title = customTitle!;
      date = customDate!;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);
    final difference = targetDay.difference(today).inDays;

    final bool isToday = difference == 0;
    final bool isPast = difference < 0;

    String daysText = difference.abs().toString();
    String labelText = "DAYS LEFT";

    if (isToday) {
      daysText = "TODAY";
      labelText = "HAPPENING NOW";
    } else if (isPast) {
      labelText = "DAYS SINCE";
    } else {
      labelText = "DAYS LEFT";
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white60 : Colors.black54);
    final bgColor = isDark ? theme.cardColor : Colors.white;

    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isToday
                              ? CupertinoIcons.sparkles
                              : isPast
                                  ? CupertinoIcons.arrow_clockwise
                                  : CupertinoIcons.hourglass,
                          color: textColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPast ? "STREAK / TRACKER" : "COUNTDOWN",
                          style: TextStyle(
                            color: dimmedColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat('MMM d, yyyy').format(date).toUpperCase(),
                        style: TextStyle(
                          color: dimmedColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          daysText,
                          style: TextStyle(
                            color: textColor,
                            fontSize: isToday ? 30 : 46,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labelText,
                          style: TextStyle(
                            color: dimmedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
