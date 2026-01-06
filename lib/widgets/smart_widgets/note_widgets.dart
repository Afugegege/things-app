import 'dart:io';
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6200EA), Color(0xFF2962FF)], 
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2962FF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // FIX: Prevent grid crash
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(CupertinoIcons.airplane, color: Colors.white, size: 20),
              Text("${target.day}/${target.month}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text("$daysLeft", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.0)),
          const Text("DAYS LEFT", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(note.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
    final bool isDone = currentLine.toLowerCase().contains('[x]');
    final String cleanText = currentLine.replaceAll(RegExp(r'- \[[ x]\] '), '').trim();
    final String newLine = isDone ? "- [ ] $cleanText" : "- [x] $cleanText";

    final List<String> lines = note.plainTextContent.split('\n');
    if (lineIndex < lines.length) {
      lines[lineIndex] = newLine;
      final newContent = lines.join('\n');
      Provider.of<NotesProvider>(context, listen: false).updateNote(
        note.copyWith(content: newContent, updatedAt: DateTime.now())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> allLines = note.plainTextContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    
    // Auto-detect checklist mode
    bool hasMarkdown = allLines.any((l) => l.trim().startsWith('- ['));
    List<int> itemIndices = [];
    if (hasMarkdown) {
      for (int i = 0; i < allLines.length; i++) {
        if (allLines[i].trim().startsWith('- [')) itemIndices.add(i);
      }
    } else {
      for (int i = 0; i < allLines.length; i++) itemIndices.add(i);
    }

    final bool isHabit = note.title.toLowerCase().contains('routine') || note.title.toLowerCase().contains('habit');
    final Color accentColor = isHabit ? Colors.white : const Color(0xFF69F0AE);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // FIX: Prevent grid crash
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isHabit ? note.title.toUpperCase() : note.title, 
                  style: TextStyle(
                    color: isHabit ? Colors.white54 : Colors.white, 
                    fontSize: isHabit ? 12 : 16, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: isHabit ? 1.5 : 0.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isHabit) const Icon(Icons.refresh, color: Colors.white24, size: 16),
            ],
          ),
          const SizedBox(height: 15),
          
          if (itemIndices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text("Empty List", style: TextStyle(color: Colors.white24)),
            )
          else
            Column(
              children: itemIndices.take(5).map((index) {
                final line = allLines[index];
                final isDone = line.toLowerCase().contains('[x]');
                final text = line.replaceAll(RegExp(r'- \[[ x]\] '), '').trim();
                
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
                          color: isDone ? accentColor : Colors.white24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              color: isDone ? Colors.white38 : Colors.white.withOpacity(0.9),
                              fontSize: 15,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              decorationColor: Colors.white38,
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // FIX: Prevent grid crash
        children: [
          const Icon(Icons.format_quote, size: 30, color: Colors.amber),
          const SizedBox(height: 10),
          Text(
            note.plainTextContent.replaceAll('"', '').trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w500,
              fontFamily: 'Georgia',
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
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            note.title.isNotEmpty ? note.title : "Untitled",
            // [FIX]: Increased Font Size & Weight
            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            note.plainTextContent,
            // [FIX]: Increased Content Font Size
            style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 15),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
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
    return GlassContainer(
      padding: const EdgeInsets.all(15),
      child: Column(mainAxisSize: MainAxisSize.min, children: [ // FIX: min size
        const Row(children: [Icon(CupertinoIcons.mic, color: Colors.white), SizedBox(width: 10), Text("Voice Note", style: TextStyle(color: Colors.white))]),
      ]),
    );
  }
}