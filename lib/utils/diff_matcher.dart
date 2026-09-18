import 'package:flutter/material.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart' as dqd;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'markdown_to_quill.dart';

/// Represents a targeted edit region in a note document
class DiffTarget {
  final int start;
  final int length;
  final String originalText;
  final String suggestedText;

  const DiffTarget({
    required this.start,
    required this.length,
    required this.originalText,
    required this.suggestedText,
  });
}

class DiffMatcher {
  /// Hex colors for Notion-style inline diffs
  static const String deletionBg = '#33FF453A'; // Soft red/rose tint
  static const String deletionColor = '#E53935'; // Red text
  static const String additionBg = '#252ECC71'; // Soft emerald tint
  static const String additionColor = '#2ECC71'; // Emerald text

  /// Finds the best character range in [fullText] corresponding to [query].
  /// Checks exact match, trimmed match, line match, or returns null if not found.
  static TextRange? findBestMatchRange(String fullText, String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || fullText.isEmpty) return null;

    // 1. Exact match
    final exactIdx = fullText.indexOf(cleanQuery);
    if (exactIdx != -1) {
      return TextRange(start: exactIdx, end: exactIdx + cleanQuery.length);
    }

    // 2. Case-insensitive match
    final lowerDoc = fullText.toLowerCase();
    final lowerQuery = cleanQuery.toLowerCase();
    final caseIdx = lowerDoc.indexOf(lowerQuery);
    if (caseIdx != -1) {
      return TextRange(start: caseIdx, end: caseIdx + cleanQuery.length);
    }

    // 3. Line-by-line similarity matching
    final lines = fullText.split('\n');
    int currentOffset = 0;
    int bestScore = 0;
    TextRange? bestRange;

    for (final line in lines) {
      final lineTrim = line.trim();
      if (lineTrim.isNotEmpty) {
        if (lineTrim == cleanQuery || lineTrim.contains(cleanQuery) || cleanQuery.contains(lineTrim)) {
          final start = fullText.indexOf(line, currentOffset);
          if (start != -1) {
            return TextRange(start: start, end: start + line.length);
          }
        }

        // Word overlap heuristic
        final queryWords = lowerQuery.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
        final lineWords = lineTrim.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
        if (queryWords.isNotEmpty && lineWords.isNotEmpty) {
          final overlap = queryWords.intersection(lineWords).length;
          if (overlap > bestScore && overlap >= (queryWords.length * 0.5).ceil()) {
            bestScore = overlap;
            final start = fullText.indexOf(line, currentOffset);
            if (start != -1) {
              bestRange = TextRange(start: start, end: start + line.length);
            }
          }
        }
      }
      currentOffset += line.length + 1; // +1 for '\n'
    }

