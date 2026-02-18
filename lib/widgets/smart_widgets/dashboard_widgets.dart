import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';

// --- 1. STICKER WIDGET ---
// --- 1. STICKER WIDGET ---
class StickerWidget extends StatelessWidget {
  final Note note;
  const StickerWidget({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = theme.textTheme.bodyLarge?.color ?? Colors.black;
    
    Color bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    Color contentColor = Colors.amber; // Default vibrant color for stickers
    Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    
    if (note.backgroundColor != null && note.backgroundColor != 0) {
      bgColor = Color(note.backgroundColor!);
      // If color is present, assume white content is better usually, or we can check brightness.
      // For now, let's keep it simple or use the note's color as an accent if meaningful.
      // Actually, StickerWidget usually sets bg color.
      contentColor = Colors.white;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: note.isPinned 
            ? Border.all(color: textColor.withOpacity(0.8), width: 4.0) 
            : Border.all(color: note.backgroundColor != null && note.backgroundColor != 0 ? Colors.transparent : theme.dividerColor, width: 2),
      ),
      child: Stack(
        children: [

          
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.smiley, size: 48, color: contentColor),
                const SizedBox(height: 10),
                Text(
                  note.title.isNotEmpty ? note.title : "Sticker",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: note.backgroundColor != null && note.backgroundColor != 0 ? Colors.white : textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. MONITOR WIDGET (Simple Counter) ---
class MonitorWidget extends StatelessWidget {
  final Note note;
  const MonitorWidget({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    // Parse current value from content (default to 0)
    int value = 0;
    try {
      final textData = note.plainTextContent.trim();
      if (textData.isNotEmpty) {
        value = int.parse(textData);
      }
    } catch (_) {}

    Color bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    Color contentColor = textColor;
    Color iconColor = dimmedColor;
    
    if (note.backgroundColor != null && note.backgroundColor != 0) {
      bgColor = Color(note.backgroundColor!);
      contentColor = Colors.white;
      iconColor = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: note.isPinned 
            ? Border.all(color: textColor.withOpacity(0.8), width: 4.0) 
            : Border.all(color: note.backgroundColor != null && note.backgroundColor != 0 ? Colors.transparent : theme.dividerColor),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(CupertinoIcons.graph_circle, color: contentColor, size: 20),
                  Row(
                    children: [
                      Text("TRACKER", style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.bold)),

                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                note.title.isNotEmpty ? note.title : "Monitor",
                style: TextStyle(color: contentColor, fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _updateValue(context, value - 1),
                    icon: Icon(CupertinoIcons.minus_circle, color: iconColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Text(
                    "$value",
                    style: TextStyle(color: contentColor, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => _updateValue(context, value + 1),
                    icon: Icon(CupertinoIcons.plus_circle, color: iconColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateValue(BuildContext context, int newValue) {
    // We store the simple integer value in the 'content' field as JSON text or plain text
    final provider = Provider.of<NotesProvider>(context, listen: false);
    provider.updateNote(note.copyWith(
      content: newValue.toString(),
      updatedAt: DateTime.now()
    ));
  }
}

// --- 3. TIMER WIDGET ---
class TimerWidget extends StatefulWidget {
  final Note note;
  const TimerWidget({super.key, required this.note});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    // Try to load state if we were persisting it (persistence requires DB update on every tick which is bad)
    // For a simple widget, we'll keep it ephemeral or just store start time.
    // Using simple ephemeral timer for now.
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      _isRunning = !_isRunning;
    });

    if (_isRunning) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _seconds++;
          });
        }
      });
    } else {
      _timer?.cancel();
    }
  }

  void _resetTimer() {
    setState(() {
      _isRunning = false;
      _seconds = 0;
    });
    _timer?.cancel();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    Color bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    Color contentColor = textColor;
    Color iconColor = dimmedColor;
    
    if (widget.note.backgroundColor != null && widget.note.backgroundColor != 0) {
       bgColor = Color(widget.note.backgroundColor!);
       contentColor = Colors.white;
       iconColor = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: widget.note.isPinned 
            ? Border.all(color: textColor.withOpacity(0.8), width: 4.0) 
            : Border.all(color: widget.note.backgroundColor != null && widget.note.backgroundColor != 0 ? Colors.transparent : theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   Text(
                    widget.note.title.isNotEmpty ? widget.note.title : "Timer",
                    style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),

                ],
              ),
              Icon(CupertinoIcons.timer, color: iconColor, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formattedTime,
            style: TextStyle(
              color: contentColor,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(_isRunning ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid),
                color: contentColor, 
                iconSize: 32,
                onPressed: _toggleTimer,
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.restart),
                color: iconColor,
                iconSize: 24,
                onPressed: _resetTimer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
