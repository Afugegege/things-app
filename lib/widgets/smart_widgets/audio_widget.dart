import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/note_model.dart';
import '../glass_container.dart';

class AudioWidget extends StatelessWidget {
  final Note note;
  const AudioWidget({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min, // FIX: Wrap content
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Voice Note", style: Theme.of(context).textTheme.labelSmall),
              Text(
                "${note.updatedAt.hour}:${note.updatedAt.minute.toString().padLeft(2, '0')}",
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 15),
          // FIX: Removed Expanded, used fixed height container for visuals
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(10, (index) {
                return Container(
                  width: 4,
                  height: 10.0 + (index % 3 * 10) + (index % 2 * 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 15),
          // Controls
          Row(
            children: [
              Container(
                width: 35, height: 35,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.play_fill, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? "Audio Recording" : note.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                    ),
                    const Text("0:45", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}