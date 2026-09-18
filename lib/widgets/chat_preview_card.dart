import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/notes_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatPreviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onSave;
  final ValueChanged<String?> onEdit;

  const ChatPreviewCard({
    super.key,
    required this.data,
    required this.onSave,
    required this.onEdit,
    this.isSuccess = false,
  });

  final bool isSuccess;

  void _showRefineOptions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            color: cardBg,
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(CupertinoIcons.slider_horizontal_3, size: 16, color: textColor),
                    const SizedBox(width: 8),
                    Text(
                      "REFINE PREVIEW",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(CupertinoIcons.xmark_circle_fill,
                          color: secondaryColor.withOpacity(0.5), size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _refineOptionTile(ctx, CupertinoIcons.plus_circle, "Make it longer",
                    "Expand on this with more details and depth", isDark, textColor, secondaryColor),
                _refineOptionTile(ctx, CupertinoIcons.minus_circle, "Make it shorter",
                    "Summarize this and make it more concise", isDark, textColor, secondaryColor),
                _refineOptionTile(ctx, CupertinoIcons.wand_stars, "Rewrite & Improve",
                    "Enhance clarity, formatting, and overall tone", isDark, textColor, secondaryColor),
                _refineOptionTile(ctx, CupertinoIcons.globe, "Translate to Spanish",
                    "Translate this content to Spanish", isDark, textColor, secondaryColor),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
                _refineOptionTile(ctx, CupertinoIcons.textbox, "Custom Instruction...",
                    "Type specific editing instructions for AI", isDark, textColor, secondaryColor,
                    customOnTap: () {
                  Navigator.pop(ctx);
                  onEdit(null);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _refineOptionTile(
      BuildContext ctx, IconData icon, String label, String subtitle, bool isDark, Color textColor, Color secondaryColor,
      {VoidCallback? customOnTap}) {
    return GestureDetector(
      onTap: customOnTap ??
          () {
            Navigator.pop(ctx);
            onEdit(subtitle);
          },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: textColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: secondaryColor, fontSize: 11)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 12, color: secondaryColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    // 1. Construct a temporary Note to visualize the data
    Note tempNote = Note(
      id: 'preview',
      title: data['title'] ?? 'Untitled',
      content: data['content'] ?? (data['append_content'] ?? ''),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: data['folder'] ?? 'Uncategorised',
    );

    if (data['action'] == 'edit_note') {
      final searchTitle = (data['search_title'] ?? '').toString().toLowerCase();
      Note? matchingNote;
      try {
        final notesProv = Provider.of<NotesProvider>(context, listen: false);
        matchingNote = notesProv.notes.cast<Note?>().firstWhere(
          (n) => n != null && n.title.toLowerCase().contains(searchTitle),
          orElse: () => null,
        );
      } catch (_) {}

      final appendText = data['append_content'] ?? data['content'] ?? data['new_content'];
      if (appendText != null) {
        String existing = matchingNote?.plainTextContent.trim() ?? '';
        String addition = appendText.toString().trim();
        String fullPreviewText = existing.isEmpty
            ? addition
            : (existing.contains(addition) ? existing : '$existing\n$addition');

        tempNote = tempNote.copyWith(
          title: matchingNote != null ? matchingNote.title : "Updating: ${data['search_title']}",
          content: fullPreviewText,
        );
      }
    }

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isSuccess
        ? (isDark ? Colors.green.withOpacity(0.4) : Colors.green.withOpacity(0.3))
        : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER BAR ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? Colors.green.withValues(alpha: 0.15)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess
                        ? CupertinoIcons.checkmark_seal_fill
                        : CupertinoIcons.bolt_fill,
                    color: isSuccess ? Colors.green : textColor,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isSuccess ? "CREATED" : "AI PREVIEW",
                  style: TextStyle(
                    color: isSuccess ? Colors.green : textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                if (data['action'] == 'create_note' && !isSuccess)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "New Note",
                      style: TextStyle(color: secondaryColor, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          Container(
            height: 1,
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          ),

          // ── CONTENT PREVIEW ──
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tempNote.title.isNotEmpty && tempNote.title != "Untitled")
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        tempNote.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  MarkdownBody(
                    data: tempNote.content,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: textColor.withOpacity(0.88),
                        fontSize: 13,
                        height: 1.5,
                      ),
                      h1: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      h2: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      code: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── ACTIONS ROW ──
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                ),
              ),
            ),
            child: Row(
              children: [
                if (!isSuccess) ...[
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      minSize: 38,
                      onPressed: () => _showRefineOptions(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.slider_horizontal_3,
                              size: 13, color: secondaryColor),
                          const SizedBox(width: 6),
                          Text(
                            "Refine...",
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: isSuccess
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white : Colors.black),
                    borderRadius: BorderRadius.circular(14),
                    minSize: 38,
                    onPressed: onSave,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSuccess
                              ? CupertinoIcons.arrow_right_circle_fill
                              : CupertinoIcons.checkmark_alt,
                          size: 14,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSuccess ? "Open Note" : "Confirm",
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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
