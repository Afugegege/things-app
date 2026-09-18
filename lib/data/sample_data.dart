import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';


/// Sample data class to populate the app with demo content
class SampleData {
  static const _uuid = Uuid();

  // ============== NOTES ==============
  static List<Note> getSampleNotes() {
    return [
      Note(
        id: _uuid.v4(),
        title: 'Welcome to Things',
        content: '[{"insert":"Welcome to your new digital workspace!\\n\\nHere is what you can do:\\n\\n• Create rich text notes\\n• Manage tasks & projects\\n• Track expenses\\n• Plan events\\n\\nTip: Try typing / to see the magic menu!\\n"}]',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        updatedAt: DateTime.now(),
        folder: 'General',
        isPinned: true,
        widgetType: 'standard',
        backgroundColor: 0xFF1E1E1E,
      ),
      Note(
        id: _uuid.v4(),
        title: 'Morning Checklist',
        content: '[{"insert":"Wake up at 7:00 AM\\nDrink a glass of water\\nStretch / Yoga (15 mins)\\nRead 10 pages of a book\\nPlan the day ahead\\n"}]',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now(),
        folder: 'Personal',
        widgetType: 'checklist',
      ),
      Note(
        id: _uuid.v4(),
        title: 'Project Phoenix',
        content: '[{"insert":"Q3 Goals:\\n\\n1. Launch MVP by August\\n2. Fix critical bugs in authentication\\n3. Hire 2 new frontend devs\\n4. Improve unit test coverage to 80%\\n"}]',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now(),
        folder: 'Work',
      ),
    ];
  }

  // ============== TASKS ==============
  static List<Task> getSampleTasks() {
    return [
      Task(
        id: _uuid.v4(),
        title: 'Review project proposal',
        isDone: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        priority: 3, // High
        note: 'Due by end of week',
        isPinned: true,
      ),
      Task(
        id: _uuid.v4(),
        title: 'Call dentist for appointment',
        isDone: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        priority: 2, // Medium
      ),
      Task(
        id: _uuid.v4(),
        title: 'Buy groceries',
        isDone: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        priority: 2,
        note: 'Milk, eggs, bread, fruits',
      ),
      Task(
        id: _uuid.v4(),
        title: 'Finish reading book chapter',
        isDone: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        priority: 1, // Low
      ),
      Task(
        id: _uuid.v4(),
        title: 'Send birthday card to Mom',
        isDone: false,
        createdAt: DateTime.now(),
        priority: 3,
      ),
      Task(
        id: _uuid.v4(),
        title: 'Update resume',
        isDone: false,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        priority: 2,
      ),
      Task(
        id: _uuid.v4(),
        title: 'Clean apartment',
        isDone: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        priority: 2,
      ),
      Task(
        id: _uuid.v4(),
        title: 'Pay electricity bill',
        isDone: true,
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        priority: 3,
      ),
      Task(
        id: _uuid.v4(),
        title: 'Schedule car maintenance',
        isDone: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        priority: 1,
      ),
      Task(
        id: _uuid.v4(),
        title: 'Learn 10 new Japanese words',
        isDone: false,
        createdAt: DateTime.now(),
        priority: 1,
        note: 'Use flashcard deck',
      ),
    ];
  }

