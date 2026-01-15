import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../config/theme.dart';

class RoamWidget extends StatelessWidget {
  final Map<String, dynamic> trip;

  const RoamWidget({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final type = trip['type'] ?? 'Activity';
    final distance = (trip['distance_km'] as double).toStringAsFixed(2);
    final pace = trip['pace'] ?? '0:00';
    
    // Calculate display time
    final int seconds = trip['duration_sec'] ?? 0;
    final String timeStr = "${(seconds / 60).floor()}m ${seconds % 60}s";

    final bool isRun = type == 'Workout' || type == 'Run';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRun 
              ? [const Color(0xFFFF416C), const Color(0xFFFF4B2B)] // Red/Orange for workout
              : [const Color(0xFF2193b0), const Color(0xFF6dd5ed)], // Blue for travel
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isRun ? Colors.redAccent : Colors.blueAccent).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Text(type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Icon(CupertinoIcons.map_pin_ellipse, color: Colors.white70, size: 16),
            ],
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$distance km",
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(CupertinoIcons.stopwatch, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(width: 10),
                  const Icon(CupertinoIcons.speedometer, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text("$pace /km", style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}