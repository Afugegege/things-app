import 'package:flutter/material.dart';

enum EventType { work, personal, birthday, holiday, oneOff }

class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final DateTime endTime;
  final EventType type;
  final Color color; // Non-nullable to prevent crash

  Event({
    required this.id,
    required this.title,
    this.description = '',
    this.location = '',
    required this.date,
    required this.endTime,
    this.type = EventType.personal,
    this.color = Colors.blueAccent, // Default color if none provided
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'location': location,
    'date': date.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'type': type.toString().split('.').last,
    'color': color.value, 
  };

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      date: DateTime.parse(json['date']),
      // Safety: If endTime is missing, default to 1 hour after start
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime']) 
          : DateTime.parse(json['date']).add(const Duration(hours: 1)),
      type: EventType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => EventType.personal,
      ),
      // Safety: If color is missing, default to Blue
      color: json['color'] != null ? Color(json['color']) : Colors.blueAccent,
    );
  }

  // Helper: Days Left
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);
    return eventDate.difference(today).inDays;
  }
}