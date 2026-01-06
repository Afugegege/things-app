import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/event_model.dart';

class EventsProvider extends ChangeNotifier {
  final List<Event> _events = [
    Event(
      id: const Uuid().v4(),
      title: "Mom's Birthday",
      description: "Buy flowers and a gift card",
      date: DateTime.now().add(const Duration(days: 4)),
      endTime: DateTime.now().add(const Duration(days: 4, hours: 2)),
      type: EventType.birthday,
      color: Colors.purpleAccent,
    ),
    Event(
      id: const Uuid().v4(),
      title: "Project Deadline",
      description: "Submit final report to management",
      date: DateTime.now().add(const Duration(days: 12)),
      endTime: DateTime.now().add(const Duration(days: 12, hours: 5)),
      type: EventType.work,
      color: Colors.redAccent,
    ),
    Event(
      id: const Uuid().v4(),
      title: "Lunch with Team",
      location: "Burger King",
      date: DateTime.now().add(const Duration(hours: 2)),
      endTime: DateTime.now().add(const Duration(hours: 3)),
      type: EventType.personal,
      color: Colors.orangeAccent,
    ),
  ];

  List<Event> get events {
    _events.sort((a, b) => a.date.compareTo(b.date));
    return _events;
  }

  List<Event> getEventsForDay(DateTime day) {
    return _events.where((event) {
      return isSameDay(event.date, day);
    }).toList();
  }

  // Get next single event for dashboard ticker
  Event? get nextEvent {
    final now = DateTime.now();
    final upcoming = _events.where((e) => e.date.isAfter(now)).toList();
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  // Get upcoming events list
  List<Event> get upcomingEvents {
    final now = DateTime.now();
    return _events.where((e) => 
      e.date.isAfter(now) && e.date.isBefore(now.add(const Duration(days: 30)))
    ).toList();
  }

  void addEvent(Event e) {
    _events.add(e);
    notifyListeners();
  }

  void removeEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}