import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Things/services/storage_service.dart';
import 'package:Things/providers/notes_provider.dart';
import 'package:Things/models/note_model.dart';
import 'package:Things/widgets/smart_widgets/note_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('ChecklistWidget Checkbox Targeting Tests', () {
    testWidgets(
        'Tapping item below (item 1) in Quill delta toggles item 1 and does NOT toggle item 0',
        (WidgetTester tester) async {
      final notesProvider = NotesProvider();

      // Create a Quill Delta note with 3 checklist items
      final quillDelta = jsonEncode([
        {'insert': 'Item 0'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'}
        },
        {'insert': 'Item 1'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'}
        },
        {'insert': 'Item 2'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'}
        },
      ]);

      final note = Note(
        id: 'note_test_checklist',
        title: 'Groceries',
        content: quillDelta,
        widgetType: 'checklist',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      notesProvider.addNote(note);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NotesProvider>.value(
              value: notesProvider,
              child: Consumer<NotesProvider>(
                builder: (context, provider, _) {
                  final currentNote = provider.notes.firstWhere(
                    (n) => n.id == 'note_test_checklist',
                  );
                  return ChecklistWidget(note: currentNote);
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 3 items are rendered
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      // Tap Item 1 (the checkbox below Item 0)
      await tester.tap(find.text('Item 1'));
      await tester.pumpAndSettle();

      // Check updated note content in provider
      final updatedNote =
          notesProvider.notes.firstWhere((n) => n.id == 'note_test_checklist');
      final List<dynamic> updatedOps = jsonDecode(updatedNote.content);

      // Verify Item 0 is STILL unchecked
      expect(updatedOps[1]['attributes']['list'], 'unchecked',
          reason: 'Item 0 should remain unchecked');

      // Verify Item 1 IS checked
      expect(updatedOps[3]['attributes']['list'], 'checked',
          reason: 'Item 1 should be checked');

      // Verify Item 2 is STILL unchecked
      expect(updatedOps[5]['attributes']['list'], 'unchecked',
          reason: 'Item 2 should remain unchecked');

      // Now tap Item 2 (the checkbox below Item 1)
      await tester.tap(find.text('Item 2'));
      await tester.pumpAndSettle();

      final updatedNote2 =
          notesProvider.notes.firstWhere((n) => n.id == 'note_test_checklist');
      final List<dynamic> updatedOps2 = jsonDecode(updatedNote2.content);

      // Verify Item 0 is still unchecked
      expect(updatedOps2[1]['attributes']['list'], 'unchecked');
      // Verify Item 1 is STILL checked (not toggled by clicking Item 2)
      expect(updatedOps2[3]['attributes']['list'], 'checked');
      // Verify Item 2 IS checked
      expect(updatedOps2[5]['attributes']['list'], 'checked');
    });

    testWidgets(
        'Tapping item 1 in Markdown checklist toggles item 1 without affecting item 0 or 2',
        (WidgetTester tester) async {
      final notesProvider = NotesProvider();

      const markdownContent =
          '- [ ] Buy Apples\n- [ ] Buy Bananas\n- [ ] Buy Cherries';

      final note = Note(
        id: 'note_test_markdown',
        title: 'Fruits',
        content: markdownContent,
        widgetType: 'checklist',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      notesProvider.addNote(note);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NotesProvider>.value(
              value: notesProvider,
              child: Consumer<NotesProvider>(
                builder: (context, provider, _) {
                  final currentNote = provider.notes.firstWhere(
                    (n) => n.id == 'note_test_markdown',
                  );
                  return ChecklistWidget(note: currentNote);
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Buy Apples'), findsOneWidget);
      expect(find.text('Buy Bananas'), findsOneWidget);
      expect(find.text('Buy Cherries'), findsOneWidget);

      // Click "Buy Bananas" (Item 1)
      await tester.tap(find.text('Buy Bananas'));
      await tester.pumpAndSettle();

      final updatedNote =
          notesProvider.notes.firstWhere((n) => n.id == 'note_test_markdown');
      final lines = updatedNote.content.split('\n');

      expect(lines[0], '- [ ] Buy Apples',
          reason: 'Buy Apples should not be toggled');
      expect(lines[1], '- [x] Buy Bananas',
          reason: 'Buy Bananas should be toggled to checked');
      expect(lines[2], '- [ ] Buy Cherries',
          reason: 'Buy Cherries should not be toggled');
    });

    testWidgets(
        'Tapping item in single-op multi-line markdown Quill delta toggles accurately',
        (WidgetTester tester) async {
      final notesProvider = NotesProvider();

      final quillDelta = jsonEncode([
        {'insert': '- [ ] Task Alpha\n- [ ] Task Beta\n- [ ] Task Gamma\n'}
      ]);

      final note = Note(
        id: 'note_test_multiline_op',
        title: 'Tasks',
        content: quillDelta,
        widgetType: 'checklist',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      notesProvider.addNote(note);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NotesProvider>.value(
              value: notesProvider,
              child: Consumer<NotesProvider>(
                builder: (context, provider, _) {
                  final currentNote = provider.notes.firstWhere(
                    (n) => n.id == 'note_test_multiline_op',
                  );
                  return ChecklistWidget(note: currentNote);
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Task Alpha'), findsOneWidget);
      expect(find.text('Task Beta'), findsOneWidget);
      expect(find.text('Task Gamma'), findsOneWidget);

      // Tap Task Beta (Item 1)
      await tester.tap(find.text('Task Beta'));
      await tester.pumpAndSettle();

      final updatedNote = notesProvider.notes
          .firstWhere((n) => n.id == 'note_test_multiline_op');
      final List<dynamic> updatedOps = jsonDecode(updatedNote.content);
      final insertText = updatedOps[0]['insert'] as String;

      expect(insertText, contains('- [ ] Task Alpha'));
      expect(insertText, contains('- [x] Task Beta'));
      expect(insertText, contains('- [ ] Task Gamma'));
    });
  });
}
