import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'action_registry.dart';
import '../utils/json_cleaner.dart';
import '../utils/date_formatter.dart';

// ──────────────────────────────────────────────
//  PARSE ISSUE
// ──────────────────────────────────────────────

enum ParseIssueType { malformedJson, unknownAction, validationError, missingField }

class ParseIssue {
  final ParseIssueType type;
  final String message;
  final int? actionIndex;

  const ParseIssue({required this.type, required this.message, this.actionIndex});
}

// ──────────────────────────────────────────────
//  PARSED AI RESPONSE
// ──────────────────────────────────────────────

class ParsedAiResponse {
  final String displayText;
  final List<ActionIntent> actions;
  final List<String> suggestions;
  final List<ParseIssue> issues;

  const ParsedAiResponse({
    required this.displayText,
    required this.actions,
    this.suggestions = const [],
    this.issues = const [],
  });
}

// ──────────────────────────────────────────────
//  AI RESPONSE PARSER
// ──────────────────────────────────────────────

class AiResponseParser {
  /// Main entry point: takes raw AI text, returns structured result.
  static ParsedAiResponse parse(String rawResponse, {String? userPrompt}) {
    String displayContent = rawResponse;
    List<ActionIntent> actions = [];
    List<String> suggestions = [];
    List<ParseIssue> issues = [];

    // ── 1. Extract ```suggestions block ──
    final suggestionMatch = RegExp(r'```suggestions\s*([\s\S]*?)\s*```').firstMatch(displayContent);
    if (suggestionMatch != null) {
      try {
        final parsed = jsonDecode(JsonCleaner.clean(suggestionMatch.group(1)!));
        if (parsed is List) {
          suggestions = parsed.map((e) => e.toString()).toList();
        }
      } catch (e) {
        debugPrint('Suggestions parse error: $e');
      }
      displayContent = displayContent.replaceFirst(suggestionMatch.group(0)!, '').trim();
    }

    // ── 2. Extract ```json block ──
    final codeBlockMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(displayContent);
    if (codeBlockMatch != null) {
      final jsonStr = codeBlockMatch.group(1)!;
      final parseResult = _parseJsonActions(jsonStr, issues, userPrompt: userPrompt);
      actions = parseResult;
      displayContent = displayContent.replaceFirst(codeBlockMatch.group(0)!, '').trim();
    } else {
      // ── 3. Fallback: scan for raw {...} with "action" key ──
      final rawMatch = RegExp(r'(\{[\s\S]*?"action"[\s\S]*?\})').firstMatch(displayContent);
      if (rawMatch != null) {
        try {
          final jsonStr = rawMatch.group(1)!;
          final parseResult = _parseJsonActions(jsonStr, issues, userPrompt: userPrompt);
          if (parseResult.isNotEmpty) {
            actions = parseResult;
            displayContent = displayContent.replaceFirst(rawMatch.group(0)!, '').trim();
          }
        } catch (_) {
          // Not valid JSON — leave displayContent as is
        }
      }
    }

    return ParsedAiResponse(
      displayText: displayContent,
      actions: actions,
      suggestions: suggestions,
      issues: issues,
    );
  }

  /// Attempts to parse a JSON string into a list of ActionIntents.
  static List<ActionIntent> _parseJsonActions(
    String jsonStr,
    List<ParseIssue> issues, {
    String? userPrompt,
  }) {
    final actions = <ActionIntent>[];

    try {
      final cleaned = JsonCleaner.clean(jsonStr);
      final parsed = jsonDecode(cleaned);

      List<Map<String, dynamic>> rawActions = [];

      if (parsed is List) {
        rawActions = parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (parsed is Map) {
        rawActions = [Map<String, dynamic>.from(parsed)];
      }

      for (int i = 0; i < rawActions.length; i++) {
        final raw = rawActions[i];
        final actionName = raw['action']?.toString() ?? '';

        // Look up in registry
        final definition = ActionRegistry.get(actionName);

        if (definition == null) {
          issues.add(ParseIssue(
            type: ParseIssueType.unknownAction,
            message: 'Unknown action: "$actionName"',
            actionIndex: i,
          ));
          actions.add(ActionIntent(
            action: actionName,
            data: raw,
            definition: null,
            validationErrors: ['Unknown action type'],
          ));
          continue;
        }

        // Normalize and validate
        final normalized = definition.normalize(raw);

        // ── Smart Date & Context Extraction ──
        final isTransactionAction = actionName.contains('transaction') || actionName.contains('expense');
        final isEventAction = actionName.contains('event');
        final isTaskAction = actionName.contains('task');

        if (isTransactionAction || isEventAction) {
          // 1. If date is present in action data, parse flexibly
          if (normalized['date'] != null) {
            final parsedDate = DateHelper.parseFlexibleDate(normalized['date']);
            if (parsedDate != null) {
              normalized['date'] = parsedDate.toIso8601String();
            }
          }
          // 2. If date is missing, check user prompt for mentioned dates
          if (normalized['date'] == null && userPrompt != null) {
            final extracted = DateHelper.extractDateFromText(userPrompt);
            if (extracted != null) {
              normalized['date'] = extracted.toIso8601String();
            }
          }
        }

        if (isTaskAction) {
          if (normalized['dueDate'] != null) {
            final parsedDate = DateHelper.parseFlexibleDate(normalized['dueDate']);
            if (parsedDate != null) {
              normalized['dueDate'] = parsedDate.toIso8601String();
            }
          } else if (normalized['date'] != null) {
            final parsedDate = DateHelper.parseFlexibleDate(normalized['date']);
            if (parsedDate != null) {
              normalized['dueDate'] = parsedDate.toIso8601String();
            }
          } else if (userPrompt != null && RegExp(r'\b(due|by|on)\b', caseSensitive: false).hasMatch(userPrompt)) {
            final extracted = DateHelper.extractDateFromText(userPrompt);
            if (extracted != null) {
              normalized['dueDate'] = extracted.toIso8601String();
            }
          }
        }

        // Ensure expense amounts are negative
        if (isTransactionAction) {
          final isExpense = actionName.contains('expense') ||
              (userPrompt != null &&
                  RegExp(r'\b(spent|expense|bought|paid|purchase|cost)\b', caseSensitive: false).hasMatch(userPrompt));
          if (isExpense && normalized['amount'] != null) {
            final amt = (normalized['amount'] is num)
                ? (normalized['amount'] as num).toDouble()
                : (double.tryParse(normalized['amount'].toString()) ?? 0.0);
            if (amt > 0) {
              normalized['amount'] = -amt;
            }
          }
        }

        final validationErrors = definition.validate(normalized);

        if (validationErrors.isNotEmpty) {
          for (final err in validationErrors) {
            issues.add(ParseIssue(
              type: ParseIssueType.validationError,
              message: err,
              actionIndex: i,
            ));
          }
        }

        actions.add(ActionIntent(
          action: actionName,
          data: normalized,
          definition: definition,
          validationErrors: validationErrors,
        ));
      }
    } catch (e) {
      debugPrint('JSON parse error: $e');
      issues.add(ParseIssue(
        type: ParseIssueType.malformedJson,
        message: 'Could not parse AI response as JSON: ${e.toString().substring(0, (e.toString().length).clamp(0, 100))}',
      ));
    }

    return actions;
  }
}
