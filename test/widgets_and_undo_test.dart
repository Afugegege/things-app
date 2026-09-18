import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Things/services/storage_service.dart';
import 'package:Things/providers/notes_provider.dart';
import 'package:Things/providers/money_provider.dart';
import 'package:Things/providers/tasks_provider.dart';
import 'package:Things/providers/events_provider.dart';
import 'package:Things/providers/user_provider.dart';
import 'package:Things/models/note_model.dart';
import 'package:Things/models/task_model.dart';
import 'package:Things/models/event_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('Widget Toggle & Persistence on Dashboard', () {
    test('NotesProvider toggles and persists widgets for All folder', () {
      final provider = NotesProvider();
      final initial = provider.getWidgetsForFolder('All');
      expect(initial.contains('EXPENSES_CHART_WIDGET'), isFalse);

      // Toggle Add
      provider.toggleFolderWidget('All', 'EXPENSES_CHART_WIDGET');
      expect(provider.getWidgetsForFolder('All').contains('EXPENSES_CHART_WIDGET'), isTrue);

      // Toggle Remove
      provider.toggleFolderWidget('All', 'EXPENSES_CHART_WIDGET');
      expect(provider.getWidgetsForFolder('All').contains('EXPENSES_CHART_WIDGET'), isFalse);
    });

    test('NotesProvider restoreNote restores a deleted note', () {
      final provider = NotesProvider();
      final note = Note(
        id: 'test_note_1',
        title: 'Meeting Notes',
        content: 'Antigravity plan',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.addNote(note);
      expect(provider.notes.any((n) => n.id == 'test_note_1'), isTrue);

      provider.deleteNotes('test_note_1');
      expect(provider.notes.any((n) => n.id == 'test_note_1'), isFalse);

      provider.restoreNote(note);
      expect(provider.notes.any((n) => n.id == 'test_note_1'), isTrue);
      expect(provider.notes.firstWhere((n) => n.id == 'test_note_1').title, 'Meeting Notes');
    });
  });

  group('Expense & App-Wide Undo Restoration', () {
    test('MoneyProvider restoreTransaction restores deleted expense at correct position', () {
      final provider = MoneyProvider();
      provider.addTransaction('Lunch', -15.5, 'Food');
      final tx = provider.transactions.first;
      final txId = tx['id'];

      provider.removeTransactionById(txId);
      expect(provider.transactions.any((t) => t['id'] == txId), isFalse);

      provider.restoreTransaction(tx);
      expect(provider.transactions.any((t) => t['id'] == txId), isTrue);
      expect(provider.transactions.firstWhere((t) => t['id'] == txId)['title'], 'Lunch');
    });

    test('MoneyProvider restoreTransactions restores batch deleted expenses', () {
      final provider = MoneyProvider();
      provider.addTransaction('Coffee', -4.5, 'Food');
      provider.addTransaction('Bus', -2.5, 'Transport');

      final tx1 = provider.transactions[0];
      final tx2 = provider.transactions[1];

      provider.removeTransactions([tx1['id'], tx2['id']]);
      expect(provider.transactions.any((t) => t['id'] == tx1['id']), isFalse);
      expect(provider.transactions.any((t) => t['id'] == tx2['id']), isFalse);

      provider.restoreTransactions([tx1, tx2]);
      expect(provider.transactions.any((t) => t['id'] == tx1['id']), isTrue);
      expect(provider.transactions.any((t) => t['id'] == tx2['id']), isTrue);
    });

    test('TasksProvider restoreTask restores deleted task', () {
      final provider = TasksProvider();
      final task = Task(
        id: 'task_1',
        title: 'Review PR',
        isDone: false,
        createdAt: DateTime.now(),
      );

      provider.addTask(task);
      expect(provider.tasks.any((t) => t.id == 'task_1'), isTrue);

      provider.deleteTask('task_1');
      expect(provider.tasks.any((t) => t.id == 'task_1'), isFalse);

      provider.restoreTask(task);
      expect(provider.tasks.any((t) => t.id == 'task_1'), isTrue);
    });

    test('EventsProvider restoreEvent restores deleted event', () {
      final provider = EventsProvider();
      final event = Event(
        id: 'event_1',
        title: 'Flight to Tokyo',
        date: DateTime.now().add(const Duration(days: 30)),
        endTime: DateTime.now().add(const Duration(days: 30, hours: 10)),
      );

      provider.addEvent(event);
      expect(provider.events.any((e) => e.id == 'event_1'), isTrue);

      provider.removeEvent('event_1');
      expect(provider.events.any((e) => e.id == 'event_1'), isFalse);

      provider.restoreEvent(event);
      expect(provider.events.any((e) => e.id == 'event_1'), isTrue);
    });
  });

  group('Grid / List View Mode Following', () {
    test('UserProvider defaults isGrid to true and persists changes', () {
      final userProv = UserProvider();
      userProv.loadUser();
      expect(userProv.isGrid, isTrue);

      userProv.setGrid(false);
      expect(userProv.isGrid, isFalse);

      // Verify persisted in new provider instance
      final userProv2 = UserProvider();
      userProv2.loadUser();
      expect(userProv2.isGrid, isFalse);

      userProv2.setGrid(true);
      expect(userProv2.isGrid, isTrue);
    });
  });
}

