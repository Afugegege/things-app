import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/note_model.dart';
import '../glass_container.dart';

class MosaicWidget extends StatelessWidget {
  final Note note;
  const MosaicWidget({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: note.isPinned ? Border.all(color: Colors.white.withOpacity(0.9), width: 4.0) : null,
      ),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            // Left: Image
            Expanded(
              flex: 1,
              child: note.backgroundImage != null
                  ? Image.file(File(note.backgroundImage!), fit: BoxFit.cover, height: double.infinity)
                  : Container(color: Colors.white10, child: const Icon(Icons.image)),
            ),
            // Right: Content
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? "Project" : note.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    const Text("Progress", style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}