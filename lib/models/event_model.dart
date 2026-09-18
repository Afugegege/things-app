import 'package:flutter/material.dart';

enum EventType { event, task, birthday, work, personal, holiday, oneOff }

class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final DateTime endTime;
  final bool isAllDay;
  final bool isDayCounter; // [NEW] Flag for Dashboard Counters
  final bool isPinned;
  final EventType type;
  final Color color; 
  final String? linkedNoteId;

  Event({
    required this.id,
    required this.title,
    this.description = '',
    this.location = '',
    required this.date,
    required this.endTime,
    this.isAllDay = false,
    this.isDayCounter = false,
    this.isPinned = false,
    this.type = EventType.event,
    this.color = Colors.grey, 
    this.linkedNoteId,
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
    'isPinned': isPinned,
    'type': type.toString().split('.').last,
    'color': color.value, 
    'linkedNoteId': linkedNoteId,
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
      isPinned: json['isPinned'] ?? false,
      type: EventType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => EventType.event,
      ),
      color: json['color'] != null ? Color(json['color']) : Colors.grey,
      linkedNoteId: json['linkedNoteId'],
    );
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? date,
    DateTime? endTime,
    bool? isAllDay,
    bool? isDayCounter,
    bool? isPinned,
    EventType? type,
    Color? color,
    String? linkedNoteId,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      date: date ?? this.date,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      isDayCounter: isDayCounter ?? this.isDayCounter,
      isPinned: isPinned ?? this.isPinned,
      type: type ?? this.type,
      color: color ?? this.color,
      linkedNoteId: linkedNoteId ?? this.linkedNoteId,
    );
  }

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);
    return eventDate.difference(today).inDays;
  }
}