import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'action_registry.dart';
import '../models/note_model.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';
import '../models/currency_model.dart';
import '../providers/notes_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/money_provider.dart';
import '../providers/events_provider.dart';
import '../providers/user_provider.dart';
import '../utils/markdown_to_quill.dart';
import '../utils/date_formatter.dart';

// ──────────────────────────────────────────────
//  REGISTER ALL BUILT-IN ACTIONS
// ──────────────────────────────────────────────

void registerAllActions() {
  ActionRegistry.register('create_note', createNoteDefinition);
  ActionRegistry.register('save_note', createNoteDefinition); // alias
  ActionRegistry.register('add_note', createNoteDefinition); // alias
  ActionRegistry.register('new_note', createNoteDefinition); // alias
  ActionRegistry.register('edit_note', editNoteDefinition);
  ActionRegistry.register('update_note', editNoteDefinition); // alias
  ActionRegistry.register('modify_note', editNoteDefinition); // alias
  ActionRegistry.register('delete_note', deleteNoteDefinition);
  ActionRegistry.register('remove_note', deleteNoteDefinition); // alias
  ActionRegistry.register('delete_notes', deleteNoteDefinition); // alias
  ActionRegistry.register('archive_note', deleteNoteDefinition); // alias
  ActionRegistry.register('remove_notes', deleteNoteDefinition); // alias

  ActionRegistry.register('create_task', createTaskDefinition);
  ActionRegistry.register('add_task', createTaskDefinition); // alias
  ActionRegistry.register('new_task', createTaskDefinition); // alias
  ActionRegistry.register('edit_task', editTaskDefinition);
  ActionRegistry.register('update_task', editTaskDefinition); // alias
  ActionRegistry.register('modify_task', editTaskDefinition); // alias
  ActionRegistry.register('delete_task', deleteTaskDefinition);
  ActionRegistry.register('remove_task', deleteTaskDefinition); // alias
  ActionRegistry.register('delete_tasks', deleteTaskDefinition); // alias

  ActionRegistry.register('add_transaction', addTransactionDefinition);
  ActionRegistry.register('add_expense', addTransactionDefinition); // alias
  ActionRegistry.register('record_expense', addTransactionDefinition); // alias
  ActionRegistry.register('create_expense', addTransactionDefinition); // alias
  ActionRegistry.register('log_expense', addTransactionDefinition); // alias
  ActionRegistry.register('edit_transaction', editTransactionDefinition);
  ActionRegistry.register('edit_expense', editTransactionDefinition); // alias
  ActionRegistry.register('update_transaction', editTransactionDefinition); // alias
  ActionRegistry.register('update_expense', editTransactionDefinition); // alias
  ActionRegistry.register('modify_expense', editTransactionDefinition); // alias
  ActionRegistry.register('modify_transaction', editTransactionDefinition); // alias
  ActionRegistry.register('change_transaction', editTransactionDefinition); // alias
  ActionRegistry.register('delete_transaction', deleteTransactionDefinition);
  ActionRegistry.register('delete_expense', deleteTransactionDefinition); // alias
  ActionRegistry.register('remove_transaction', deleteTransactionDefinition); // alias
  ActionRegistry.register('remove_expense', deleteTransactionDefinition); // alias

  ActionRegistry.register('create_event', createEventDefinition);
  ActionRegistry.register('add_event', createEventDefinition); // alias
  ActionRegistry.register('new_event', createEventDefinition); // alias
  ActionRegistry.register('edit_event', editEventDefinition);
  ActionRegistry.register('update_event', editEventDefinition); // alias
  ActionRegistry.register('modify_event', editEventDefinition); // alias
  ActionRegistry.register('delete_event', deleteEventDefinition);
  ActionRegistry.register('remove_event', deleteEventDefinition); // alias
  ActionRegistry.register('delete_events', deleteEventDefinition); // alias

  ActionRegistry.register('remember', rememberDefinition);
  ActionRegistry.register('update_note_style', updateNoteStyleDefinition);
  ActionRegistry.register('manage_folder', manageFolderDefinition);
  ActionRegistry.register('update_user_settings', updateUserSettingsDefinition);
}

// ──────────────────────────────────────────────
//  CREATE NOTE
// ──────────────────────────────────────────────

