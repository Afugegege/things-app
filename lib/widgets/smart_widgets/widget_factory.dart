import 'package:flutter/material.dart';
import '../../models/note_model.dart';

// Imports
import 'note_widgets.dart' hide AudioWidget;
import 'mosaic_widget.dart';
import 'expense_widget.dart';
import 'album_widget.dart';
import 'dashboard_widgets.dart';
import 'savings_goal_widget.dart';
import 'sleep_energy_widget.dart';
import 'expenses_chart_widget.dart';
import 'task_priority_widget.dart';
import 'day_counter_widget.dart';
import 'audio_widget.dart';

class WidgetFactory {
  static Widget build(BuildContext context, dynamic item) {
    // 1. SYSTEM WIDGETS
    if (item == 'EXPENSE_WIDGET') {
      return const ExpenseSummaryWidget();
    }
    if (item == 'EXPENSES_CHART_WIDGET') {
      return const ExpensesChartWidget();
    }
    if (item == 'TASK_PRIORITY_WIDGET') {
      return const TaskPriorityWidget();
    }
    if (item == 'SAVINGS_GOAL_WIDGET') {
      return const SavingsGoalWidget();
    }
    if (item == 'SLEEP_ENERGY_WIDGET') {
      return const SleepEnergyWidget();
    }

    // 2. NOTES & SMART WIDGETS
    if (item is Note) {
      final type = item.widgetType.toLowerCase();

      // --- EXPLICIT WIDGET TYPES ---
      if (type == 'checklist' ||
          type == 'list' ||
          type == 'todo' ||
          type == 'habit' ||
          type == 'tasks') {
        return ChecklistWidget(note: item);
      }
      if (type == 'sticker') return StickerWidget(note: item);
      if (type == 'monitor') return MonitorWidget(note: item);
      if (type == 'timer') return TimerWidget(note: item);
      if (type == 'quote') return QuoteWidget(note: item);
      if (type == 'album') return AlbumWidget(note: item);
      if (type == 'audio' || type == 'voice') return AudioWidget(note: item);
      if (type == 'day_counter' || type == 'days_since') return DayCounterWidget(note: item);
      if (type == 'expenses_chart') return const ExpensesChartWidget();
      if (type == 'task_priority') return const TaskPriorityWidget();
      if (type == 'savings_goal' || type == 'savings' || type == 'money') {
        return const SavingsGoalWidget();
      }
      if (type == 'sleep_energy' || type == 'sleep') {
        return const SleepEnergyWidget();
      }
      if (type == 'travel' || type == 'countdown' || type == 'event') {
        return CountdownWidget(note: item);
      }
      if (type == 'mosaic') return MosaicWidget(note: item);
      if (type == 'polaroid' && item.backgroundImage != null) {
        return PolaroidWidget(note: item, imagePath: item.backgroundImage!);
      }
      if (type == 'expense') return const ExpenseSummaryWidget();

      final rawContent = item.content;
      final plainText = item.plainTextContent;
      final plainTextLower = plainText.toLowerCase();
      final titleLower = item.title.toLowerCase();

      // --- AUTO-DETECTION RULES (When widgetType is standard or unhandled) ---

      // 1. Countdown / Date tag
      if (rawContent.contains('[[date:') ||
          plainTextLower.contains('[[date:')) {
        return CountdownWidget(note: item);
      }

      // 2. Habit / Checklist
      // Auto-detect checklist strictly if content actually contains checkboxes:
      // - markdown checkbox syntax: `- [ ]`, `- [x]`, `[ ]`, `[x]`, `-[ ]`, `-[x]`
      // - OR Quill JSON delta contains checklist attribute: `"list":"checked"`, `"list":"unchecked"`
      // - OR plain text has unicode checkmarks `☐`, `☑`
      // We strictly DO NOT auto-detect based on title words (e.g. grocery, shopping) or plain bullet points!
      final hasMarkdownCheckbox = rawContent.contains('- [ ]') ||
          rawContent.contains('- [x]') ||
          rawContent.contains('- [X]') ||
          rawContent.contains('-[ ]') ||
          rawContent.contains('-[x]') ||
          rawContent.contains('[ ]') ||
          rawContent.contains('[x]') ||
          plainText.contains('[ ]') ||
          plainText.contains('[x]') ||
          plainText.contains('☐') ||
          plainText.contains('☑');

      final hasQuillCheckbox = rawContent.contains('"list":"checked"') ||
          rawContent.contains('"list":"unchecked"') ||
          (rawContent.contains('"list"') &&
              (rawContent.contains('checked') ||
                  rawContent.contains('unchecked')));

      bool isChecklistContent = hasMarkdownCheckbox || hasQuillCheckbox;

      if (isChecklistContent) {
        return ChecklistWidget(note: item);
      }

      // 3. Mosaic / Polaroid
      if (item.backgroundImage != null) {
        if (plainText.length > 20) {
          return MosaicWidget(note: item);
        }
        return PolaroidWidget(note: item, imagePath: item.backgroundImage!);
      }

      // 4. Quote
      if ((plainTextLower.contains('"') ||
              plainTextLower.contains('“') ||
              plainTextLower.contains('”')) &&
          plainText.length < 120) {
        return QuoteWidget(note: item);
      }

      // Default
      return TypographyWidget(note: item);
    }

    return const SizedBox();
  }
}
