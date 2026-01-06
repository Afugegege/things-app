import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import 'smart_widgets/widget_factory.dart';

class ChatPreviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onSave;
  final VoidCallback onEdit;

  const ChatPreviewCard({
    super.key,
    required this.data,
    required this.onSave,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Construct a temporary Note to visualize the data
    // This allows us to use the exact same Widget Factory logic as the Dashboard
    Note tempNote = Note(
      id: 'preview',
      title: data['title'] ?? 'Untitled',
      content: data['content'] ?? (data['append_content'] ?? ''),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: data['folder'] ?? 'Uncategorised',
    );
    
    // Handle Append Logic for Preview
    if (data['action'] == 'edit_note' && data['append_content'] != null) {
        tempNote = tempNote.copyWith(
          title: "Appending to: ${data['search_title']}",
          content: data['append_content']
        );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
            child: Row(
              children: [
                const Icon(CupertinoIcons.eye_fill, color: Colors.blueAccent, size: 14),
                const SizedBox(width: 6),
                const Text("PREVIEW", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (data['action'] == 'create_note')
                   const Text("New Note", style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          
          // The Mini Widget
          Container(
             constraints: const BoxConstraints(maxHeight: 150),
             child: SingleChildScrollView(
               physics: const NeverScrollableScrollPhysics(),
               child: IgnorePointer(
                 child: Transform.scale(
                   scale: 0.95,
                   child: WidgetFactory.build(context, tempNote),
                 ),
               ),
             ),
          ),

          // Actions
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(CupertinoIcons.pencil, size: 14, color: Colors.white70),
                    label: const Text("Refine", style: TextStyle(color: Colors.white70)),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onSave,
                    icon: const Icon(CupertinoIcons.checkmark_alt, size: 14, color: Colors.blueAccent),
                    label: const Text("Confirm", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}