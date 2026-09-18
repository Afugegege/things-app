import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'action_registry.dart';
import '../providers/notes_provider.dart';
import '../providers/tasks_provider.dart';

// ──────────────────────────────────────────────
//  AMBIGUITY RESOLVER
//  Intercepts ActionIntents with validation errors
//  or ambiguous references before preview.
// ──────────────────────────────────────────────

enum SuggestionType { missingField, ambiguousTarget, unknownAction, autoFilled }

class ResolutionSuggestion {
  final int actionIndex;
  final String? fieldKey;
  final SuggestionType type;
  final String message;
  final List<String>? candidates; // for disambiguation
  final dynamic suggestedValue;

  const ResolutionSuggestion({
    required this.actionIndex,
    this.fieldKey,
    required this.type,
    required this.message,
    this.candidates,
    this.suggestedValue,
  });
}

class AmbiguityResolver {
  /// Checks each ActionIntent for issues and returns resolution suggestions.
  static List<ResolutionSuggestion> analyze(
    List<ActionIntent> intents,
    BuildContext context,
  ) {
    final suggestions = <ResolutionSuggestion>[];

    for (int i = 0; i < intents.length; i++) {
      final intent = intents[i];

      // Case 1: Unknown action
      if (intent.definition == null) {
        suggestions.add(ResolutionSuggestion(
          actionIndex: i,
          type: SuggestionType.unknownAction,
          message: 'Unknown action "${intent.action}". This action will be skipped.',
        ));
        continue;
      }

      // Case 2: Missing required fields
      for (final field in intent.definition!.schema) {
        if (field.required) {
          final value = intent.data[field.key];
          if (value == null || (value is String && value.trim().isEmpty)) {
            suggestions.add(ResolutionSuggestion(
              actionIndex: i,
              fieldKey: field.key,
              type: SuggestionType.missingField,
              message: '${field.label} is required but missing.',
            ));
          }
        }
      }

      // Case 3: Ambiguous target resolution for search-based actions
      if (intent.action == 'edit_note' || intent.action == 'delete_note') {
        final searchTitle = (intent.data['search_title'] ?? '').toString().toLowerCase();
        if (searchTitle.isNotEmpty) {
          final notesProvider = Provider.of<NotesProvider>(context, listen: false);
          final matches = notesProvider.notes
              .where((n) => n.title.toLowerCase().contains(searchTitle))
              .toList();

          if (matches.isEmpty) {
            suggestions.add(ResolutionSuggestion(
              actionIndex: i,
              fieldKey: 'search_title',
              type: SuggestionType.ambiguousTarget,
              message: 'No notes found matching "$searchTitle".',
              candidates: notesProvider.notes.take(5).map((n) => n.title).toList(),
            ));
          } else if (matches.length > 1) {
            suggestions.add(ResolutionSuggestion(
              actionIndex: i,
              fieldKey: 'search_title',
              type: SuggestionType.ambiguousTarget,
              message: 'Multiple notes match "$searchTitle". Please select one.',
              candidates: matches.map((n) => n.title).toList(),
            ));
          }
        }
      }

      if (intent.action == 'delete_task') {
        final searchTitle = (intent.data['search_title'] ?? '').toString().toLowerCase();
        if (searchTitle.isNotEmpty) {
          final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
          final matches = tasksProvider.tasks
              .where((t) => t.title.toLowerCase().contains(searchTitle))
              .toList();

          if (matches.isEmpty) {
            suggestions.add(ResolutionSuggestion(
              actionIndex: i,
              fieldKey: 'search_title',
              type: SuggestionType.ambiguousTarget,
              message: 'No tasks found matching "$searchTitle".',
              candidates: tasksProvider.tasks.take(5).map((t) => t.title).toList(),
            ));
          } else if (matches.length > 1) {
            suggestions.add(ResolutionSuggestion(
              actionIndex: i,
              fieldKey: 'search_title',
              type: SuggestionType.ambiguousTarget,
              message: 'Multiple tasks match "$searchTitle". Please select one.',
              candidates: matches.map((t) => t.title).toList(),
            ));
          }
        }
      }

      // Case 4: Auto-filled defaults
      for (final field in intent.definition!.schema) {
        if (!field.required && field.defaultValue != null) {
          final originalValue = intent.data[field.key];
          if (originalValue == null) {
            suggestions.add(ResolutionSuggestion(
              actionIndex: i,
              fieldKey: field.key,
              type: SuggestionType.autoFilled,
              message: '"${field.label}" was not specified, defaulting to "${field.defaultValue}".',
              suggestedValue: field.defaultValue,
            ));
          }
        }
      }
    }

    return suggestions;
  }
}