    return bestRange;
  }

  /// Builds a visual diff Quill Document where the original text in [target] is
  /// strikethrough + red highlight, followed by the suggested text in green highlight.
  static quill.Document buildPreviewDocument({
    required quill.Document originalDoc,
    required DiffTarget target,
  }) {
    final plainText = originalDoc.toPlainText();
    final docLength = plainText.length;
    final clampedStart = target.start.clamp(0, docLength);
    final clampedLength = target.length.clamp(0, docLength - clampedStart);

    final previewOps = <Map<String, dynamic>>[];
    final originalOps = originalDoc.toDelta().toJson();

    int offset = 0;

    for (final op in originalOps) {
      if (op['insert'] is! String) {
        previewOps.add(Map<String, dynamic>.from(op));
        continue;
      }

      final text = op['insert'] as String;
      final opStart = offset;
      final opEnd = offset + text.length;
      offset = opEnd;

      // Entirely before target
      if (opEnd <= clampedStart) {
        previewOps.add(Map<String, dynamic>.from(op));
        continue;
      }

      // Entirely after target
      if (opStart >= clampedStart + clampedLength) {
        previewOps.add(Map<String, dynamic>.from(op));
        continue;
      }

      // Intersects target
      final preLength = (clampedStart - opStart).clamp(0, text.length);
      final inStart = preLength;
      final inEnd = (clampedStart + clampedLength - opStart).clamp(0, text.length);
      final postLength = text.length - inEnd;

      if (preLength > 0) {
        previewOps.add({
          'insert': text.substring(0, preLength),
          if (op['attributes'] != null) 'attributes': Map<String, dynamic>.from(op['attributes']),
        });
      }

      if (inEnd > inStart) {
        final targetPart = text.substring(inStart, inEnd);
        final strikeAttrs = Map<String, dynamic>.from(op['attributes'] ?? {});
        strikeAttrs['strike'] = true;
        strikeAttrs['color'] = deletionColor;
        strikeAttrs['background'] = deletionBg;
        previewOps.add({
          'insert': targetPart,
          'attributes': strikeAttrs,
        });
      }

      // Check if this op is where the target ends - insert the suggested text here!
      if (opEnd >= clampedStart + clampedLength) {
        // Insert separator and suggestion
        _appendSuggestedPreview(previewOps, target.suggestedText);
      }

      if (postLength > 0) {
        previewOps.add({
          'insert': text.substring(inEnd),
          if (op['attributes'] != null) 'attributes': Map<String, dynamic>.from(op['attributes']),
        });
      }
    }

    // Fallback if target was at the very end
    if (offset < clampedStart + clampedLength || previewOps.isEmpty) {
      _appendSuggestedPreview(previewOps, target.suggestedText);
    }

    // Ensure document ends with newline
    _ensureTrailingNewline(previewOps);

    return quill.Document.fromJson(previewOps);
  }

  static void _appendSuggestedPreview(List<Map<String, dynamic>> ops, String suggestedText) {
    // Add a newline before suggestion if not present
    ops.add({
      'insert': '\n',
    });

    final suggestedDoc = markdownToQuill(suggestedText);
    for (final op in suggestedDoc.toDelta().toJson()) {
      if (op['insert'] is String) {
        final text = op['insert'] as String;
        if (text == '\n') {
          ops.add(Map<String, dynamic>.from(op));
        } else {
          final attrs = Map<String, dynamic>.from(op['attributes'] ?? {});
          attrs['background'] = additionBg;
          attrs['color'] = additionColor;
          ops.add({
            'insert': text,
            'attributes': attrs,
          });
        }
      } else {
        ops.add(Map<String, dynamic>.from(op));
      }
    }
  }

  /// Builds a clean committed document replacing the target range with [suggestedText].
  /// Strips all diff attributes (strike, diff backgrounds/colors).
  static quill.Document buildCommittedDocument({
    required dqd.Delta prePreviewDelta,
    required DiffTarget target,
  }) {
    final doc = quill.Document.fromDelta(prePreviewDelta);
    final plainLength = doc.toPlainText().length;

    // 1. If replacing the entire document (or target spans the whole text)
    if (target.start == 0 && target.length >= plainLength - 1) {
      return markdownToQuill(target.suggestedText);
    }

    var delta = dqd.Delta();
    if (target.start > 0) {
      delta.retain(target.start);
    }
    if (target.length > 0) {
      delta.delete(target.length);
    }
    if (target.suggestedText.isNotEmpty) {
      delta = delta.concat(markdownToQuill(target.suggestedText).toDelta());
    }

    final committedDoc = quill.Document.fromDelta(prePreviewDelta);
    committedDoc.compose(delta, quill.ChangeSource.local);
    return committedDoc;
  }

  static void _ensureTrailingNewline(List<Map<String, dynamic>> ops) {
    if (ops.isEmpty) {
      ops.add({'insert': '\n'});
      return;
    }
    final last = ops.last;
    if (last['insert'] is String) {
      final str = last['insert'] as String;
      if (!str.endsWith('\n')) {
        ops.add({'insert': '\n'});
      }
    } else {
      ops.add({'insert': '\n'});
    }
  }
}
