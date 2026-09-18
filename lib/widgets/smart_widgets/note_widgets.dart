import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../glass_container.dart';

// --- 1. COUNTDOWN WIDGET ---
class CountdownWidget extends StatelessWidget {
  final Note note;
  const CountdownWidget({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    DateTime target = DateTime.now().add(const Duration(days: 7));
    try {
      final match = RegExp(r'\[\[date:(.*?)\]\]').firstMatch(note.content);
      if (match != null) {
        target = DateTime.parse(match.group(1)!);
      }
    } catch (_) {}

    final daysLeft = target.difference(DateTime.now()).inDays;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: note.isPinned
            ? Border.all(color: textColor, width: 2.0)
            : (isDark
                ? Border.all(color: Colors.white12, width: 1.0)
                : Border.all(
                    color: Colors.black.withOpacity(0.08), width: 1.0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // FIX: Prevent grid crash
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(CupertinoIcons.airplane, color: textColor, size: 20),
              Text("${target.day}/${target.month}",
                  style: TextStyle(
                      color: dimmedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text("$daysLeft",
              style: TextStyle(
                  color: textColor,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1.0)),
          Text("DAYS LEFT",
              style: TextStyle(
                  color: dimmedColor,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(note.title,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// --- 2. INTERACTIVE CHECKLIST WIDGET ---
class ChecklistWidget extends StatelessWidget {
  final Note note;
  const ChecklistWidget({super.key, required this.note});

  static dynamic _parseContentJson(dynamic content) {
    dynamic parsed = content;
    if (parsed is String) {
      String s = parsed.trim();
      if (s.startsWith('[') || s.startsWith('{')) {
        try {
          for (int i = 0; i < 3; i++) {
            if (s.startsWith('[') || s.startsWith('{')) {
              parsed = jsonDecode(s);
              if (parsed is String) {
                s = parsed.trim();
              } else {
                break;
              }
            } else {
              break;
            }
          }
        } catch (_) {}
      }
    }
    return parsed;
  }

  static List<String> _extractLines(Note note) {
    dynamic parsed = _parseContentJson(note.content);
    if (parsed is List) {
      final buffer = StringBuffer();
      for (final op in parsed) {
        if (op is Map && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }
      String fullText = buffer.toString().replaceAll('\r\n', '\n');
      if (fullText.endsWith('\n')) {
        fullText = fullText.substring(0, fullText.length - 1);
      }
      return fullText.split('\n');
    }
    String text = note.content.replaceAll('\r\n', '\n');
    if (text.endsWith('\n')) {
      text = text.substring(0, text.length - 1);
    }
    final lines = text.split('\n');
    if (lines.isNotEmpty) return lines;
    return note.plainTextContent.replaceAll('\r\n', '\n').split('\n');
  }

  static bool _hasCheckbox(String text) {
    final trimmed = text.trim();
    final checkboxMarkerRegExp =
        RegExp(r'^(?:-\s*|[*]\s*|•\s*|\d+\.\s*)?(?:\[[ xX]\]|[☐☑])');
    return checkboxMarkerRegExp.hasMatch(trimmed) ||
        trimmed.contains('[ ]') ||
        trimmed.contains('[x]') ||
        trimmed.contains('[X]') ||
        trimmed.contains('☐') ||
        trimmed.contains('☑');
  }

  static String _toggleCheckboxString(String text) {
    if (text.contains('[ ]')) {
      return text.replaceFirst('[ ]', '[x]');
    } else if (text.contains('[x]')) {
      return text.replaceFirst('[x]', '[ ]');
    } else if (text.contains('[X]')) {
      return text.replaceFirst('[X]', '[ ]');
    } else if (text.contains('☐')) {
      return text.replaceFirst('☐', '☑');
    } else if (text.contains('☑')) {
      return text.replaceFirst('☑', '☐');
    } else {
      final isDone = text.toLowerCase().contains('[x]') || text.contains('☑');
      final clean = text
          .replaceAll(
              RegExp(
                  r'^(?:-\s*|[*]\s*|•\s*|\d+\.\s*)?(?:\[[ xX]\]|[☐☑])\s*'),
              '')
          .replaceAll(RegExp(r'^(?:-\s*|[*]\s*|•\s*)'), '')
          .trim();
      return isDone ? "- [ ] $clean" : "- [x] $clean";
    }
  }

  void _toggleItem(BuildContext context, int lineIndex, String currentLine) {
    String newContent = note.content;
    bool contentUpdated = false;

    try {
      dynamic parsed = _parseContentJson(note.content);

      if (parsed is List) {
        List<dynamic> ops = List.from(parsed.map((op) {
          if (op is Map) {
            final copy = Map<String, dynamic>.from(op);
            if (copy.containsKey('attributes') && copy['attributes'] is Map) {
              copy['attributes'] =
                  Map<String, dynamic>.from(copy['attributes']);
            }
            return copy;
          }
          return op;
        }));

        // Pass 1: Toggle Quill list attribute on the newline that terminates lineIndex
        int currentLineCount = 0;
        for (int i = 0; i < ops.length; i++) {
          var op = ops[i];
          if (op is Map && op['insert'] is String) {
            String text = op['insert'];
            int newlinesInOp = '\n'.allMatches(text).length;

            if (newlinesInOp > 0) {
              // Line lineIndex terminates in this op if it falls in [currentLineCount, currentLineCount + newlinesInOp)
              if (lineIndex >= currentLineCount &&
                  lineIndex < currentLineCount + newlinesInOp) {
                if (op.containsKey('attributes') &&
                    op['attributes'] is Map) {
                  Map<String, dynamic> attrs = op['attributes'];
                  if (attrs.containsKey('list')) {
                    bool isChecked = attrs['list'] == 'checked';
                    attrs['list'] = isChecked ? 'unchecked' : 'checked';
                    contentUpdated = true;
                    break;
                  }
                }
              }
              currentLineCount += newlinesInOp;
            }
          }
        }

        // Pass 2: If no block attribute toggled, check for inline markdown checkboxes in ops
        if (!contentUpdated) {
          int lineCounter = 0;
          for (int i = 0; i < ops.length; i++) {
            var op = ops[i];
            if (op is Map && op['insert'] is String) {
              String text = op['insert'];
              int newlinesInOp = '\n'.allMatches(text).length;

              if (newlinesInOp == 0) {
                if (lineCounter == lineIndex && _hasCheckbox(text)) {
                  ops[i]['insert'] = _toggleCheckboxString(text);
                  contentUpdated = true;
                  break;
                }
              } else {
                if (lineIndex >= lineCounter &&
                    lineIndex < lineCounter + newlinesInOp) {
                  int relativeLine = lineIndex - lineCounter;
                  List<String> opLines = text.split('\n');
                  if (relativeLine < opLines.length &&
                      _hasCheckbox(opLines[relativeLine])) {
                    opLines[relativeLine] =
                        _toggleCheckboxString(opLines[relativeLine]);
                    ops[i]['insert'] = opLines.join('\n');
                    contentUpdated = true;
                    break;
                  }
                }
                lineCounter += newlinesInOp;
              }
            }
          }
        }

        // Pass 3: Fallback content match if lineIndex could not be matched directly
        if (!contentUpdated && currentLine.trim().isNotEmpty) {
          String cleanCurrent = currentLine
              .replaceAll(
                  RegExp(
                      r'^(?:-\s*|[*]\s*|•\s*|\d+\.\s*)?(?:\[[ xX]\]|[☐☑])\s*'),
                  '')
              .replaceAll(RegExp(r'^(?:-\s*|[*]\s*|•\s*)'), '')
              .trim();

          for (int i = 0; i < ops.length; i++) {
            var op = ops[i];
            if (op is Map && op['insert'] is String) {
              String text = op['insert'];
              int newlinesInOp = '\n'.allMatches(text).length;
              if (newlinesInOp > 0 &&
                  op.containsKey('attributes') &&
                  op['attributes'] is Map) {
                Map<String, dynamic> attrs = op['attributes'];
                if (attrs.containsKey('list')) {
                  if (i > 0 &&
                      ops[i - 1] is Map &&
                      ops[i - 1]['insert'] is String) {
                    String prevText = ops[i - 1]['insert'].toString().trim();
                    if (prevText.contains(cleanCurrent) ||
                        cleanCurrent.contains(prevText)) {
                      bool isChecked = attrs['list'] == 'checked';
                      attrs['list'] = isChecked ? 'unchecked' : 'checked';
                      contentUpdated = true;
                      break;
                    }
                  }
                }
              }
            }
          }
        }

        if (contentUpdated) {
          newContent = jsonEncode(ops);
        }
      }
    } catch (_) {}

    // Fallback: Handle plain text / markdown content
    if (!contentUpdated) {
      String trimmed = note.content.trim();
      if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) {
        final List<String> lines = _extractLines(note);
        int targetIndex = lineIndex;

        if (targetIndex >= lines.length || !_hasCheckbox(lines[targetIndex])) {
          String cleanCurrent = currentLine
              .replaceAll(
                  RegExp(
                      r'^(?:-\s*|[*]\s*|•\s*|\d+\.\s*)?(?:\[[ xX]\]|[☐☑])\s*'),
                  '')
              .replaceAll(RegExp(r'^(?:-\s*|[*]\s*|•\s*)'), '')
              .trim();
          for (int i = 0; i < lines.length; i++) {
            if (_hasCheckbox(lines[i])) {
              String clean = lines[i]
                  .replaceAll(
                      RegExp(
                          r'^(?:-\s*|[*]\s*|•\s*|\d+\.\s*)?(?:\[[ xX]\]|[☐☑])\s*'),
                      '')
                  .replaceAll(RegExp(r'^(?:-\s*|[*]\s*|•\s*)'), '')
                  .trim();
              if (clean == cleanCurrent || lines[i].contains(cleanCurrent)) {
                targetIndex = i;
                break;
              }
            }
          }
        }

        if (targetIndex < lines.length) {
          lines[targetIndex] = _toggleCheckboxString(lines[targetIndex]);
          newContent = lines.join('\n');
          contentUpdated = true;
        }
      }
    }

    if (contentUpdated) {
      Provider.of<NotesProvider>(context, listen: false).updateNote(
          note.copyWith(content: newContent, updatedAt: DateTime.now()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get Text Lines aligned with document structure
    final List<String> allLines = _extractLines(note);

    // 2. Determine Checked State and Checkbox Status per Line
    List<bool> checkedState = List.filled(allLines.length, false);
    List<bool> isCheckboxLine = List.filled(allLines.length, false);

    dynamic parsed = _parseContentJson(note.content);
    if (parsed is List) {
      int currentLineIndex = 0;
      for (var op in parsed) {
        if (op is Map && op['insert'] is String) {
          String text = op['insert'];
          int newlines = '\n'.allMatches(text).length;

          bool isChecklistOp = false;
          bool isChecked = false;
          if (op.containsKey('attributes') && op['attributes'] is Map) {
            var attrs = op['attributes'];
            if (attrs['list'] == 'checked' || attrs['checked'] == true) {
              isChecklistOp = true;
              isChecked = true;
            } else if (attrs['list'] == 'unchecked') {
              isChecklistOp = true;
              isChecked = false;
            }
          }

          if (newlines > 0) {
            for (int j = 0; j < newlines; j++) {
              int lineIdx = currentLineIndex + j;
              if (lineIdx < allLines.length) {
                if (isChecklistOp) {
                  isCheckboxLine[lineIdx] = true;
                  if (isChecked) {
                    checkedState[lineIdx] = true;
                  }
                }
              }
            }
            currentLineIndex += newlines;
          }
        }
      }
    }

    // 3. Check for Markdown / explicit checkbox syntax in lines
    final checkboxMarkerRegExp =
        RegExp(r'^(?:-\s*|[*]\s*|•\s*|\d+\.\s*)?(?:\[[ xX]\]|[☐☑])');
    for (int i = 0; i < allLines.length; i++) {
      final trimmed = allLines[i].trim();
      if (checkboxMarkerRegExp.hasMatch(trimmed) ||
          trimmed.contains('[ ]') ||
          trimmed.contains('[x]') ||
          trimmed.contains('[X]') ||
          trimmed.contains('☐') ||
          trimmed.contains('☑')) {
        isCheckboxLine[i] = true;
        final l = trimmed.toLowerCase();
        if (l.contains('[x]') || l.contains('☑')) {
          checkedState[i] = true;
        }
      }
    }

    // 4. Build Display Items
    final checkboxRegExp =
        RegExp(r'^(?:-\s*|[*]\s*|•\s*|\d+\.\s*)?(?:\[[ xX]\]|[☐☑])\s*');
    final bulletRegExp = RegExp(r'^(?:-\s*|[*]\s*|•\s*)');

    List<int> itemIndices = [];
    for (int i = 0; i < allLines.length; i++) {
      if (allLines[i].trim().isEmpty) continue;
      itemIndices.add(i);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final bool isHabit = note.title.toLowerCase().contains('routine') ||
        note.title.toLowerCase().contains('habit');
    final Color accentColor = textColor; // Monochrome

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: note.isPinned
            ? Border.all(color: textColor, width: 2.0)
            : (isDark
                ? Border.all(color: Colors.white12, width: 1.0)
                : Border.all(
                    color: Colors.black.withOpacity(0.08), width: 1.0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // FIX: Prevent grid crash
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isHabit)
                      Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.refresh,
                              color: dimmedColor, size: 14)),
                    Flexible(
                      child: Text(
                        isHabit ? note.title.toUpperCase() : note.title,
                        style: TextStyle(
                          color: isHabit ? dimmedColor : textColor,
                          fontSize: isHabit ? 12 : 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: isHabit ? 1.5 : 0.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (itemIndices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text("Empty List", style: TextStyle(color: dimmedColor)),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (note.isExpanded ? itemIndices : itemIndices.take(6))
                  .map((index) {
                final line = allLines[index];
                final bool isCheckbox = isCheckboxLine[index];
                final bool isDone = checkedState[index];

                // If NOT a checkbox line, render strictly as clean text/header without checkbox circle
                if (!isCheckbox) {
                  final isHeader = line.trim().startsWith('#');
                  final cleanHeader = isHeader
                      ? line.replaceAll(RegExp(r'^#+\s*'), '').trim()
                      : line.trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(
                      cleanHeader,
                      style: TextStyle(
                        color: isHeader ? textColor : dimmedColor,
                        fontSize: isHeader ? 14 : 13,
                        fontWeight:
                            isHeader ? FontWeight.bold : FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }

                // Clean text for checkbox display
                String cleanText = line
                    .replaceAll(checkboxRegExp, '')
                    .replaceAll(bulletRegExp, '')
                    .trim();
                if (cleanText.isEmpty) cleanText = line.trim();

                return GestureDetector(
                  onTap: () => _toggleItem(context, index, allLines[index]),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Icon(
                            isDone
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.circle,
                            size: 22,
                            color: isDone ? accentColor : dimmedColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            cleanText,
                            style: TextStyle(
                              color: isDone ? dimmedColor : textColor,
                              fontSize: note.fontSize ?? 14.0,
                              fontWeight:
                                  isDone ? FontWeight.normal : FontWeight.w500,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                              decorationColor: dimmedColor,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// --- 3. QUOTE WIDGET ---
class QuoteWidget extends StatelessWidget {
  final Note note;
  const QuoteWidget({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    final bgColor = isDark ? theme.cardColor : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: note.isPinned
            ? Border.all(color: textColor, width: 2.0)
            : (isDark
                ? Border.all(color: Colors.white12, width: 1.0)
                : Border.all(
                    color: Colors.black.withOpacity(0.08), width: 1.0)),
      ),
      child: Container(
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isDark ? Colors.white70 : Colors.black87,
              width: 3.0,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.quote_bubble_fill,
                    size: 14, color: textColor.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  "QUOTE",
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "\"${note.plainTextContent.replaceAll('"', '').trim()}\"",
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.4,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. TYPOGRAPHY WIDGET ---
class TypographyWidget extends StatelessWidget {
  final Note note;
  const TypographyWidget({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    // Use custom color if available
    if (note.backgroundColor != null && note.backgroundColor != 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(note.backgroundColor!),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: note.isPinned
                  ? Colors.white.withOpacity(0.9)
                  : Colors.white24,
              width: note.isPinned ? 4.0 : 2.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    note.title.isNotEmpty ? note.title : "Untitled",
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.plainTextContent,
              style: TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                  fontSize: note.fontSize ?? 15.0),
              maxLines: note.isExpanded ? null : 4,
              overflow: note.isExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.cardColor : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: note.isPinned
            ? Border.all(color: textColor, width: 2.0)
            : (isDark
                ? Border.all(color: Colors.white12, width: 1.0)
                : Border.all(
                    color: Colors.black.withOpacity(0.08), width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.title.isNotEmpty ? note.title : "Untitled",
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.plainTextContent,
            style: TextStyle(
                color: dimmedColor,
                height: 1.4,
                fontSize: note.fontSize ?? 15.0),
            maxLines: note.isExpanded ? null : 4,
            overflow:
                note.isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// --- 5. POLAROID WIDGET ---
class PolaroidWidget extends StatelessWidget {
  final Note note;
  final String imagePath;
  const PolaroidWidget(
      {super.key, required this.note, required this.imagePath});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border:
            note.isPinned ? Border.all(color: Colors.black, width: 4.0) : null,
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // FIX: min size
        AspectRatio(
            aspectRatio: 1,
            child: Container(
                color: Colors.grey[200],
                child: Image.file(File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image)))),
        const SizedBox(height: 10),
        Text(note.title,
            style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier')),
      ]),
    );
  }
}

// --- 6. AUDIO WIDGET ---
class AudioWidget extends StatelessWidget {
  final Note note;
  const AudioWidget({super.key, required this.note});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: note.isPinned
            ? Border.all(color: Colors.white, width: 2.0)
            : Border.all(color: Colors.white12, width: 1.0),
      ),
      child: const GlassContainer(
        padding: EdgeInsets.all(15),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // FIX: min size
          Row(children: [
            Icon(CupertinoIcons.mic, color: Colors.white),
            SizedBox(width: 10),
            Text("Voice Note", style: TextStyle(color: Colors.white))
          ]),
        ]),
      ),
    );
  }
}
