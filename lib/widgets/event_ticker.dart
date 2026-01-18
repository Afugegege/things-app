import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/event_model.dart';

class EventTicker extends StatelessWidget {
  final Event event;
  
  const EventTicker({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final days = event.daysLeft;
    final isToday = days <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isToday 
              ? [Colors.redAccent.withOpacity(0.4), Colors.orangeAccent.withOpacity(0.2)]
              : [Colors.blueAccent.withOpacity(0.2), Colors.purpleAccent.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.calendar, 
                color: isToday ? Colors.redAccent : Colors.blueAccent, 
                size: 16
              ),
              const SizedBox(width: 8),
              Text(
                isToday ? "HAPPENING NOW" : "UP NEXT • ${days}d LEFT", 
                style: TextStyle(
                  color: isToday ? Colors.redAccent : Colors.blueAccent, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1.0
                )
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.title,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}