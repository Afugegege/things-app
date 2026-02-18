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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: note.isPinned 
            ? Border.all(color: textColor.withOpacity(0.8), width: 4.0) 
            : (isDark ? Border.all(color: Colors.white24, width: 2.0) : Border.all(color: theme.dividerColor, width: 2.0)),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
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
              Text("${target.day}/${target.month}", style: TextStyle(color: dimmedColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text("$daysLeft", style: TextStyle(color: textColor, fontSize: 48, fontWeight: FontWeight.bold, height: 1.0)),
          Text("DAYS LEFT", style: TextStyle(color: dimmedColor, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(note.title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _toggleItem(BuildContext context, int lineIndex, String currentLine) {
    String newContent = note.content;
    bool contentUpdated = false;

    try {
      // 1. Safe JSON Decode (Handle multi-level string encoding)
      dynamic parsed = note.content;
      bool isJson = false;
        if (parsed is String) {
          String s = parsed.trim();
          if (s.startsWith('[') || s.startsWith('{')) {
             try {
               // Try deep decoding up to 3 times
               for (int i = 0; i < 3; i++) {
                 if (s is String && (s.startsWith('[') || s.startsWith('{'))) {
                   parsed = jsonDecode(s);
                   isJson = true;
                   if (parsed is String) s = parsed; // unwrapped layer
                 } else {
                   break; 
                 }
               }
             } catch (_) {}
          }
        }

      if (isJson && parsed is List) {
         List<dynamic> ops = List.from(parsed); // generic cast
         int currentLineCount = 0;
         
         // Iterate to find the target line's content or newline attribute
         for (int i = 0; i < ops.length; i++) {
           var op = ops[i];
           if (op is Map && op['insert'] is String) {
              String text = op['insert'];
              List<String> opLines = text.split('\n');
              // Note: split('\n') for "A\nB" gives ["A", "B"]. 
              // For "A\n" gives ["A", ""].
              // Newlines are separators.
              
              // We need to match precise line index.
              // Logic: Count newlines in this op.
              // Each newline finishes a line.
              
              int newlinesInOp = '\n'.allMatches(text).length;
              
              // Check if our target line ENDS in this op?
              // The attributes for line N are usually on the Nth newline.
              
              // Simplistic Text Toggle Strategy (Markdown Style)
              // If we are INSIDE the line content (not the newline op), check for "- [ ]".
              if (currentLineCount <= lineIndex && (currentLineCount + newlinesInOp) >= lineIndex) {
                 // The line start is here.
                 // Find local index relative to line count.
                 // This is tricky crossing ops.
                 // Simplified: If op contains text for this line, scan it.
                 
                 // Fallback to simpler 'Check whole op for target text' approach for Markdown
                 // This matches previous logic which worked for Text-based lists.
                  if (text.contains(currentLine.trim())) { // Check matches content
                     // Toggle text pattern
                     if (text.contains('- [ ]') || text.contains('- [x]')) {
                         String toggled = text.replaceAll('- [ ]', '- [x]').replaceAll('- [x]', '- [ ]');
                         // Be careful not to replace wrong ones if multiple same lines.
                         // But simple replace is safer than index wizardry for now.
                         // Better: RegExp replace first instance?
                         // Let's assume one line per op usually for checkboxes.
                         if (text.startsWith('- [')) {
                            // Only toggle start
                             String savedTail = text.substring(5);
                             String header = text.substring(0, 5);
                             header = header == '- [ ]' ? '- [x]' : '- [ ]';
                             ops[i]['insert'] = header + savedTail;
                             contentUpdated = true;
                             break;
                         }
                     }
                  }
              }

              // Attribute Toggle Strategy (Quill Style)
              // We need to find the newline character that ENDS line 'lineIndex'.
              // It is the (lineIndex + 1)-th newline in the whole doc.
              // 'currentLineCount' tracks finished lines so far.
              // If 'lineIndex' is 2, we want the newline at end of line 2.
              
              int relativeTarget = lineIndex - currentLineCount;
              if (relativeTarget >= 0 && relativeTarget < newlinesInOp) {
                 // Found the newline!
                 // It is at specific index in 'text'.
                 // BUT attributes apply to the whole op if not split.
                 // If the op is just "\n", update it.
                 if (text == '\n') {
                    Map<String, dynamic> attrs = Map.from(ops[i]['attributes'] ?? {});
                    bool isChecked = attrs['list'] == 'checked';
                    attrs['list'] = isChecked ? 'unchecked' : 'checked';
                    ops[i]['attributes'] = attrs;
                    contentUpdated = true;
                    break;
                 } else {
                   // Op is mixed "Text\n". Attributes apply to newline.
                   // In Quill, if op has text and \n, both share attributes block-wise? 
                   // Usually separate ops: text op, then \n op.
                   // If mixed, we might need to split to apply attribute safely.
                   // For now, if we detect mixed content, assume implicit mode:
                   // Just leave it - prevents corruption.
                 }
              }
              
              currentLineCount += newlinesInOp;
           }
         }
         
         if (contentUpdated) {
            newContent = jsonEncode(ops);
         }
      }
    } catch (e) {
      // Safely ignore deep JSON failures, fallback only if absolutely sure it's plain text?
      // No, let's keep original content if JSON parse fails to avoid corruption.
    }

    // 2. Fallback: If no JSON update happened, and it looks like plain text...
    // AND we are sure it is not valid JSON (e.g. parsed failed).
    if (!contentUpdated) {
       // Only run fallback if original does NOT start with JSON brackets
       // ensuring we don't destroy unparsed JSON.
       String trimmed = note.content.trim();
       if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) {
          final List<String> lines = note.plainTextContent.split('\n');
          if (lineIndex < lines.length) {
            bool isDone = currentLine.toLowerCase().contains('[x]');
             String cleanText = currentLine.replaceAll(RegExp(r'- \[[ x]\] '), '').trim();
             String newLine = isDone ? "- [ ] $cleanText" : "- [x] $cleanText";
             lines[lineIndex] = newLine;
             newContent = lines.join('\n');
          }
       }
    }

    Provider.of<NotesProvider>(context, listen: false).updateNote(
      note.copyWith(content: newContent, updatedAt: DateTime.now())
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get Text Lines (Robust)
    final List<String> allLines = note.plainTextContent.split('\n');
    
    // 2. Determine Checked State per Line
    List<bool> checkedState = List.filled(allLines.length, false);
    
    try {
      // Decode JSON to extract attributes
      dynamic parsed = note.content;
      bool isJson = false;
      if (parsed is String) {
          String s = parsed.trim();
          if (s.startsWith('[') || s.startsWith('{')) {
             try {
               for (int i = 0; i < 3; i++) {
                 if (s is String && (s.startsWith('[') || s.startsWith('{'))) {
                   parsed = jsonDecode(s);
                   isJson = true;
                   if (parsed is String) s = parsed;
                 } else break;
               }
             } catch (_) {}
          }
      }

      if (isJson && parsed is List) {
         int currentLineIndex = 0;
         for (var op in parsed) {
           if (op is Map && op['insert'] is String) {
             String text = op['insert'];
             int newlines = '\n'.allMatches(text).length;
             
             // Check for checkbox attribute
             // Quill: attributes on '\n' apply to the line it terminates.
             bool isChecked = false;
             if (op.containsKey('attributes')) {
                var attrs = op['attributes'];
                if (attrs is Map && (attrs['list'] == 'checked' || attrs['checked'] == true)) {
                   isChecked = true;
                }
             }

             if (isChecked) {
                // Apply to all lines terminated by this op
                // Usually just one '\n' per such op, but loop to be safe
                for (int j = 0; j < newlines; j++) {
                   if (currentLineIndex + j < checkedState.length) {
                      checkedState[currentLineIndex + j] = true;
                   }
                }
             }
             currentLineIndex += newlines;
           }
         }
      }
    } catch (_) {}

    // 3. Merge with Markdown Style
    // If line explicitly has "- [x]", it overrides or is already true.
    for (int i = 0; i < allLines.length; i++) {
       if (allLines[i].toLowerCase().contains('- [x]')) {
         checkedState[i] = true;
       }
    }

    // 4. Build Display Items
    // Auto-detect checklist mode or force if attributes found
    bool hasMarkdown = allLines.any((l) => l.trim().startsWith('- ['));
    bool hasAttributes = checkedState.any((b) => b);
    
    List<int> itemIndices = [];
    for (int i = 0; i < allLines.length; i++) {
      if (allLines[i].trim().isEmpty) continue;
      
      // If we found rich text attributes, treat everything as potentially a list item?
      // Or only if we have Markdown marker?
      // Better strategy: If using Attributes, show all non-empty lines? 
      // Or only those with attributes?
      // User might have "Title" then "List".
      // Let's replicate strict filtering:
      // If hasMarkdown, show only "- [". 
      // If hasAttributes (Quill list), show lines that match list style?
      // Ideally show all lines that "look" like list items.
      
      if (hasMarkdown) {
         if (allLines[i].trim().startsWith('- [')) itemIndices.add(i);
      } else if (hasAttributes) {
         // If generic text with some checks, maybe show all?
         itemIndices.add(i);
      } else {
         // Fallback default: show all
         itemIndices.add(i);
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final bool isHabit = note.title.toLowerCase().contains('routine') || note.title.toLowerCase().contains('habit');
    final Color accentColor = textColor; // Monochrome

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: note.isPinned 
            ? Border.all(color: textColor.withOpacity(0.8), width: 4.0) 
            : (isDark ? Border.all(color: Colors.white24, width: 2.0) : Border.all(color: theme.dividerColor, width: 2.0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
                      Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.refresh, color: dimmedColor, size: 14)),
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
              children: itemIndices.take(5).map((index) {
                final line = allLines[index];
                // Correctly determine checked status from both sources
                final bool isDone = checkedState[index];
                
                // Clean text for display
                String cleanText = line.replaceAll(RegExp(r'- \[[ x]\] '), '').trim();
                // If it was attribute-checked, 'line' might allow be "Text", so cleanText is same.
                
                return GestureDetector(
                  onTap: () => _toggleItem(context, index, allLines[index]),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                          size: 22,
                          color: isDone ? accentColor : dimmedColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            cleanText,
                            style: TextStyle(
                              color: isDone ? dimmedColor : textColor,
                              fontSize: 15,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              decorationColor: dimmedColor,
                              height: 1.2,
                            ),
                            maxLines: 1,
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
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(24),
        border: note.isPinned 
            ? Border.all(color: textColor.withOpacity(0.8), width: 4.0) 
            : (isDark ? Border.all(color: Colors.white24, width: 2.0) : Border.all(color: theme.dividerColor, width: 2.0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Stack(
        children: [
             
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min, // FIX: Prevent grid crash
              children: [
                 Icon(Icons.format_quote, size: 30, color: textColor),
                 const SizedBox(height: 10),
                Text(
                  note.plainTextContent.replaceAll('"', '').trim(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(note.backgroundColor!),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: note.isPinned ? Colors.white.withOpacity(0.9) : Colors.white24, width: note.isPinned ? 4.0 : 2.0),
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
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.plainTextContent,
              style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 15),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.cardColor : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: note.isPinned 
            ? Border.all(color: textColor.withOpacity(0.8), width: 4.0) 
            : (isDark ? Border.all(color: Colors.white24, width: 2.0) : Border.all(color: theme.dividerColor, width: 2.0)),
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
                  style: TextStyle(fontWeight: FontWeight.w800, color: textColor, fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ],
          ),
          const SizedBox(height: 8),
          Text(
            note.plainTextContent,
            style: TextStyle(color: dimmedColor, height: 1.4, fontSize: 15),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
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
  const PolaroidWidget({super.key, required this.note, required this.imagePath});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(4),
        border: note.isPinned ? Border.all(color: Colors.black, width: 4.0) : null,
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [ // FIX: min size
          AspectRatio(aspectRatio: 1, child: Container(color: Colors.grey[200], child: Image.file(File(imagePath), fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.broken_image)))),
          const SizedBox(height: 10),
          Text(note.title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20), // Match GlassContainer default
        border: note.isPinned ? Border.all(color: Colors.white.withOpacity(0.8), width: 4.0) : null,
      ),
      child: GlassContainer(
        padding: const EdgeInsets.all(15),
        child: Column(mainAxisSize: MainAxisSize.min, children: [ // FIX: min size
          const Row(children: [Icon(CupertinoIcons.mic, color: Colors.white), SizedBox(width: 10), Text("Voice Note", style: TextStyle(color: Colors.white))]),
        ]),
      ),
    );
  }
}