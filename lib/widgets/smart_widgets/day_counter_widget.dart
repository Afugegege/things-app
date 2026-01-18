import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../glass_container.dart';

class DayCounterWidget extends StatelessWidget {
  final Event event;

  const DayCounterWidget({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final days = event.daysLeft;
    final bool isToday = days == 0;
    final bool isPast = days < 0;

    String daysText = days.abs().toString();
    String labelText = "DAYS LEFT";
    
    if (isToday) {
      daysText = "TODAY";
      labelText = "HAPPENING NOW";
    } else if (isPast) {
      labelText = "DAYS AGO";
    }

    return GlassContainer(
      height: 160, 
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    event.color.withOpacity(0.2),
                    event.color.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(isToday ? CupertinoIcons.sparkles : CupertinoIcons.calendar, color: event.color, size: 20),
                    if (event.isAllDay)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                        child: Text(DateFormat('MMM d').format(event.date).toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),

                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(daysText, style: TextStyle(color: event.color, fontSize: isToday ? 32 : 48, fontWeight: FontWeight.w300, height: 1.0)),
                        const SizedBox(height: 5),
                        Text(labelText, style: TextStyle(color: event.color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                      ],
                    ),
                  ),
                ),

                Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}