final createNoteDefinition = ActionDefinition(
  name: 'create_note',
  displayName: 'Create Note',
  icon: CupertinoIcons.doc_text,
  schema: [
    const ActionFieldSchema(key: 'title', label: 'Title', type: FieldType.text, required: true, maxLength: 200),
    const ActionFieldSchema(key: 'folder', label: 'Folder', type: FieldType.text, required: false, defaultValue: 'General'),
    const ActionFieldSchema(key: 'content', label: 'Content', type: FieldType.longText, required: false, defaultValue: ''),
  ],
  execute: (data, context) async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final id = const Uuid().v4();

    // Handle nested content structure from AI
    String rawContent = '';
    String title = data['title'] ?? 'Untitled';
    if (data['content'] is Map) {
      rawContent = data['content']['body'] ?? '';
      if (data['content']['title'] != null) title = data['content']['title'];
    } else {
      rawContent = data['content'] ?? '';
    }

    final delta = markdownToQuill(rawContent).toDelta();
    final String structuredContent = jsonEncode(delta.toJson());

    final folderName = data['folder'] ?? 'General';
    provider.addFolder(folderName);

    provider.addNote(Note(
      id: id,
      title: title,
      content: structuredContent,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: folderName,
    ));

    return ActionResult.success(id: id, summary: 'Created note "$title"');
  },
);

// ──────────────────────────────────────────────
//  CREATE TASK
// ──────────────────────────────────────────────

final createTaskDefinition = ActionDefinition(
  name: 'create_task',
  displayName: 'Create Task',
  icon: CupertinoIcons.checkmark_circle,
  schema: [
    const ActionFieldSchema(key: 'title', label: 'Task Title', type: FieldType.text, required: true, maxLength: 200),
    const ActionFieldSchema(
      key: 'priority', label: 'Priority', type: FieldType.dropdown, required: false, defaultValue: 1,
      options: ['1 - Low', '2 - Medium', '3 - High'],
    ),
    const ActionFieldSchema(key: 'note', label: 'Note', type: FieldType.longText, required: false),
  ],
  execute: (data, context) async {
    final provider = Provider.of<TasksProvider>(context, listen: false);
    final id = const Uuid().v4();

    int priority = 1;
    final rawPriority = data['priority'];
    if (rawPriority is int) {
      priority = rawPriority.clamp(1, 3);
    } else if (rawPriority is String) {
      priority = int.tryParse(rawPriority.split(' ').first) ?? 1;
    }

    provider.addTask(Task(
      id: id,
      title: data['title'] ?? 'New Task',
      isDone: false,
      createdAt: DateTime.now(),
      priority: priority,
      note: data['note'],
    ));

    return ActionResult.success(id: id, summary: 'Created task "${data['title']}"');
  },
);

// ──────────────────────────────────────────────
//  ADD TRANSACTION
// ──────────────────────────────────────────────

final addTransactionDefinition = ActionDefinition(
  name: 'add_transaction',
  displayName: 'Add Transaction',
  icon: CupertinoIcons.money_dollar,
  schema: [
    const ActionFieldSchema(key: 'title', label: 'Description', type: FieldType.text, required: true, maxLength: 200),
    const ActionFieldSchema(key: 'amount', label: 'Amount', type: FieldType.number, required: true),
    const ActionFieldSchema(key: 'currency', label: 'Currency Code (e.g. USD, EUR, MYR)', type: FieldType.text, required: false),
    const ActionFieldSchema(
      key: 'category', label: 'Category', type: FieldType.dropdown, required: false, defaultValue: 'General',
      options: ['Food', 'Transport', 'Shopping', 'Entertainment', 'Health', 'Other', 'General'],
    ),
    const ActionFieldSchema(key: 'date', label: 'Date', type: FieldType.date, required: false),
  ],
  execute: (data, context) async {
    final provider = Provider.of<MoneyProvider>(context, listen: false);
    double amount = double.tryParse(data['amount'].toString()) ?? 0.0;
    String category = data['category'] ?? 'General';
    final currency = data['currency']?.toString().toUpperCase() ?? provider.currentCurrency;

    DateTime? customDate;
    if (data['date'] != null) {
      customDate = DateHelper.parseFlexibleDate(data['date']);
    }

    provider.addTransaction(
      data['title'] ?? 'Transaction',
      amount,
      category,
      date: customDate,
      currency: currency,
    );

    final symbol = AppCurrency.getSymbol(currency);
    return ActionResult.success(summary: 'Added transaction "${data['title']}" ($symbol${amount.abs().toStringAsFixed(2)})');
  },
);

