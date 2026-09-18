import 'package:flutter_test/flutter_test.dart';
import '../lib/core/action_registry.dart';
import '../lib/core/action_definitions.dart';
import '../lib/core/ai_response_parser.dart';
import '../lib/providers/money_provider.dart';
import '../lib/services/storage_service.dart';
import '../lib/providers/events_provider.dart';
import '../lib/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    registerAllActions();
  });

  group('Action Registry & Aliases', () {
    test('edit_transaction and aliases are properly registered', () {
      expect(ActionRegistry.get('edit_transaction'), isNotNull);
      expect(ActionRegistry.get('edit_expense'), isNotNull);
      expect(ActionRegistry.get('update_transaction'), isNotNull);
      expect(ActionRegistry.get('update_expense'), isNotNull);
      expect(ActionRegistry.get('delete_transaction'), isNotNull);
      expect(ActionRegistry.get('delete_expense'), isNotNull);
      expect(ActionRegistry.get('remove_transaction'), isNotNull);
      expect(ActionRegistry.get('remove_expense'), isNotNull);
    });

    test('delete_note and aliases are registered', () {
      expect(ActionRegistry.get('delete_note'), isNotNull);
      expect(ActionRegistry.get('remove_note'), isNotNull);
      expect(ActionRegistry.get('delete_notes'), isNotNull);
      expect(ActionRegistry.get('archive_note'), isNotNull);
    });

    test('ActionDefinition.normalize handles title as search_title fallback', () {
      final def = ActionRegistry.get('delete_note')!;
      final normalized = def.normalize({'action': 'delete_note', 'title': 'Grocery List'});
      expect(normalized['search_title'], 'Grocery List');
    });
  });

  group('MoneyProvider Batch & Multi-Select', () {
    test('batchUpdateDatesYear updates 2023 transactions to 2026', () {
      final provider = MoneyProvider();
      // Add transactions with 2023 dates
      provider.addTransaction(
        'Old Coffee',
        -4.50,
        'Food',
        date: DateTime(2023, 5, 12, 10, 30),
      );
      provider.addTransaction(
        'Old Shoes',
        -80.00,
        'Shopping',
        date: DateTime(2023, 8, 20, 14, 0),
      );
      provider.addTransaction(
        'Recent Lunch',
        -15.00,
        'Food',
        date: DateTime(2026, 9, 10, 12, 0),
      );

      final updated = provider.batchUpdateDatesYear(2023, 2026);
      expect(updated, 2);

      final oldCoffee = provider.allTransactions.firstWhere((t) => t['title'] == 'Old Coffee');
      expect(DateTime.parse(oldCoffee['date']).year, 2026);
      expect(DateTime.parse(oldCoffee['date']).month, 5);

      final oldShoes = provider.allTransactions.firstWhere((t) => t['title'] == 'Old Shoes');
      expect(DateTime.parse(oldShoes['date']).year, 2026);
      expect(DateTime.parse(oldShoes['date']).month, 8);
    });

    test('removeTransactions batch deletes specified transaction IDs', () {
      final provider = MoneyProvider();
      provider.addTransaction('Item 1', -10.0, 'General');
      provider.addTransaction('Item 2', -20.0, 'General');
      provider.addTransaction('Item 3', -30.0, 'General');

      final id1 = provider.allTransactions.firstWhere((t) => t['title'] == 'Item 1')['id'].toString();
      final id2 = provider.allTransactions.firstWhere((t) => t['title'] == 'Item 2')['id'].toString();

      provider.removeTransactions([id1, id2]);
      expect(provider.allTransactions.any((t) => t['id'] == id1), isFalse);
      expect(provider.allTransactions.any((t) => t['id'] == id2), isFalse);
      expect(provider.allTransactions.any((t) => t['title'] == 'Item 3'), isTrue);
    });

    test('batchUpdateCategory updates category for selected transactions', () {
      final provider = MoneyProvider();
      provider.addTransaction('Tx 1', -10.0, 'Other');
      provider.addTransaction('Tx 2', -20.0, 'Other');

      final id1 = provider.allTransactions[0]['id'].toString();
      final id2 = provider.allTransactions[1]['id'].toString();

      provider.batchUpdateCategory([id1, id2], 'Food');
      expect(provider.allTransactions.firstWhere((t) => t['id'] == id1)['category'], 'Food');
      expect(provider.allTransactions.firstWhere((t) => t['id'] == id2)['category'], 'Food');
    });

    test('todaySpendingAmount accurately sums only today expenses and skips past, future, and income', () {
      final provider = MoneyProvider();
      final initialToday = provider.todaySpendingAmount;
      final initialTotal = provider.totalSpendingAmount;
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final tomorrow = now.add(const Duration(days: 1));

      // Today's expenses
      provider.addTransaction('Coffee Today', -4.50, 'Food', date: now);
      provider.addTransaction('Lunch Today', -15.50, 'Food', date: now);

      // Yesterday's expense
      provider.addTransaction('Dinner Yesterday', -30.00, 'Food', date: yesterday);

      // Future expense
      provider.addTransaction('Concert Tomorrow', -50.00, 'Entertainment', date: tomorrow, isFuture: true);

      // Today's income
      provider.addTransaction('Salary', 500.00, 'Salary', date: now);

      // todaySpendingAmount should only increase by today's expenses (4.50 + 15.50 = 20.00)
      expect(provider.todaySpendingAmount, initialToday + 20.00);
      // totalSpendingAmount includes yesterday's 30.00 too (20.00 + 30.00 = 50.00)
      expect(provider.totalSpendingAmount, initialTotal + 50.00);
    });
  });

  group('AI Response Parser Date & Expense Processing', () {
    test('extracts date from user prompt when AI omits date field in add_transaction', () {
      const aiResponse = '''
Sure! I recorded your expense.
```json
[
  {"action": "add_transaction", "title": "Coffee", "amount": 5.50, "category": "Food"}
]
```
''';
      final parsed = AiResponseParser.parse(aiResponse, userPrompt: 'I spent 5.50 on coffee yesterday');
      expect(parsed.actions.length, 1);
      final action = parsed.actions.first;
      expect(action.action, 'add_transaction');
      // Amount should be normalized to negative for expense
      expect((action.data['amount'] as num).toDouble(), -5.50);
      // Date should have been populated from userPrompt "yesterday"
      expect(action.data['date'], isNotNull);
      final parsedDate = DateTime.parse(action.data['date']);
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      expect(parsedDate.day, yesterday.day);
      expect(parsedDate.year, yesterday.year);
    });
  });

  group('Events & Templates Cleanup', () {
    test('EventsProvider starts with clean empty events (no default template events)', () {
      final provider = EventsProvider();
      expect(provider.events, isEmpty);
      expect(provider.dashboardEvents, isEmpty);
    });
  });

  group('UserProvider Accent Colors', () {
    test('default accent color is dynamic monochrome (white in dark, black in light)', () {
      final userProv = UserProvider();
      expect(userProv.isMonoAccent, isTrue);
      userProv.toggleTheme(false);
      expect(userProv.accentColor, Colors.black);
      userProv.toggleTheme(true);
      expect(userProv.accentColor, Colors.white);
    });

    test('setting colorful accent overrides monochrome mode and persists', () {
      final userProv = UserProvider();
      const blue = Color(0xFF3B82F6);
      userProv.updateAccentColor(blue, isMono: false);
      expect(userProv.isMonoAccent, isFalse);
      expect(userProv.accentColor.value, blue.value);

      // Switching back to mono works
      userProv.updateAccentColor(Colors.transparent, isMono: true);
      expect(userProv.isMonoAccent, isTrue);
    });
  });
}
