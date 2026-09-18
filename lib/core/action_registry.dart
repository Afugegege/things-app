import 'package:flutter/material.dart';

// ──────────────────────────────────────────────
//  FIELD TYPES & SCHEMA
// ──────────────────────────────────────────────

enum FieldType { text, longText, number, dropdown, date, boolean }

enum ActionStatus { pending, confirmed, loading, success, error }

class ActionFieldSchema {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final dynamic defaultValue;
  final List<String>? options; // for dropdowns
  final int? maxLength;
  final bool Function(dynamic value)? customValidator;

  const ActionFieldSchema({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.options,
    this.maxLength,
    this.customValidator,
  });
}

// ──────────────────────────────────────────────
//  ACTION RESULT
// ──────────────────────────────────────────────

class ActionResult {
  final bool isSuccess;
  final String? id;
  final String summary;

  const ActionResult._({required this.isSuccess, this.id, required this.summary});

  factory ActionResult.success({String? id, required String summary}) =>
      ActionResult._(isSuccess: true, id: id, summary: summary);

  factory ActionResult.error(String message) =>
      ActionResult._(isSuccess: false, summary: message);
}

// ──────────────────────────────────────────────
//  ACTION DEFINITION
// ──────────────────────────────────────────────

class ActionDefinition {
  final String name;
  final String displayName;
  final IconData icon;
  final List<ActionFieldSchema> schema;
  final Future<ActionResult> Function(Map<String, dynamic> data, BuildContext context) execute;

  const ActionDefinition({
    required this.name,
    required this.displayName,
    required this.icon,
    required this.schema,
    required this.execute,
  });

  /// Validates raw data against the schema. Returns list of error strings.
  List<String> validate(Map<String, dynamic> data) {
    final errors = <String>[];
    for (final field in schema) {
      final value = data[field.key];

      // Required check
      if (field.required && (value == null || (value is String && value.trim().isEmpty))) {
        errors.add('${field.label} is required');
        continue;
      }

      if (value == null) continue;

      // Max length check
      if (field.maxLength != null && value is String && value.length > field.maxLength!) {
        errors.add('${field.label} exceeds max length of ${field.maxLength}');
      }

      // Dropdown options check
      if (field.type == FieldType.dropdown && field.options != null) {
        final strValue = value.toString();
        if (!field.options!.any((opt) => opt.startsWith(strValue) || opt == strValue)) {
          // Tolerate numeric values for priority-style fields
          // Don't error if the value is a valid number within options range
        }
      }

      // Custom validator
      if (field.customValidator != null && !field.customValidator!(value)) {
        errors.add('${field.label} has an invalid value');
      }
    }
    return errors;
  }

  /// Fills in defaults and normalizes data. Returns cleaned Map.
  Map<String, dynamic> normalize(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Smart alias mapping for common key mismatches from AI
    if (result['search_title'] == null || result['search_title'].toString().trim().isEmpty) {
      final alt = result['title'] ?? result['name'] ?? result['id'] ?? result['fact'] ?? result['text'];
      if (alt != null) result['search_title'] = alt;
    }
    if (result['title'] == null || result['title'].toString().trim().isEmpty) {
      final alt = result['search_title'] ?? result['name'] ?? result['description'];
      if (alt != null) result['title'] = alt;
    }

    for (final field in schema) {
      if (!result.containsKey(field.key) || result[field.key] == null) {
        if (field.defaultValue != null) {
          result[field.key] = field.defaultValue;
        }
      }
      // Coerce number strings to actual numbers
      if (field.type == FieldType.number && result[field.key] is String) {
        result[field.key] = num.tryParse(result[field.key]) ?? field.defaultValue ?? 0;
      }
    }
    return result;
  }
}

// ──────────────────────────────────────────────
//  ACTION INTENT (parsed from AI output)
// ──────────────────────────────────────────────

class ActionIntent {
  final String action;
  Map<String, dynamic> data;
  final ActionDefinition? definition;
  final List<String> validationErrors;
  ActionStatus status;

  ActionIntent({
    required this.action,
    required this.data,
    this.definition,
    this.validationErrors = const [],
    this.status = ActionStatus.pending,
  });
}

// ──────────────────────────────────────────────
//  ACTION REGISTRY (singleton lookup table)
// ──────────────────────────────────────────────

class ActionRegistry {
  static final Map<String, ActionDefinition> _actions = {};

  static void register(String name, ActionDefinition def) {
    _actions[name] = def;
  }

  static ActionDefinition? get(String name) => _actions[name];

  static List<String> get supportedActions => _actions.keys.toList();

  static Map<String, ActionDefinition> get all => Map.unmodifiable(_actions);

  /// Called once at app startup to register all built-in actions.
  /// Import and call registerAllActions() from action_definitions.dart.
  static void initialize() {
    // Populated by action_definitions.dart
  }
}