// ──────────────────────────────────────────────
//  EDIT / UPDATE TRANSACTION
// ──────────────────────────────────────────────

final editTransactionDefinition = ActionDefinition(
  name: 'edit_transaction',
  displayName: 'Edit Transaction',
  icon: CupertinoIcons.pencil_circle,
  schema: [
    const ActionFieldSchema(key: 'search_title', label: 'Transaction to Edit (or "all")', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'title', label: 'New Title', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'amount', label: 'New Amount', type: FieldType.number, required: false),
    const ActionFieldSchema(
      key: 'category', label: 'New Category', type: FieldType.dropdown, required: false,
      options: ['Food', 'Transport', 'Shopping', 'Entertainment', 'Health', 'Other', 'General', 'Income'],
    ),
    const ActionFieldSchema(key: 'date', label: 'New Date', type: FieldType.date, required: false),
    const ActionFieldSchema(key: 'currency', label: 'Currency Code', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'target_year', label: 'Old Year (for bulk year update, e.g. 2023)', type: FieldType.number, required: false),
    const ActionFieldSchema(key: 'new_year', label: 'New Year (e.g. 2026)', type: FieldType.number, required: false),
  ],
  execute: (data, context) async {
    final provider = Provider.of<MoneyProvider>(context, listen: false);

    // 1. Bulk Year Migration (e.g. user says: change 2023 transactions to 2026)
    final rawTargetYear = data['target_year'] ?? data['old_year'];
    final targetYear = int.tryParse(rawTargetYear?.toString() ?? '');
    final newYear = int.tryParse(data['new_year']?.toString() ?? '') ?? DateTime.now().year;

    if (targetYear != null) {
      final count = provider.batchUpdateDatesYear(targetYear, newYear);
      return ActionResult.success(summary: 'Updated $count transactions from year $targetYear to $newYear');
    }

    final query = (data['search_title'] ?? data['title'] ?? data['id'] ?? '').toString().trim().toLowerCase();

    // Check if user requested "all" or "all 2023" or similar
    if (query == 'all' || query.contains('all 2023') || query.contains('all expenses') || query.contains('2023')) {
      final count = provider.batchUpdateDatesYear(2023, newYear);
      if (count > 0) {
        return ActionResult.success(summary: 'Updated $count transactions to year $newYear');
      }
    }

    // 2. Individual transaction lookup
    final all = provider.allTransactions;
    Map<String, dynamic>? match;
    for (final t in all) {
      final tId = t['id']?.toString().toLowerCase() ?? '';
      final tTitle = t['title']?.toString().toLowerCase() ?? '';
      if (tId == query || tTitle == query || tTitle.contains(query) || (query.isNotEmpty && query.contains(tTitle))) {
        match = t;
        break;
      }
    }

    if (match == null) {
      return ActionResult.error('Could not find a transaction matching "$query"');
    }

    final id = match['id'].toString();
    final newTitle = data['title']?.toString() ?? match['title'].toString();
    final newAmount = data['amount'] != null
        ? (double.tryParse(data['amount'].toString()) ?? (match['amount'] as double))
        : (match['amount'] as double);
    final newCat = data['category']?.toString() ?? match['category']?.toString() ?? 'General';
    final newCur = data['currency']?.toString().toUpperCase() ?? match['currency']?.toString();

    DateTime? newDate;
    if (data['date'] != null) {
      newDate = DateHelper.parseFlexibleDate(data['date']);
    }

    provider.editTransaction(
      id,
      newTitle,
      newAmount,
      newCat,
      date: newDate,
      currency: newCur,
    );

    return ActionResult.success(id: id, summary: 'Updated transaction "$newTitle"');
  },
);

// ──────────────────────────────────────────────
//  DELETE TRANSACTION
// ──────────────────────────────────────────────

