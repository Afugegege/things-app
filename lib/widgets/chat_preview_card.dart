import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import 'smart_widgets/widget_factory.dart';

class ChatPreviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onSave;
  final ValueChanged<String?> onEdit; // Changed to accept optional instruction

  const ChatPreviewCard({
    super.key,
    required this.data,
    required this.onSave,
    required this.onEdit,
    this.isSuccess = false,
  });

  final bool isSuccess;

  void _showRefineOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color;
        
        return Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
               const SizedBox(height: 20),
               Text("REFINE PREVIEW", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
               const SizedBox(height: 20),
               _refineOption(ctx, Icons.playlist_add, "Make it longer", "Expand on this with more details"),
               _refineOption(ctx, Icons.short_text, "Make it shorter", "Summarize this, make it more concise"),
               _refineOption(ctx, CupertinoIcons.wand_stars, "Rewrite / Improve", "Rewrite this to be more professional and clear"),
               _refineOption(ctx, Icons.translate, "Translate to Spanish", "Translate this to Spanish"),
               const Divider(),
               ListTile(
                 leading: Icon(Icons.keyboard, color: textColor),
                 title: Text("Custom Instruction...", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                 onTap: () { Navigator.pop(ctx); onEdit(null); } 
               ),
            ]
          )
        );
      }
    );
  }

  Widget _refineOption(BuildContext ctx, IconData icon, String label, String instruction) {
    final textColor = Theme.of(ctx).textTheme.bodyLarge?.color;
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(label, style: TextStyle(color: textColor)),
      onTap: () { Navigator.pop(ctx); onEdit(instruction); }
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Construct a temporary Note to visualize the data
    Note tempNote = Note(
      id: 'preview',
      title: data['title'] ?? 'Untitled',
      content: data['content'] ?? (data['append_content'] ?? ''),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: data['folder'] ?? 'Uncategorised',
    );
    
    if (data['action'] == 'edit_note' && data['append_content'] != null) {
        tempNote = tempNote.copyWith(
          title: "Appending to: ${data['search_title']}",
          content: data['append_content']
        );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
           color: isSuccess ? Colors.green.withOpacity(0.3) : Colors.blueAccent.withOpacity(0.5)
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
            child: Row(
              children: [
                Icon(
                  isSuccess ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.eye_fill, 
                  color: isSuccess ? Colors.green : Colors.blueAccent, 
                  size: 14
                ),
                const SizedBox(width: 6),
                Text(
                  isSuccess ? "CREATED" : "PREVIEW", 
                  style: TextStyle(
                    color: isSuccess ? Colors.green : Colors.blueAccent, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  )
                ),
                const Spacer(),
                if (data['action'] == 'create_note' && !isSuccess)
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
                if (!isSuccess) ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showRefineOptions(context),
                      icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 14, color: Colors.white70),
                      label: const Text("Refine...", style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white12),
                ],
                Expanded(
                  child: TextButton.icon(
                    onPressed: onSave,
                    icon: Icon(
                      isSuccess ? CupertinoIcons.arrow_right_circle_fill : CupertinoIcons.checkmark_alt, 
                      size: 14, 
                      color: isSuccess ? Colors.green : Colors.blueAccent
                    ),
                    label: Text(
                      isSuccess ? "Open Note" : "Confirm", 
                      style: TextStyle(
                        color: isSuccess ? Colors.green : Colors.blueAccent, 
                        fontWeight: FontWeight.bold
                      )
                    ),
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