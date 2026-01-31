import 'package:flutter/material.dart';
import '../../models/note_model.dart';

// Imports
import 'note_widgets.dart';     
import 'mosaic_widget.dart';    
import 'expense_widget.dart';
import 'album_widget.dart'; // <--- Import

import 'dashboard_widgets.dart'; // <--- Import

class WidgetFactory {
  
  static Widget build(BuildContext context, dynamic item) {
    
    // 1. EXPENSE
    if (item == 'EXPENSE_WIDGET') {
      return const ExpenseSummaryWidget(); 
    }

    // 2. NOTES
    if (item is Note) {
      // --- DASHBOARD WIDGETS ---
      if (item.widgetType == 'sticker') return StickerWidget(note: item);
      if (item.widgetType == 'monitor') return MonitorWidget(note: item);
      if (item.widgetType == 'timer') return TimerWidget(note: item);
      if (item.widgetType == 'quote') return QuoteWidget(note: item);

      // Explicit Album Type
      if (item.widgetType == 'album') {
        return AlbumWidget(note: item);
      }

      final content = item.plainTextContent.toLowerCase();
      final title = item.title.toLowerCase();

      // Countdown
      if (item.content.contains('[[date:')) {
        return CountdownWidget(note: item);
      }

      // Habit / Checklist
      if (item.content.contains('- [ ]') || item.content.contains('- [x]') || title.contains('list') || title.contains('routine')) {
        return ChecklistWidget(note: item);
      }

      // Mosaic / Polaroid (Legacy Auto-detection)
      if (item.backgroundImage != null) {
        if (item.plainTextContent.length > 20) {
          return MosaicWidget(note: item);
        }
        return PolaroidWidget(note: item, imagePath: item.backgroundImage!);
      }

      // Quote
      if (content.contains('"') && item.plainTextContent.length < 80) {
        return QuoteWidget(note: item);
      }

      // Default
      return TypographyWidget(note: item);
    }

    return const SizedBox();
  }
}