final deleteTransactionDefinition = ActionDefinition(
  name: 'delete_transaction',
  displayName: 'Delete Transaction',
  icon: CupertinoIcons.trash,
  schema: [
    const ActionFieldSchema(key: 'search_title', label: 'Transaction to Delete', type: FieldType.text, required: true),
  ],
  execute: (data, context) async {
    final provider = Provider.of<MoneyProvider>(context, listen: false);
    final search = (data['search_title'] ?? data['title'] ?? data['id'] ?? '').toString().trim().toLowerCase();

    final all = provider.allTransactions;
    Map<String, dynamic>? match;
    for (final t in all) {
      final tId = t['id']?.toString().toLowerCase() ?? '';
      final tTitle = t['title']?.toString().toLowerCase() ?? '';
      if (tId == search || tTitle == search || tTitle.contains(search) || (search.isNotEmpty && search.contains(tTitle))) {
        match = t;
        break;
      }
    }

    if (match == null) {
      return ActionResult.error('Could not find transaction matching "$search"');
    }

    final id = match['id'].toString();
    final title = match['title'].toString();
    provider.removeTransactionById(id);
    return ActionResult.success(id: id, summary: 'Deleted transaction "$title"');
  },
);

// ──────────────────────────────────────────────
//  CREATE EVENT
// ──────────────────────────────────────────────

final createEventDefinition = ActionDefinition(
  name: 'create_event',
  displayName: 'Create Event',
  icon: CupertinoIcons.calendar,
  schema: [
    const ActionFieldSchema(key: 'title', label: 'Event Title', type: FieldType.text, required: true, maxLength: 200),
    const ActionFieldSchema(key: 'date', label: 'Date', type: FieldType.date, required: true),
    const ActionFieldSchema(key: 'description', label: 'Description', type: FieldType.longText, required: false, defaultValue: ''),
    const ActionFieldSchema(key: 'location', label: 'Location', type: FieldType.text, required: false, defaultValue: ''),
    const ActionFieldSchema(key: 'isAllDay', label: 'All Day', type: FieldType.boolean, required: false, defaultValue: true),
  ],
  execute: (data, context) async {
    final provider = Provider.of<EventsProvider>(context, listen: false);
    final id = const Uuid().v4();

    DateTime eventDate = DateTime.now();
    if (data['date'] != null) {
      eventDate = DateHelper.parseFlexibleDate(data['date']) ?? DateTime.now();
    }

    provider.addEvent(Event(
      id: id,
      title: data['title'] ?? 'New Event',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      date: eventDate,
      endTime: eventDate.add(const Duration(hours: 1)),
      isAllDay: data['isAllDay'] ?? true,
      type: EventType.event,
      color: Colors.grey,
    ));

    return ActionResult.success(id: id, summary: 'Created event "${data['title']}"');
  },
);

// ──────────────────────────────────────────────
//  EDIT NOTE
// ──────────────────────────────────────────────

