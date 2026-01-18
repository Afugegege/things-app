import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/event_model.dart';

class EventsProvider extends ChangeNotifier {
  final List<Event> _events = [
    // Sample Data
    Event(
      id: const Uuid().v4(),
      title: "Mom's Birthday",
      date: DateTime.now().add(const Duration(days: 4)),
      endTime: DateTime.now().add(const Duration(days: 4)),
      isAllDay: true,
      type: EventType.birthday,
      color: Colors.purpleAccent,
    ),
    Event(
      id: const Uuid().v4(),
      title: "Japan Trip",
      date: DateTime.now().add(const Duration(days: 120)), // Far future event
      endTime: DateTime.now().add(const Duration(days: 125)),
      isAllDay: true,
      isDayCounter: true, // This should now show up
      type: EventType.personal,
      color: Colors.pinkAccent,
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

  // [FIX] Dashboard Logic
  // 1. Regular Events: Show only if within 60 days (to keep list clean)
  // 2. Day Counters: Show ALL future counters (no date limit)
  List<Event> get dashboardEvents {
    final now = DateTime.now();
    final list = _events.where((e) {
      final isFuture = e.endTime.isAfter(now);
      if (!isFuture) return false;

      if (e.isDayCounter) return true; // Always show Day Counters
      
      // Only show regular events if they are soon (e.g., next 60 days)
      return e.date.isBefore(now.add(const Duration(days: 60)));
    }).toList();
    
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  void addEvent(Event e) {
    _events.add(e);
    notifyListeners();
  }

  void editEvent(Event updatedEvent) {
    final index = _events.indexWhere((e) => e.id == updatedEvent.id);
    if (index != -1) {
      _events[index] = updatedEvent;
      notifyListeners();
    }
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