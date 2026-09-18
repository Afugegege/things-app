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
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: note.isPinned
            ? Border.all(color: Colors.white, width: 2.0)
            : Border.all(color: Colors.white12, width: 1.0),
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
                  : Container(color: Colors.white10, child: const Icon(Icons.image, color: Colors.white70)),
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
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
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