final editNoteDefinition = ActionDefinition(
  name: 'edit_note',
  displayName: 'Edit Note',
  icon: CupertinoIcons.pencil,
  schema: [
    const ActionFieldSchema(key: 'search_title', label: 'Note to Edit', type: FieldType.text, required: true),
    const ActionFieldSchema(key: 'append_content', label: 'Content to Append', type: FieldType.longText, required: false),
    const ActionFieldSchema(key: 'new_title', label: 'New Title', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'content', label: 'New Content (overwrites)', type: FieldType.longText, required: false),
    const ActionFieldSchema(key: 'overwrite', label: 'Overwrite Entire Note', type: FieldType.boolean, required: false, defaultValue: false),
  ],
  execute: (data, context) async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final searchTitle = (data['search_title'] ?? '').toString().toLowerCase();

    final match = provider.notes.cast<Note?>().firstWhere(
      (n) => n!.title.toLowerCase().contains(searchTitle),
      orElse: () => null,
    );

    if (match == null) {
      return ActionResult.error('Could not find a note matching "$searchTitle"');
    }

    Note updated = match;

    // Update title if provided
    if (data['new_title'] != null && data['new_title'].toString().trim().isNotEmpty) {
      updated = updated.copyWith(title: data['new_title'].toString().trim());
    }

    final bool shouldOverwrite = data['overwrite'] == true || data['replace_all'] == true;

    // ── CASE 1: append_content — always appends to existing note ──
    final String? appendContent = data['append_content']?.toString();
    if (appendContent != null && appendContent.trim().isNotEmpty) {
      String existingText = match.plainTextContent.trimRight();
      String addition = appendContent.trim();

      // If note is a checklist, ensure addition items are formatted as checklist items
      bool isChecklistNote = match.widgetType == 'checklist' ||
          existingText.contains('- [ ]') ||
          existingText.contains('- [x]') ||
          existingText.contains('[ ]') ||
          existingText.contains('[x]');

      if (isChecklistNote &&
          !addition.startsWith('- [') &&
          !addition.startsWith('- ') &&
          !addition.startsWith('* ') &&
          !addition.startsWith('• ')) {
        addition = addition.split('\n').map((line) {
          final l = line.trim();
          if (l.isEmpty) return l;
          if (l.startsWith('- [') || l.startsWith('- ') || l.startsWith('* ') ||
              l.startsWith('• ') || l.startsWith('[ ]') || l.startsWith('[x]')) {
            return l;
          }
          return '- [ ] $l';
        }).join('\n');
      }

      // Normalise both sides (strip markdown list prefixes) for duplicate detection
      String stripListPrefix(String s) => s
          .replaceAll(RegExp(r'^[-*•]\s+\[[ x]\]\s*', multiLine: true, caseSensitive: false), '')
          .replaceAll(RegExp(r'^[-*•]\s+', multiLine: true), '')
          .replaceAll(RegExp(r'^\[[ x]\]\s*', multiLine: true, caseSensitive: false), '')
          .trim();

      final normExisting = stripListPrefix(existingText);
      final normAddition = stripListPrefix(addition);

      // Only append if the content is not already present
      String mergedText;
      if (existingText.isEmpty) {
        mergedText = addition;
      } else if (normExisting.contains(normAddition) || existingText.contains(addition)) {
        // Already present — don't duplicate
        mergedText = existingText;
      } else {
        mergedText = '$existingText\n$addition';
      }

      final mergedDelta = markdownToQuill(mergedText).toDelta();
      updated = updated.copyWith(content: jsonEncode(mergedDelta.toJson()), updatedAt: DateTime.now());
    }
    // ── CASE 2: content field OR explicit overwrite — always replaces ──
    else if (data['content'] != null && data['content'].toString().trim().isNotEmpty) {
      final newContent = data['content'].toString().trim();
      if (shouldOverwrite || true) {
        // 'content' field always means replace/overwrite the full note body
        final newDelta = markdownToQuill(newContent).toDelta();
        updated = updated.copyWith(content: jsonEncode(newDelta.toJson()), updatedAt: DateTime.now());
      }
    }

    provider.updateNote(updated);

    return ActionResult.success(id: match.id, summary: 'Updated note "${match.title}"');
  },
);


// ──────────────────────────────────────────────
//  DELETE TASK
// ──────────────────────────────────────────────

final deleteTaskDefinition = ActionDefinition(
  name: 'delete_task',
  displayName: 'Delete Task',
  icon: CupertinoIcons.trash,
  schema: [
    const ActionFieldSchema(key: 'search_title', label: 'Task to Delete', type: FieldType.text, required: true),
  ],
  execute: (data, context) async {
    final provider = Provider.of<TasksProvider>(context, listen: false);
    final search = (data['search_title'] ?? data['title'] ?? data['name'] ?? data['id'] ?? '').toString().trim().toLowerCase();

    final match = provider.tasks.cast<Task?>().firstWhere(
      (t) => t != null && (
        t.id.toLowerCase() == search ||
        t.title.toLowerCase() == search ||
        t.title.toLowerCase().contains(search) ||
        (search.isNotEmpty && search.contains(t.title.toLowerCase()))
      ),
      orElse: () => null,
    );

    if (match == null) {
      return ActionResult.error('Could not find a task matching "$search"');
    }

    provider.deleteTask(match.id);
    return ActionResult.success(id: match.id, summary: 'Deleted task "${match.title}"');
  },
);

// ──────────────────────────────────────────────
//  DELETE NOTE
// ──────────────────────────────────────────────

final deleteNoteDefinition = ActionDefinition(
  name: 'delete_note',
  displayName: 'Delete Note',
  icon: CupertinoIcons.trash,
  schema: [
    const ActionFieldSchema(key: 'search_title', label: 'Note to Delete', type: FieldType.text, required: true),
  ],
  execute: (data, context) async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final search = (data['search_title'] ?? data['title'] ?? data['name'] ?? data['id'] ?? '').toString().trim().toLowerCase();

    final match = provider.notes.cast<Note?>().firstWhere(
      (n) => n != null && (
        n.id.toLowerCase() == search ||
        n.title.toLowerCase() == search ||
        n.title.toLowerCase().contains(search) ||
        (search.isNotEmpty && search.contains(n.title.toLowerCase()))
      ),
      orElse: () => null,
    );

    if (match == null) {
      return ActionResult.error('Could not find a note matching "$search"');
    }

    provider.deleteNotes(match.id);
    return ActionResult.success(id: match.id, summary: 'Deleted note "${match.title}"');
  },
);