  // ============== EVENTS ==============
  static List<Event> getSampleEvents() {
    return [
      Event(
        id: _uuid.v4(),
        title: "Team Meeting",
        date: DateTime.now().add(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
        isAllDay: false,
        type: EventType.event,
        color: Colors.black,
      ),
      Event(
        id: _uuid.v4(),
        title: "Mom's Birthday",
        date: DateTime.now().add(const Duration(days: 4)),
        endTime: DateTime.now().add(const Duration(days: 4)),
        isAllDay: true,
        type: EventType.birthday,
        color: Colors.white,
      ),
      Event(
        id: _uuid.v4(),
        title: "Japan Trip",
        date: DateTime.now().add(const Duration(days: 120)),
        endTime: DateTime.now().add(const Duration(days: 127)),
        isAllDay: true,
        isDayCounter: true,
        type: EventType.event,
        color: Colors.grey.shade800,
      ),
      Event(
        id: _uuid.v4(),
        title: "Dentist Appointment",
        date: DateTime.now().add(const Duration(days: 7)),
        endTime: DateTime.now().add(const Duration(days: 7, hours: 1)),
        isAllDay: false,
        type: EventType.task,
        color: Colors.grey.shade600,
      ),
      Event(
        id: _uuid.v4(),
        title: "Project Deadline",
        date: DateTime.now().add(const Duration(days: 14)),
        endTime: DateTime.now().add(const Duration(days: 14)),
        isAllDay: true,
        isDayCounter: true,
        type: EventType.task,
        color: Colors.black,
      ),
      Event(
        id: _uuid.v4(),
        title: "Gym Session",
        date: DateTime.now().add(const Duration(days: 2)),
        endTime: DateTime.now().add(const Duration(days: 2, hours: 1)),
        isAllDay: false,
        type: EventType.event,
        color: Colors.white,
      ),
      Event(
        id: _uuid.v4(),
        title: "Wedding Anniversary",
        date: DateTime.now().add(const Duration(days: 45)),
        endTime: DateTime.now().add(const Duration(days: 45)),
        isAllDay: true,
        isDayCounter: true,
        type: EventType.birthday,
        color: Colors.grey.shade400,
      ),
    ];
  }



  // ============== TRANSACTIONS (WALLET) ==============  
  static const _japanGroupId = 'sample-group-japan';
  static const _workGroupId = 'sample-group-work';

  static List<Map<String, dynamic>> getSampleTransactions() {
    final now = DateTime.now();
    return [
      // --- USD Transactions ---
      {
        'id': _uuid.v4(),
        'title': 'Monthly Salary',
        'amount': 5000.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 5)).toString(),
        'category': 'Income',
      },
      {
        'id': _uuid.v4(),
        'title': 'Grocery Shopping',
        'amount': -85.50,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 1)).toString(),
        'category': 'Food',
      },
      {
        'id': _uuid.v4(),
        'title': 'Coffee & Snacks',
        'amount': -12.99,
        'currency': 'USD',
        'date': now.toString(),
        'category': 'Food',
      },
      {
        'id': _uuid.v4(),
        'title': 'Uber Ride',
        'amount': -25.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 2)).toString(),
        'category': 'Transport',
      },
      {
        'id': _uuid.v4(),
        'title': 'Netflix Subscription',
        'amount': -15.99,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 10)).toString(),
        'category': 'Entertainment',
      },
      {
        'id': _uuid.v4(),
        'title': 'New Shoes',
        'amount': -120.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 3)).toString(),
        'category': 'Shopping',
      },
      {
        'id': _uuid.v4(),
        'title': 'Freelance Project',
        'amount': 800.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 7)).toString(),
        'category': 'Income',
      },
      {
        'id': _uuid.v4(),
        'title': 'Restaurant Dinner',
        'amount': -65.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 4)).toString(),
        'category': 'Food',
      },
      {
        'id': _uuid.v4(),
        'title': 'Gas Station',
        'amount': -45.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 6)).toString(),
        'category': 'Transport',
      },
      {
        'id': _uuid.v4(),
        'title': 'Gym Membership',
        'amount': -50.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 15)).toString(),
        'category': 'Health',
      },
      {
        'id': _uuid.v4(),
        'title': 'Movie Tickets',
        'amount': -28.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 8)).toString(),
        'category': 'Entertainment',
      },
      {
        'id': _uuid.v4(),
        'title': 'Amazon Purchase',
        'amount': -89.99,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 12)).toString(),
        'category': 'Shopping',
      },
      {
        'id': _uuid.v4(),
        'title': 'Client Dinner',
        'amount': -120.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 9)).toString(),
        'category': 'Food',
        'groupId': _workGroupId,
        'excludeFromExpenses': true,
      },
      {
        'id': _uuid.v4(),
        'title': 'Conference Ticket',
        'amount': -350.00,
        'currency': 'USD',
        'date': now.subtract(const Duration(days: 11)).toString(),
        'category': 'Other',
        'groupId': _workGroupId,
        'excludeFromExpenses': true,
      },

      // --- EUR Transactions ---
      {
        'id': _uuid.v4(),
        'title': 'Client Retainer',
        'amount': 3200.00,
        'currency': 'EUR',
        'date': now.subtract(const Duration(days: 4)).toString(),
        'category': 'Income',
      },
      {
        'id': _uuid.v4(),
        'title': 'Paris Bistro Dinner',
        'amount': -78.50,
        'currency': 'EUR',
        'date': now.subtract(const Duration(days: 1)).toString(),
        'category': 'Food',
      },
      {
        'id': _uuid.v4(),
        'title': 'TGV High-Speed Train',
        'amount': -115.00,
        'currency': 'EUR',
        'date': now.subtract(const Duration(days: 3)).toString(),
        'category': 'Transport',
      },
      {
        'id': _uuid.v4(),
        'title': 'Louvre Museum Tickets',
        'amount': -34.00,
        'currency': 'EUR',
        'date': now.subtract(const Duration(days: 5)).toString(),
        'category': 'Entertainment',
      },

      // --- MYR Transactions ---
      {
        'id': _uuid.v4(),
        'title': 'Monthly Salary',
        'amount': 8500.00,
        'currency': 'MYR',
        'date': now.subtract(const Duration(days: 6)).toString(),
        'category': 'Income',
      },
      {
        'id': _uuid.v4(),
        'title': 'Village Park Nasi Lemak',
        'amount': -32.50,
        'currency': 'MYR',
        'date': now.subtract(const Duration(days: 1)).toString(),
        'category': 'Food',
      },
      {
        'id': _uuid.v4(),
        'title': 'Grab Ride to Bangsar',
        'amount': -18.00,
        'currency': 'MYR',
        'date': now.subtract(const Duration(days: 2)).toString(),
        'category': 'Transport',
      },
      {
        'id': _uuid.v4(),
        'title': 'Shopee Gadget Purchase',
        'amount': -149.00,
        'currency': 'MYR',
        'date': now.subtract(const Duration(days: 4)).toString(),
        'category': 'Shopping',
      },

      // --- JPY Transactions ---
      {
        'id': _uuid.v4(),
        'title': 'Consulting Honorarium',
        'amount': 280000.00,
        'currency': 'JPY',
        'date': now.subtract(const Duration(days: 7)).toString(),
        'category': 'Income',
      },
      {
        'id': _uuid.v4(),
        'title': 'Tokyo Hotel (3 nights)',
        'amount': -45000.00,
        'currency': 'JPY',
        'date': now.subtract(const Duration(days: 20)).toString(),
        'category': 'Other',
        'groupId': _japanGroupId,
      },
      {
        'id': _uuid.v4(),
        'title': 'Japan Rail Pass',
        'amount': -29650.00,
        'currency': 'JPY',
        'date': now.subtract(const Duration(days: 19)).toString(),
        'category': 'Transport',
        'groupId': _japanGroupId,
      },
      {
        'id': _uuid.v4(),
        'title': 'Sushi Omakase Ginza',
        'amount': -14500.00,
        'currency': 'JPY',
        'date': now.subtract(const Duration(days: 18)).toString(),
        'category': 'Food',
        'groupId': _japanGroupId,
      },

      // --- GBP Transactions ---
      {
        'id': _uuid.v4(),
        'title': 'Tech Consulting Fee',
        'amount': 2400.00,
        'currency': 'GBP',
        'date': now.subtract(const Duration(days: 5)).toString(),
        'category': 'Income',
      },
      {
        'id': _uuid.v4(),
        'title': 'London Underground Weekly',
        'amount': -42.50,
        'currency': 'GBP',
        'date': now.subtract(const Duration(days: 2)).toString(),
        'category': 'Transport',
      },
      {
        'id': _uuid.v4(),
        'title': 'Borough Market Groceries',
        'amount': -58.20,
        'currency': 'GBP',
        'date': now.subtract(const Duration(days: 3)).toString(),
        'category': 'Food',
      },
    ];
  }



  // ============== MONEY SETTINGS ==============
  static Map<String, dynamic> getSampleMoneySettings() {
    return {
      'totalSavings': 2500.00,
      'isSavingsVisible': true,
      'budgets': {
        'Food': 400.0,
        'Transport': 200.0,
        'Entertainment': 150.0,
        'Shopping': 300.0,
        'Health': 100.0,
      },
      'goals': [
        {
          'id': _uuid.v4(),
          'title': 'Emergency Fund',
          'targetAmount': 10000.0,
          'currentAmount': 3500.0,
          'deadline': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
        },
        {
          'id': _uuid.v4(),
          'title': 'Vacation Fund',
          'targetAmount': 3000.0,
          'currentAmount': 1200.0,
          'deadline': DateTime.now().add(const Duration(days: 180)).toIso8601String(),
        },
      ],
      'accounts': [
        {'id': '1', 'name': 'Main Bank', 'type': 'Bank', 'balance': 4500.0},
        {'id': '2', 'name': 'E-Wallet', 'type': 'Wallet', 'balance': 250.0},
        {'id': '3', 'name': 'Cash', 'type': 'Cash', 'balance': 180.0},
        {'id': '4', 'name': 'Investment', 'type': 'Invest', 'balance': 2000.0},
      ],
      'groups': [
        {
          'id': _japanGroupId,
          'name': 'Japan Trip',
          'icon': 'airplane',
          'createdAt': DateTime.now().subtract(const Duration(days: 25)).toIso8601String(),
        },
        {
          'id': _workGroupId,
          'name': 'Work Conference',
          'icon': 'briefcase',
          'createdAt': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        },
      ],
    };
  }
}
