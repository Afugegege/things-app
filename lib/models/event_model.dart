import 'package:flutter/material.dart';

enum EventType { work, personal, birthday, holiday, oneOff }

class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final DateTime endTime;
  final bool isAllDay;
  final bool isDayCounter; // [NEW] Flag for Dashboard Counters
  final EventType type;
  final Color color; 

  Event({
    required this.id,
    required this.title,
    this.description = '',
    this.location = '',
    required this.date,
    required this.endTime,
    this.isAllDay = false,
    this.isDayCounter = false,
    this.type = EventType.personal,
    this.color = Colors.blueAccent, 
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'location': location,
    'date': date.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'isAllDay': isAllDay,
    'isDayCounter': isDayCounter,
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
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime']) 
          : DateTime.parse(json['date']).add(const Duration(hours: 1)),
      isAllDay: json['isAllDay'] ?? false,
      isDayCounter: json['isDayCounter'] ?? false,
      type: EventType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => EventType.personal,
      ),
      color: json['color'] != null ? Color(json['color']) : Colors.blueAccent,
    );
  }

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);
    return eventDate.difference(today).inDays;
  }
}