// ──────────────────────────────────────────────
//  REMEMBER (User Memory)
// ──────────────────────────────────────────────

final rememberDefinition = ActionDefinition(
  name: 'remember',
  displayName: 'Remember',
  icon: CupertinoIcons.lightbulb,
  schema: [
    const ActionFieldSchema(key: 'fact', label: 'Fact to Remember', type: FieldType.text, required: true, maxLength: 500),
  ],
  execute: (data, context) async {
    final provider = Provider.of<UserProvider>(context, listen: false);
    final fact = data['fact'] ?? '';
    if (fact.isNotEmpty) {
      provider.addMemory(fact);
    }
    return ActionResult.success(summary: 'Remembered: "$fact"');
  },
);

// ──────────────────────────────────────────────
//  EDIT TASK
// ──────────────────────────────────────────────

final editTaskDefinition = ActionDefinition(
  name: 'edit_task',
  displayName: 'Edit Task',
  icon: CupertinoIcons.pencil,
  schema: [
    const ActionFieldSchema(key: 'search_title', label: 'Task Title to Find', type: FieldType.text, required: true),
    const ActionFieldSchema(key: 'new_title', label: 'New Title', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'priority', label: 'New Priority (1 - Low, 2 - Medium, 3 - High)', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'note', label: 'New Note Content', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'isDone', label: 'Set Completed (true/false)', type: FieldType.boolean, required: false),
  ],
  execute: (data, context) async {
    final provider = Provider.of<TasksProvider>(context, listen: false);
    final searchTitle = (data['search_title'] ?? '').toString().toLowerCase();

    final match = provider.tasks.cast<Task?>().firstWhere(
      (t) => t!.title.toLowerCase().contains(searchTitle),
      orElse: () => null,
    );

    if (match == null) {
      return ActionResult.error('Could not find a task matching "$searchTitle"');
    }

    Task updated = match;

    if (data['new_title'] != null) {
      updated = updated.copyWith(title: data['new_title'].toString());
    }

    if (data['priority'] != null) {
      int priority = 1;
      final rawPriority = data['priority'];
      if (rawPriority is int) {
        priority = rawPriority.clamp(1, 3);
      } else if (rawPriority is String) {
        priority = int.tryParse(rawPriority.split(' ').first) ?? 1;
      }
      updated = updated.copyWith(priority: priority);
    }

    if (data['note'] != null) {
      updated = updated.copyWith(note: data['note'].toString());
    }

    if (data['isDone'] != null) {
      updated = updated.copyWith(isDone: data['isDone'] == true);
    }

    provider.updateTask(updated);

    return ActionResult.success(id: match.id, summary: 'Updated task "${match.title}"');
  },
);

// ──────────────────────────────────────────────
//  EDIT EVENT
// ──────────────────────────────────────────────

final editEventDefinition = ActionDefinition(
  name: 'edit_event',
  displayName: 'Edit Event',
  icon: CupertinoIcons.pencil,
  schema: [
    const ActionFieldSchema(key: 'search_title', label: 'Event Title to Find', type: FieldType.text, required: true),
    const ActionFieldSchema(key: 'new_title', label: 'New Title', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'date', label: 'New Date', type: FieldType.date, required: false),
    const ActionFieldSchema(key: 'description', label: 'New Description', type: FieldType.longText, required: false),
    const ActionFieldSchema(key: 'location', label: 'New Location', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'isAllDay', label: 'All Day (true/false)', type: FieldType.boolean, required: false),
  ],
  execute: (data, context) async {
    final provider = Provider.of<EventsProvider>(context, listen: false);
    final searchTitle = (data['search_title'] ?? '').toString().toLowerCase();

    final match = provider.events.cast<Event?>().firstWhere(
      (e) => e!.title.toLowerCase().contains(searchTitle),
      orElse: () => null,
    );

    if (match == null) {
      return ActionResult.error('Could not find an event matching "$searchTitle"');
    }

    Event updated = match;

    if (data['new_title'] != null) {
      updated = updated.copyWith(title: data['new_title'].toString());
    }

    if (data['date'] != null) {
      final date = DateHelper.parseFlexibleDate(data['date']);
      if (date != null) {
        updated = updated.copyWith(date: date, endTime: date.add(const Duration(hours: 1)));
      }
    }

    if (data['description'] != null) {
      updated = updated.copyWith(description: data['description'].toString());
    }

    if (data['location'] != null) {
      updated = updated.copyWith(location: data['location'].toString());
    }

    if (data['isAllDay'] != null) {
      updated = updated.copyWith(isAllDay: data['isAllDay'] == true);
    }

    provider.editEvent(updated);

    return ActionResult.success(id: match.id, summary: 'Updated event "${match.title}"');
  },
);

// ──────────────────────────────────────────────
//  DELETE EVENT
// ──────────────────────────────────────────────

final deleteEventDefinition = ActionDefinition(
  name: 'delete_event',
  displayName: 'Delete Event',
  icon: CupertinoIcons.trash,
  schema: [
    const ActionFieldSchema(key: 'search_title', label: 'Event to Delete', type: FieldType.text, required: true),
  ],
  execute: (data, context) async {
    final provider = Provider.of<EventsProvider>(context, listen: false);
    final search = (data['search_title'] ?? data['title'] ?? data['name'] ?? data['id'] ?? '').toString().trim().toLowerCase();

    final match = provider.events.cast<Event?>().firstWhere(
      (e) => e != null && (
        e.id.toLowerCase() == search ||
        e.title.toLowerCase() == search ||
        e.title.toLowerCase().contains(search) ||
        (search.isNotEmpty && search.contains(e.title.toLowerCase()))
      ),
      orElse: () => null,
    );

    if (match == null) {
      return ActionResult.error('Could not find an event matching "$search"');
    }

    provider.removeEvent(match.id);
    return ActionResult.success(id: match.id, summary: 'Deleted event "${match.title}"');
  },
);

// ──────────────────────────────────────────────
//  UPDATE NOTE STYLE & DESIGN
// ──────────────────────────────────────────────

final updateNoteStyleDefinition = ActionDefinition(
  name: 'update_note_style',
  displayName: 'Update Note Style',
  icon: CupertinoIcons.paintbrush,
  schema: [
    const ActionFieldSchema(key: 'search_title', label: 'Note Title to find', type: FieldType.text, required: true),
    const ActionFieldSchema(key: 'widgetType', label: 'Widget Type (standard, sticker, monitor, quote, album)', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'backgroundColor', label: 'Hex Color (e.g. #FF5733)', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'stickerEmoji', label: 'Sticker Emoji', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'buttonLabel', label: 'Button Label', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'buttonLink', label: 'Button Link', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'buttonColor', label: 'Button Hex Color', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'folder', label: 'Collection / Folder', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'isPinned', label: 'Pin Note (true/false)', type: FieldType.boolean, required: false),
    const ActionFieldSchema(key: 'isFullWidth', label: 'Full Width (true/false)', type: FieldType.boolean, required: false),
    const ActionFieldSchema(key: 'isExpanded', label: 'Expanded Widget (true/false)', type: FieldType.boolean, required: false),
    const ActionFieldSchema(key: 'fontSize', label: 'Font Size pt (e.g. 14, 17, 20)', type: FieldType.number, required: false),
  ],
  execute: (data, context) async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final searchTitle = (data['search_title'] ?? '').toString().toLowerCase();

    final match = provider.notes.cast<Note?>().firstWhere(
      (n) => n!.title.toLowerCase().contains(searchTitle),
      orElse: () => null,
    );

    if (match == null) {
      return ActionResult.error('Could not find a note matching "$searchTitle"');
    }

    Note updated = match;

    if (data['widgetType'] != null) {
      updated = updated.copyWith(widgetType: data['widgetType'].toString());
    }

    if (data['backgroundColor'] != null) {
      final colorStr = data['backgroundColor'].toString().replaceAll('#', '');
      final colorVal = int.tryParse(colorStr, radix: 16);
      if (colorVal != null) {
        final fullColorVal = colorStr.length == 6 ? 0xFF000000 + colorVal : colorVal;
        updated = updated.copyWith(backgroundColor: fullColorVal);
      }
    }

    if (data['stickerEmoji'] != null) {
      updated = updated.copyWith(stickerEmoji: data['stickerEmoji'].toString());
    }

    if (data['buttonLabel'] != null) {
      updated = updated.copyWith(buttonLabel: data['buttonLabel'].toString());
    }

    if (data['buttonLink'] != null) {
      updated = updated.copyWith(buttonLink: data['buttonLink'].toString());
    }

    if (data['buttonColor'] != null) {
      final colorStr = data['buttonColor'].toString().replaceAll('#', '');
      final colorVal = int.tryParse(colorStr, radix: 16);
      if (colorVal != null) {
        final fullColorVal = colorStr.length == 6 ? 0xFF000000 + colorVal : colorVal;
        updated = updated.copyWith(buttonColor: fullColorVal);
      }
    }

    if (data['folder'] != null) {
      final folderName = data['folder'].toString();
      provider.addFolder(folderName);
      updated = updated.copyWith(folder: folderName);
    }

    if (data['isPinned'] != null) {
      updated = updated.copyWith(isPinned: data['isPinned'] == true);
    }

    if (data['isFullWidth'] != null) {
      updated = updated.copyWith(isFullWidth: data['isFullWidth'] == true);
    }

    if (data['isExpanded'] != null) {
      updated = updated.copyWith(isExpanded: data['isExpanded'] == true);
    }

    if (data['fontSize'] != null) {
      final size = double.tryParse(data['fontSize'].toString());
      if (size != null) {
        updated = updated.copyWith(fontSize: size);
      }
    }

    provider.updateNote(updated);

    return ActionResult.success(id: match.id, summary: 'Updated style & design of note "${match.title}"');
  },
);

// ──────────────────────────────────────────────
//  MANAGE FOLDER / COLLECTION
// ──────────────────────────────────────────────

final manageFolderDefinition = ActionDefinition(
  name: 'manage_folder',
  displayName: 'Manage Folders',
  icon: CupertinoIcons.folder,
  schema: [
    const ActionFieldSchema(key: 'folder', label: 'Folder Name', type: FieldType.text, required: true),
    const ActionFieldSchema(key: 'operation', label: 'Operation (add, delete)', type: FieldType.text, required: true),
  ],
  execute: (data, context) async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final folder = data['folder'].toString();
    final operation = data['operation'].toString().toLowerCase();

    if (operation == 'add') {
      provider.addFolder(folder);
      return ActionResult.success(summary: 'Created folder collection "$folder"');
    } else if (operation == 'delete') {
      provider.deleteFolder(folder);
      return ActionResult.success(summary: 'Deleted folder collection "$folder"');
    }

    return ActionResult.error('Invalid folder operation: "$operation"');
  },
);

// ──────────────────────────────────────────────
//  UPDATE USER SETTINGS
// ──────────────────────────────────────────────

final updateUserSettingsDefinition = ActionDefinition(
  name: 'update_user_settings',
  displayName: 'Update User Settings',
  icon: CupertinoIcons.settings,
  schema: [
    const ActionFieldSchema(key: 'isDarkMode', label: 'Dark Mode (true/false)', type: FieldType.boolean, required: false),
    const ActionFieldSchema(key: 'accentColor', label: 'Accent Hex Color (e.g. #FF5733)', type: FieldType.text, required: false),
    const ActionFieldSchema(key: 'customPersona', label: 'Custom Assistant Persona Prompt', type: FieldType.text, required: false),
  ],
  execute: (data, context) async {
    final provider = Provider.of<UserProvider>(context, listen: false);

    if (data['isDarkMode'] != null) {
      provider.toggleTheme(data['isDarkMode'] == true);
    }

    if (data['accentColor'] != null) {
      final colorStr = data['accentColor'].toString().replaceAll('#', '');
      final colorVal = int.tryParse(colorStr, radix: 16);
      if (colorVal != null) {
        final fullColorVal = colorStr.length == 6 ? 0xFF000000 + colorVal : colorVal;
        provider.updateAccentColor(Color(fullColorVal));
      }
    }

    if (data['customPersona'] != null) {
      provider.updateCustomPersona(data['customPersona'].toString());
    }

    return ActionResult.success(summary: 'Updated user app settings');
  },
);
