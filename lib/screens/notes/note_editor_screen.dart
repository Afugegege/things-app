import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:dart_quill_delta/dart_quill_delta.dart' as dqd;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hand_signature/signature.dart';
import 'package:intl/intl.dart';

import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/ai_agent_sheet.dart';
import '../../widgets/smart_widgets/widget_factory.dart';
import '../../services/ai_service.dart';
import '../../utils/markdown_to_quill.dart'; // [ADDED] Markdown Parser
import '../../utils/diff_matcher.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final String? initialFolder;
  const NoteEditorScreen({super.key, this.note, this.initialFolder});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late quill.QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _pageScrollController = ScrollController();
  final HandSignatureControl _doodleControl = HandSignatureControl();

  final PageController _toolbarPageController = PageController();
  final int _currentToolbarPage = 0;
  bool _showToolbar = true;

  Color? _backgroundColor;
  String? _backgroundImagePath;
  String _currentThemeId = 'midnight';
  String _currentWidgetType = 'standard';



  double _savingsTarget = 10000.0;
  double _savingsCurrent = 3500.0;
  double _sleepHours = 7.5;

  String? _buttonLabel;
  String? _buttonLink;
  int? _buttonColor;

  String? _currentNoteId;
  DateTime? _createdAt;

  // Auto-Save State
  Timer? _autoSaveTimer;
  String? _saveStatus;
  double _fontSize = 17.0;

  // AI Preview & Selection State
  bool _isInAIPreview = false;
  bool _hasTextSelection = false;
  dqd.Delta? _prePreviewDocDelta;
  DiffTarget? _activeDiffTarget;

  @override
  void initState() {
    super.initState();
    _currentNoteId = widget.note?.id;
    _createdAt = widget.note?.createdAt;
    _loadNoteData();
    _setupEditor();

    _pageScrollController.addListener(() {
      if (_pageScrollController.hasClients) {
        if (_pageScrollController.position.userScrollDirection ==
            ScrollDirection.reverse) {
          if (_showToolbar) setState(() => _showToolbar = false);
        } else {
          if (!_showToolbar) setState(() => _showToolbar = true);
        }
      }
    });

    // SLASH COMMAND LISTENER
    _quillController.addListener(_checkForSlashCommand);

    // SELECTION LISTENER FOR AI FLOATING ACTIONS
    _quillController.addListener(_onSelectionChanged);

    // AUTO-SAVE LISTENER
    _quillController.changes.listen((event) {
      if (event.source == quill.ChangeSource.local) {
        _scheduleAutoSave();
      }
    });
  }

  void _onSelectionChanged() {
    if (_isInAIPreview) return;
    final selection = _quillController.selection;
    final hasSelection = !selection.isCollapsed && selection.end > selection.start;
    if (hasSelection != _hasTextSelection) {
      setState(() {
        _hasTextSelection = hasSelection;
      });
    }
  }

  @override
  void dispose() {
    if (_isInAIPreview && _prePreviewDocDelta != null) {
      _quillController.document = quill.Document.fromDelta(_prePreviewDocDelta!);
    }
    _quillController.removeListener(_onSelectionChanged);
    _quillController.removeListener(_checkForSlashCommand);
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _pageScrollController.dispose();
    _toolbarPageController.dispose();
    _doodleControl.dispose();
    super.dispose();
  }

  void _scheduleAutoSave() {
    if (_isInAIPreview) return; // Do not auto-save during AI preview diff review
    if (_saveStatus != "Saving...") {
      if (_saveStatus == null) {
        setState(() => _saveStatus = "Saving...");
      }
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () => _saveNote(false));
  }

  void _checkForSlashCommand() {
    final selection = _quillController.selection;
    if (!selection.isCollapsed) return;

    final text = _quillController.document.toPlainText();
    final index = selection.baseOffset;

    // Safety check for bounds
    if (index < 1 || index > text.length) return;

    final lastChar = text.substring(index - 1, index);
    if (lastChar == '/') {
      // Check proceeding character
      bool shouldTrigger = false;
      if (index == 1) {
        shouldTrigger = true; // Start of doc
      } else {
        final prevChar = text.substring(index - 2, index - 1);
        if (prevChar.trim().isEmpty) {
          // Whitespace or newline
          shouldTrigger = true;
        }
      }

      if (shouldTrigger) {
        _showSlashMenu();
      }
    }
  }

  void _showSlashMenu() {
    final index = _quillController.selection.baseOffset;
    _quillController.replaceText(index - 1, 1, '', null);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final itemBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * (isLandscape ? 0.85 : 0.6)),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Icon(CupertinoIcons.slash_circle,
                      size: 16, color: secondaryColor),
                  const SizedBox(width: 8),
                  Text("Insert block",
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
              ),
            ),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // ── BASIC BLOCKS ──
                  _slashSection("BASIC", secondaryColor),
                  _slashItem(
                      ctx,
                      CupertinoIcons.textformat_size,
                      "Heading 1",
                      "Big section heading",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.h1);
                  }),
                  _slashItem(
                      ctx,
                      CupertinoIcons.textformat,
                      "Heading 2",
                      "Medium section heading",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.h2);
                  }),
                  _slashItem(
                      ctx,
                      CupertinoIcons.checkmark_square,
                      "To-do list",
                      "Track tasks with checkboxes",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.unchecked);
                  }),
                  _slashItem(
                      ctx,
                      CupertinoIcons.list_bullet,
                      "Bulleted list",
                      "Simple bulleted list",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.ul);
                  }),
                  _slashItem(
                      ctx,
                      CupertinoIcons.list_number,
                      "Numbered list",
                      "List with numbers",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.ol);
                  }),
                  _slashItem(ctx, CupertinoIcons.text_quote, "Quote",
                      "Capture a quote", itemBg, textColor, secondaryColor, () {
                    _quillController
                        .formatSelection(quill.Attribute.blockQuote);
                  }),
                  _slashItem(
                      ctx,
                      CupertinoIcons.minus,
                      "Divider",
                      "Visual separator",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    final idx = _quillController.selection.baseOffset;
                    _quillController.replaceText(
                        idx, 0, const quill.BlockEmbed('divider', 'hr'), null);
                  }),

                  const SizedBox(height: 12),

                  // ── MEDIA ──
                  _slashSection("MEDIA", secondaryColor),
                  _slashItem(
                      ctx,
                      CupertinoIcons.photo,
                      "Image",
                      "Upload or embed an image",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _insertImage();
                  }),

                  const SizedBox(height: 12),

                  // ── AI ──
                  _slashSection("AI", secondaryColor),
                  _slashItem(
                      ctx,
                      CupertinoIcons.sparkles,
                      "Ask AI",
                      "Write, edit, or brainstorm with AI",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _openAIAgent();
                  }, isAI: true),
                  _slashItem(
                      ctx,
                      CupertinoIcons.arrow_right_circle,
                      "Continue writing",
                      "Let AI continue from here",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _openAIAgent(initialAction: 'continue');
                  }, isAI: true),
                  _slashItem(
                      ctx,
                      CupertinoIcons.doc_plaintext,
                      "Summarize",
                      "Summarize current note",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _openAIAgent(initialAction: 'summarize');
                  }, isAI: true),
                  _slashItem(
                      ctx,
                      CupertinoIcons.wand_stars,
                      "Style Note",
                      "Format structure & style",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _openAIAgent(initialAction: 'style');
                  }, isAI: true),
                  _slashItem(
                      ctx,
                      CupertinoIcons.tag_fill,
                      "Auto-Categorize Note",
                      "AI auto-detects folder & tags",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _autoCategorizeNoteWithAI();
                  }, isAI: true),

                  const SizedBox(height: 12),

                  // ── AI TEMPLATES ──
                  _slashSection("SMART TEMPLATES & WIDGETS", secondaryColor),
                  _slashItem(
                      ctx,
                      CupertinoIcons.airplane,
                      "Travel Itinerary",
                      "Live travel widget + flight, stay & packing list",
                      itemBg,
                      textColor,
                      secondaryColor, () {
                    _applyTemplate(
                      'travel',
                      'Tokyo Spring Trip',
                      '''# Tokyo Spring Trip 2026

> Destination: Tokyo, Japan | Dates: April 10 – April 18 #travel #vacation

### Flight & Accommodation
- [ ] **Flight**: JL 005 (Dep 09:30 AM)
- [ ] **Hotel**: Shibuya Excel Hotel Tokyu (Confirmation #88219)

### Packing Checklist
- [x] Passport & Visa documents
- [ ] Universal Power Adapter
- [ ] JR Rail Pass & Suica Card

### Daily Highlights
- **Day 1**: Arrive Haneda, Check in & Shibuya Crossing
- **Day 2**: Tsukiji Outer Market & Asakusa Sensoji Temple
- **Day 3**: Day trip to Mt. Fuji & Hakone Hot Springs''',
                    );
                  }, isAI: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slashSection(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }

  Widget _slashItem(
      BuildContext ctx,
      IconData icon,
      String title,
      String subtitle,
      Color bg,
      Color textColor,
      Color secondaryColor,
      VoidCallback onTap,
      {bool isAI = false}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isAI ? textColor.withOpacity(0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 17,
                  color: isAI ? textColor : textColor.withOpacity(0.6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: TextStyle(color: secondaryColor, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAIAgent({String? initialAction}) {
    // If currently in preview, discard first before opening
    if (_isInAIPreview) {
      _discardAIPreview();
    }

    // Get selected text if any
    String? selectedText;
    final selection = _quillController.selection;
    if (!selection.isCollapsed) {
      final plainText = _quillController.document.toPlainText();
      final start = selection.start.clamp(0, plainText.length);
      final end = selection.end.clamp(0, plainText.length);
      if (end > start) {
        selectedText = plainText.substring(start, end);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AIAgentSheet(
        currentContent: _quillController.document.toPlainText(),
        selectedText: selectedText,
        onPreviewEdit: (suggestedText, {targetText}) {
          _startAIPreview(suggestedText, targetText: targetText ?? selectedText);
        },
        onClearSelection: () {
          _quillController.updateSelection(
            TextSelection.collapsed(offset: _quillController.selection.baseOffset),
            quill.ChangeSource.local,
          );
          if (mounted) setState(() => _hasTextSelection = false);
        },
        onReplaceContent: (text) {
          _quillController.document = markdownToQuill(text);
          _saveNote(false);
        },
        onInsertContent: (text) {
          final idx = _quillController.selection.baseOffset;
          final insertIdx =
              idx >= 0 ? idx : _quillController.document.length - 1;

          // Build a delta: retain to cursor, then concat new content
          final composed = dqd.Delta();
          if (insertIdx > 0) composed.retain(insertIdx);
          final newDelta = markdownToQuill("\n$text\n").toDelta();
          composed.concat(newDelta);

          _quillController.compose(
              composed, _quillController.selection, quill.ChangeSource.local);
          _saveNote(false);
        },
        onReplaceSelection: selectedText != null
            ? (text) {
                final start = selection.start;
                final length = selection.end - selection.start;

                // Atomic delete + insert in a single delta to avoid selection/offset corruption
                var delta = dqd.Delta();
                if (start > 0) delta.retain(start);
                if (length > 0) delta.delete(length);
                delta = delta.concat(markdownToQuill(text).toDelta());
                _quillController.compose(
                    delta,
                    TextSelection.collapsed(offset: start),
                    quill.ChangeSource.local);

                _saveNote(false);
              }
            : null,
        initialAction: initialAction,
      ),
    );
  }

  // ── NOTION AI IN-EDITOR PREVIEW ENGINE ──

  void _startAIPreview(String suggestedText, {String? targetText}) {
    final docPlainText = _quillController.document.toPlainText();
    int start = 0;
    int length = 0;
    String originalText = '';

    // 1. Try explicit target / selection match
    if (targetText != null && targetText.trim().isNotEmpty) {
      final range = DiffMatcher.findBestMatchRange(docPlainText, targetText);
      if (range != null) {
        start = range.start;
        length = range.end - range.start;
        originalText = docPlainText.substring(start, range.end);
      }
    }

    // 2. Fallback to active selection if no match
    if (length == 0 && !_quillController.selection.isCollapsed) {
      final sel = _quillController.selection;
      start = sel.start.clamp(0, docPlainText.length);
      final end = sel.end.clamp(0, docPlainText.length);
      if (end > start) {
        length = end - start;
        originalText = docPlainText.substring(start, end);
      }
    }

    // 3. Fallback: if no target or selection was specified, AI is modifying the whole note
    if (length == 0) {
      start = 0;
      length = docPlainText.length;
      originalText = docPlainText;
    }

    final target = DiffTarget(
      start: start,
      length: length,
      originalText: originalText,
      suggestedText: suggestedText,
    );

    _prePreviewDocDelta = dqd.Delta.from(_quillController.document.toDelta());
    _activeDiffTarget = target;

    final previewDoc = DiffMatcher.buildPreviewDocument(
      originalDoc: _quillController.document,
      target: target,
    );

    setState(() {
      _quillController.document = previewDoc;
      _isInAIPreview = true;
      _hasTextSelection = false;
    });

    _showIOSToast(context, "Reviewing AI edit preview", CupertinoIcons.sparkles);
  }

  void _acceptAIPreview() {
    if (_prePreviewDocDelta == null || _activeDiffTarget == null) {
      setState(() => _isInAIPreview = false);
      return;
    }

    final committedDoc = DiffMatcher.buildCommittedDocument(
      prePreviewDelta: _prePreviewDocDelta!,
      target: _activeDiffTarget!,
    );

    setState(() {
      _quillController.document = committedDoc;
      _isInAIPreview = false;
      _prePreviewDocDelta = null;
      _activeDiffTarget = null;
    });

    _saveNote(false);
    _showIOSToast(context, "Changes applied", CupertinoIcons.checkmark_circle_fill);
  }

  void _discardAIPreview() {
    if (_prePreviewDocDelta != null) {
      _quillController.document = quill.Document.fromDelta(_prePreviewDocDelta!);
    }
    setState(() {
      _isInAIPreview = false;
      _prePreviewDocDelta = null;
      _activeDiffTarget = null;
    });
    _showIOSToast(context, "Changes discarded", CupertinoIcons.xmark_circle_fill);
  }

  void _repromptAIPreview() {
    final target = _activeDiffTarget;
    if (_prePreviewDocDelta != null) {
      _quillController.document = quill.Document.fromDelta(_prePreviewDocDelta!);
    }
    setState(() {
      _isInAIPreview = false;
      _prePreviewDocDelta = null;
      _activeDiffTarget = null;
    });

    if (target != null && target.length > 0) {
      _quillController.updateSelection(
        TextSelection(baseOffset: target.start, extentOffset: target.start + target.length),
        quill.ChangeSource.local,
      );
    }
    _openAIAgent();
  }

  void _rehighlightAIPreview() {
    final target = _activeDiffTarget;
    if (_prePreviewDocDelta != null) {
      _quillController.document = quill.Document.fromDelta(_prePreviewDocDelta!);
    }
    setState(() {
      _isInAIPreview = false;
      _prePreviewDocDelta = null;
      _activeDiffTarget = null;
    });

    if (target != null && target.length > 0) {
      _quillController.updateSelection(
        TextSelection(baseOffset: target.start, extentOffset: target.start + target.length),
        quill.ChangeSource.local,
      );
      _editorFocusNode.requestFocus();
      _showIOSToast(context, "Selection restored for editing", CupertinoIcons.selection_pin_in_out);
    }
  }

  // ── FLOATING UI FOR SELECTION & PREVIEW ──

  Widget _buildFloatingSelectionAIPill(
      bool isEffectiveBgDark, Color textColor) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 50;
    final toolbarHeight = isLandscape ? 46.0 : 60.0;
    final toolbarBottom = isLandscape ? 8.0 : 28.0;

    final double bottomPosition;
    if (keyboardOpen) {
      bottomPosition = MediaQuery.of(context).viewInsets.bottom + 14;
    } else if (_showToolbar) {
      bottomPosition = toolbarBottom + toolbarHeight + 14;
    } else {
      bottomPosition = isLandscape ? 12 : 28;
    }

    return Positioned(
      bottom: bottomPosition,
      left: 20,
      right: 20,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isEffectiveBgDark
                    ? const Color(0xFF1E1E22).withOpacity(0.92)
                    : Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isEffectiveBgDark
                      ? Colors.white.withOpacity(0.16)
                      : Colors.black.withOpacity(0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main "Ask AI" pill
                    GestureDetector(
                      onTap: () => _openAIAgent(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isEffectiveBgDark
                              ? Colors.white
                              : const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.sparkles,
                                size: 13,
                                color: isEffectiveBgDark ? Colors.black : Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              "Ask AI",
                              style: TextStyle(
                                color: isEffectiveBgDark ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _selectionQuickChip(
                      _isHighlightActive() ? "Unhighlight" : "Highlight",
                      () => _toggleHighlight(isEffectiveBgDark),
                      isEffectiveBgDark,
                      textColor,
                    ),
                    const SizedBox(width: 5),
                    _selectionQuickChip("Deselect", () {
                      _quillController.updateSelection(
                        TextSelection.collapsed(offset: _quillController.selection.extentOffset),
                        quill.ChangeSource.local,
                      );
                      _quillController.formatSelection(const quill.BackgroundAttribute(null));
                    }, isEffectiveBgDark, textColor),
                    const SizedBox(width: 5),
                    _selectionQuickChip("Improve", () => _openAIAgent(initialAction: 'improve'),
                        isEffectiveBgDark, textColor),
                    const SizedBox(width: 5),
                    _selectionQuickChip("Fix", () => _openAIAgent(initialAction: 'fix_grammar'),
                        isEffectiveBgDark, textColor),
                    const SizedBox(width: 5),
                    _selectionQuickChip("Shorten", () => _openAIAgent(initialAction: 'shorter'),
                        isEffectiveBgDark, textColor),
                    const SizedBox(width: 5),
                    _selectionQuickChip("Tone", () => _openAIAgent(initialAction: 'professional'),
                        isEffectiveBgDark, textColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectionQuickChip(
      String label, VoidCallback onTap, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.9),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPreviewReviewDock(
      bool isEffectiveBgDark, Color textColor) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Positioned(
      bottom: isLandscape ? 12 : 28,
      left: isLandscape ? 40 : 16,
      right: isLandscape ? 40 : 16,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(maxWidth: isLandscape ? 560 : 440),
              decoration: BoxDecoration(
                color: isEffectiveBgDark
                    ? const Color(0xFF1C1C1E).withOpacity(0.95)
                    : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isEffectiveBgDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.black.withOpacity(0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Label + Sparkle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: isEffectiveBgDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.sparkles,
                              size: 13,
                              color: isEffectiveBgDark ? Colors.white : Colors.black),
                          const SizedBox(width: 4),
                          Text(
                            "AI Edit",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isEffectiveBgDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Re-highlight / Re-select button
                    _reviewActionBtn(
                      label: "Re-select",
                      icon: CupertinoIcons.selection_pin_in_out,
                      onTap: _rehighlightAIPreview,
                      isDark: isEffectiveBgDark,
                      textColor: textColor,
                    ),
                    const SizedBox(width: 5),

                    // Reprompt button
                    _reviewActionBtn(
                      label: "Adjust",
                      icon: CupertinoIcons.slider_horizontal_3,
                      onTap: _repromptAIPreview,
                      isDark: isEffectiveBgDark,
                      textColor: textColor,
                    ),
                    const SizedBox(width: 5),

                    // Discard button
                    _reviewActionBtn(
                      label: "Discard",
                      icon: CupertinoIcons.xmark,
                      onTap: _discardAIPreview,
                      isDark: isEffectiveBgDark,
                      textColor: const Color(0xFFFF453A),
                      isDestructive: true,
                    ),
                    const SizedBox(width: 8),

                    // Accept (Primary)
                    GestureDetector(
                      onTap: _acceptAIPreview,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isEffectiveBgDark ? Colors.white : const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: (isEffectiveBgDark ? Colors.white : Colors.black).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.checkmark_alt,
                                size: 13,
                                color: isEffectiveBgDark ? Colors.black : Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              "Accept",
                              style: TextStyle(
                                color: isEffectiveBgDark ? Colors.black : Colors.white,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewActionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color textColor,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFFF453A).withOpacity(0.12)
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFFF453A).withOpacity(0.25)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIOSToast(BuildContext context, String message, IconData iconData) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: (Theme.of(ctx).brightness == Brightness.dark
                            ? const Color(0xFF1C1C1E)
                            : Colors.black)
                        .withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconData, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 2200), () {
      overlayEntry.remove();
    });
  }

  Future<void> _autoCategorizeNoteWithAI() async {
    final title = _titleController.text;
    final content = _quillController.document.toPlainText();
    final notesProv = Provider.of<NotesProvider>(context, listen: false);
    final aiService = AiService();

    _showIOSToast(context, "AI Auto-Categorizing Note...", CupertinoIcons.sparkles);

    final res = await aiService.autoCategorizeNote(
      title: title,
      content: content,
      availableFolders: notesProv.folders,
    );

    final String folder = res['folder'] ?? 'General';
    final List tags = res['tags'] ?? [];

    if (tags.isNotEmpty) {
      final String tagStr = "\n\n${tags.join(' ')}";
      final insertDelta = dqd.Delta();
      insertDelta.retain(_quillController.document.length - 1);
      insertDelta.insert(tagStr);
      _quillController.compose(insertDelta, _quillController.selection, quill.ChangeSource.local);
    }

    _saveNote(false);

    _showIOSToast(context, "AI Categorized note to '$folder'", CupertinoIcons.tag_fill);
  }

  void _applyTemplate(String type, String title, String markdownTemplate) {
    setState(() {
      _currentWidgetType = type;
      if (_titleController.text.trim().isEmpty || _titleController.text == 'Untitled Note') {
        _titleController.text = title;
      }
    });

    final parsedDoc = markdownToQuill(markdownTemplate);
    _quillController.document = parsedDoc;
    _saveNote(false);

    _showIOSToast(context, "Applied $title Template & Widget", CupertinoIcons.sparkles);
  }

  void _setupEditor() {
    if (widget.note?.content == null || widget.note!.content.isEmpty) {
      _quillController = quill.QuillController.basic();
      return;
    }

    String contentToLoad = widget.note!.content;

    // RECURSIVE UNWRAP: Check if the content is "baked" JSON (double-encoded)
    // Sometimes a note's text is literally the JSON string "[{\"insert\":\"...\"}]"
    // We try to unwrap this up to 3 times to find the real content.
    for (int i = 0; i < 3; i++) {
      try {
        if (contentToLoad.trim().startsWith('[') &&
            contentToLoad.contains('insert')) {
          final List<dynamic> json = jsonDecode(contentToLoad);
          // Check if this is a single-element list containing a JSON string
          if (json.isNotEmpty &&
              json.length == 1 &&
              json[0] is Map &&
              json[0]['insert'] is String) {
            final String innerText = json[0]['insert'].trim();
            if (innerText.startsWith('[') && innerText.contains('"insert"')) {
              // It looks like JSON! Unwrap it.
              contentToLoad = innerText;
              continue;
            }
          }
        }
      } catch (_) {}
      break; // Stop if not unwrappable
    }

    // Now try to load the unwrapped content
    try {
      if (contentToLoad.trim().startsWith('[')) {
        final List<dynamic> jsonContent = jsonDecode(contentToLoad);
        // Validate newline for Quill
        if (jsonContent.isNotEmpty) {
          final lastOp = jsonContent.last;
          if (lastOp is Map<String, dynamic>) {
            final insertVal = lastOp['insert'];
            if (insertVal is String && !insertVal.endsWith('\n')) {
              jsonContent.last = {'insert': '$insertVal\n'};
            }
          }
        }
        final doc = quill.Document.fromJson(jsonContent);
        _quillController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        return;
      }
    } catch (e) {
      debugPrint('Quill parse failed: $e');
    }

    // Fallback: If it STILL looks like JSON code, try to force-extract text
    // to avoid showing raw code to the user.
    String fallbackText = contentToLoad;
    try {
      if (fallbackText.trim().startsWith('[')) {
        final List<dynamic> ops = jsonDecode(fallbackText);
        final buffer = StringBuffer();
        for (final op in ops) {
          if (op is Map && op['insert'] is String) buffer.write(op['insert']);
        }
        if (buffer.isNotEmpty) fallbackText = buffer.toString();
      }
    } catch (_) {}

    final doc = quill.Document()..insert(0, fallbackText);
    _quillController = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _loadNoteData() {
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _backgroundColor = widget.note?.backgroundColor != null
        ? Color(widget.note!.backgroundColor!)
        : null;
    _backgroundImagePath = widget.note?.backgroundImage;
    _buttonLabel = widget.note?.buttonLabel;
    _buttonLink = widget.note?.buttonLink;
    _buttonColor = widget.note?.buttonColor;
    _currentThemeId = widget.note?.themeId ?? 'midnight';
    _fontSize = widget.note?.fontSize ?? 17.0;
    _currentWidgetType = widget.note?.widgetType ?? 'standard';
  }

  void _saveNote([bool close = true]) {
    if (_isInAIPreview) {
      if (close && mounted) {
        _discardAIPreview();
        Navigator.pop(context);
      }
      return;
    }
    _autoSaveTimer?.cancel();
    final title = _titleController.text.trim();
    final String plainText = _quillController.document.toPlainText().trim();
    final bool isEmpty =
        title.isEmpty && plainText.isEmpty && _backgroundImagePath == null;

    if (_currentNoteId == null && isEmpty) {
      if (!close && mounted) setState(() => _saveStatus = null);
      if (close && mounted) Navigator.pop(context);
      return;
    }

    final contentJson =
        jsonEncode(_quillController.document.toDelta().toJson());
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    // Determine ID
    _currentNoteId ??= const Uuid().v4();

    // Determine CreatedAt
    _createdAt ??= DateTime.now();

    final noteToSave = Note(
      id: _currentNoteId!,
      title: title.isEmpty ? "Untitled" : title,
      content: contentJson,
      createdAt: _createdAt!,
      updatedAt: DateTime.now(),
      backgroundColor: _backgroundColor?.value,
      backgroundImage: _backgroundImagePath,
      buttonLabel: _buttonLabel,
      buttonLink: _buttonLink,
      buttonColor: _buttonColor,
      themeId: _currentThemeId,
      widgetType: _currentWidgetType,
      folder: widget.note?.folder ?? widget.initialFolder ?? 'All',
      fontSize: _fontSize,
      isExpanded: widget.note?.isExpanded ?? false,
    );

    // efficient existence check
    final exists = notesProvider.notes.any((n) => n.id == _currentNoteId);

    if (exists) {
      notesProvider.updateNote(noteToSave);
    } else {
      notesProvider.addNote(noteToSave);
    }

    if (!close && mounted) {
      setState(() => _saveStatus = "Saved");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _saveStatus == "Saved") {
          setState(() => _saveStatus = null);
        }
      });
    }

    if (close && mounted) Navigator.pop(context);
  }

  // --- SPECIALIZED CONTEXT EDITORS ---

  Widget _buildSpecializedContextEditor(BuildContext context, bool isDark, Color textColor, Color secondaryColor) {
    switch (_currentWidgetType) {
      case 'savings_goal':
        return _buildSavingsGoalEditorView(isDark, textColor, secondaryColor);
      case 'sleep_energy':
        return _buildSleepEnergyEditorView(isDark, textColor, secondaryColor);
      default:
        return const SizedBox.shrink();
    }
  }

  // 5. SAVINGS GOAL EDITOR VIEW
  Widget _buildSavingsGoalEditorView(bool isDark, Color textColor, Color secondaryColor) {
    final pct = (_savingsTarget > 0 ? (_savingsCurrent / _savingsTarget) : 0.0).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      child: Column(
        children: [
          GlassContainer(
            borderRadius: 28,
            opacity: isDark ? 0.15 : 0.85,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(CupertinoIcons.money_dollar_circle_fill, color: textColor, size: 40),
                const SizedBox(height: 12),
                Text("\$${_savingsCurrent.toStringAsFixed(2)} / \$${_savingsTarget.toStringAsFixed(2)}", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: isDark ? Colors.white12 : Colors.black12, valueColor: AlwaysStoppedAnimation(textColor)),
                ),
                const SizedBox(height: 8),
                Text("${(pct * 100).toStringAsFixed(1)}% Achieved", style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08),
              foregroundColor: textColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
            ),
            onPressed: () => setState(() => _savingsCurrent += 100),
            icon: Icon(CupertinoIcons.add, color: textColor),
            label: Text("Deposit \$100 Now", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 6. SLEEP ENERGY EDITOR VIEW
  Widget _buildSleepEnergyEditorView(bool isDark, Color textColor, Color secondaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      child: Column(
        children: [
          GlassContainer(
            borderRadius: 28,
            opacity: isDark ? 0.15 : 0.85,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(CupertinoIcons.moon_stars_fill, color: textColor, size: 40),
                const SizedBox(height: 12),
                Text("${_sleepHours.toStringAsFixed(1)} Hours Slept", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: Icon(CupertinoIcons.minus_circle_fill, color: textColor, size: 28), onPressed: () => setState(() => _sleepHours = (_sleepHours - 0.5).clamp(0, 24))),
                    const SizedBox(width: 20),
                    IconButton(icon: Icon(CupertinoIcons.plus_circle_fill, color: textColor, size: 28), onPressed: () => setState(() => _sleepHours = (_sleepHours + 0.5).clamp(0, 24))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(String label, String hint, String value, Function(String) onChanged, Color textColor, Color bg, Color border) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.6))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: TextFormField(
            initialValue: value,
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: InputDecoration(hintText: hint, border: InputBorder.none, isDense: true),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildWidgetSelectorBar(Color textColor, bool isDark) {
    final widgetsList = [
      {'type': 'standard', 'label': 'Text Only', 'icon': CupertinoIcons.doc_text_fill},
      {'type': 'checklist', 'label': 'Checklist', 'icon': CupertinoIcons.checkmark_square},
      {'type': 'travel', 'label': 'Travel', 'icon': CupertinoIcons.airplane},
      {'type': 'savings_goal', 'label': 'Savings Goal', 'icon': CupertinoIcons.money_dollar_circle_fill},
      {'type': 'sleep_energy', 'label': 'Sleep Log', 'icon': CupertinoIcons.moon_stars_fill},
      {'type': 'sticker', 'label': 'Sticker', 'icon': CupertinoIcons.pin_fill},
      {'type': 'quote', 'label': 'Quote', 'icon': CupertinoIcons.quote_bubble_fill},
      {'type': 'timer', 'label': 'Timer', 'icon': CupertinoIcons.timer},
    ];

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      height: isLandscape ? 32 : 36,
      margin: EdgeInsets.only(bottom: isLandscape ? 4 : 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widgetsList.length,
        itemBuilder: (ctx, i) {
          final w = widgetsList[i];
          final isSelected = _currentWidgetType == w['type'];
          final iconData = w['icon'] as IconData;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentWidgetType = w['type'] as String;
              });
              _saveNote(false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.85))
                    : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? textColor.withOpacity(0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, size: 13, color: isSelected ? Colors.white : textColor.withOpacity(0.8)),
                  const SizedBox(width: 6),
                  Text(
                    w['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showWidgetPickerSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryColor = isDark ? Colors.white60 : Colors.black54;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final widgetsList = [
      {'type': 'standard', 'label': 'Text Only', 'icon': CupertinoIcons.doc_text_fill, 'desc': 'Standard rich text editor'},
      {'type': 'checklist', 'label': 'Interactive Checklist', 'icon': CupertinoIcons.checkmark_square, 'desc': 'Interactive to-do list with checkable items'},
      {'type': 'savings_goal', 'label': 'Savings Goal Tracker', 'icon': CupertinoIcons.money_dollar_circle_fill, 'desc': 'Target savings & deposit log'},
      {'type': 'sleep_energy', 'label': 'Sleep & Energy Log', 'icon': CupertinoIcons.moon_stars_fill, 'desc': 'Sleep hours & energy bolts'},
      {'type': 'sticker', 'label': 'Sticker Pin', 'icon': CupertinoIcons.pin_fill, 'desc': 'Decorative note sticker'},
      {'type': 'quote', 'label': 'Quote Banner', 'icon': CupertinoIcons.quote_bubble_fill, 'desc': 'Inspirational quote card'},
      {'type': 'timer', 'label': 'Focus Timer', 'icon': CupertinoIcons.timer, 'desc': 'Countdown focus timer'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * (isLandscape ? 0.85 : 0.7)),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withOpacity(0.88),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: secondaryColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Text("SMART WIDGET MODE", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1)),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 24,
                        onPressed: () => Navigator.pop(ctx),
                        child: Icon(CupertinoIcons.xmark_circle_fill, size: 22, color: secondaryColor),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widgetsList.length,
                    itemBuilder: (context, i) {
                      final w = widgetsList[i];
                      final isSelected = _currentWidgetType == w['type'];
                      final iconData = w['icon'] as IconData;

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _currentWidgetType = w['type'] as String;
                          });
                          _saveNote(false);
                          _showIOSToast(context, "Switched to ${w['label']}", iconData);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08))
                                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? textColor.withOpacity(0.6) : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(iconData, color: textColor, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(w['label'] as String, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(w['desc'] as String, style: TextStyle(color: secondaryColor, fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(CupertinoIcons.checkmark_circle_fill, color: textColor, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- THEME LOGIC ---

  BoxDecoration _getThemeDecoration(BuildContext context) {
    if (_backgroundImagePath != null) {
      return BoxDecoration(
        image: DecorationImage(
            image: FileImage(File(_backgroundImagePath!)), fit: BoxFit.cover),
      );
    }

    switch (_currentThemeId) {
      case 'cyber':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'paper':
        return const BoxDecoration(color: Color(0xFFF5F5DC));
      case 'midnight':
      default:
        return BoxDecoration(
            color:
                _backgroundColor ?? Theme.of(context).scaffoldBackgroundColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final accentColor = userProvider.accentColor;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    Color effectiveBgColor = _backgroundColor ?? theme.scaffoldBackgroundColor;
    if (_currentThemeId == 'cyber') {
      effectiveBgColor = const Color(0xFF0f0c29);
    } else if (_currentThemeId == 'paper') {
      effectiveBgColor = const Color(0xFFF5F5DC);
    }

    final bool isEffectiveBgDark = _backgroundImagePath != null 
        ? true 
        : ThemeData.estimateBrightnessForColor(effectiveBgColor) == Brightness.dark;

    final Color textColor = isEffectiveBgDark ? Colors.white : Colors.black87;
    final Color effectiveAccent = isEffectiveBgDark ? Colors.white : Colors.black;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // 1. BACKGROUND
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: _getThemeDecoration(context),
              ),
            ),

            // 2. EDITOR AREA
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: isLandscape ? 58 : 96), // Dynamic Space for Header

                  // Title
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 24, vertical: isLandscape ? 4 : 10),
                    child: TextField(
                      controller: _titleController,
                      style: TextStyle(
                          fontSize: isLandscape ? 22 : 28,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          fontFamily: isDark ? 'Courier' : null,
                          letterSpacing: -0.5),
                      decoration: InputDecoration(
                          hintText: "Untitled Note",
                          hintStyle:
                              TextStyle(color: textColor.withOpacity(0.4)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero),
                    ),
                  ),

                  // Smart Link Button (if exists)
                  if (_buttonLabel != null && _buttonLink != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SmartButton(
                            label: _buttonLabel!,
                            link: _buttonLink!,
                            colorValue: _buttonColor!),
                      ),
                    ),

                  // Rich Text Editor
                  Expanded(
                    child: quill.QuillEditor.basic(
                      controller: _quillController,
                      scrollController: _pageScrollController,
                      focusNode: _editorFocusNode,
                      configurations: quill.QuillEditorConfigurations(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          isLandscape ? 4 : 0,
                          24,
                          bottomInset > 0
                              ? bottomInset + 140
                              : (isLandscape ? 60 : 160),
                        ),
                        autoFocus: false,
                        expands: true,
                        placeholder: "Start typing...",
                        onTapUp: (details, getPosition) {
                          if (!_quillController.selection.isCollapsed) {
                            final pos = getPosition(details.localPosition);
                            _quillController.updateSelection(
                              TextSelection.collapsed(offset: pos.offset),
                              quill.ChangeSource.local,
                            );
                            return true;
                          }
                          return false;
                        },
                        onTapDown: (details, getPosition) {
                          if (!_quillController.selection.isCollapsed) {
                            final pos = getPosition(details.localPosition);
                            _quillController.updateSelection(
                              TextSelection.collapsed(offset: pos.offset),
                              quill.ChangeSource.local,
                            );
                            return true;
                          }
                          return false;
                        },
                        onTapOutside: (event, focusNode) {
                          if (!_quillController.selection.isCollapsed) {
                            _quillController.updateSelection(
                              TextSelection.collapsed(
                                  offset: _quillController.selection.extentOffset),
                              quill.ChangeSource.local,
                            );
                          }
                        },
                        embedBuilders:
                            kIsWeb ? null : FlutterQuillEmbeds.editorBuilders(),
                        customStyles: quill.DefaultStyles(
                          paragraph: quill.DefaultTextBlockStyle(
                              TextStyle(
                                  color: textColor,
                                  fontSize: _fontSize,
                                  height: 1.6),
                              const quill.HorizontalSpacing(0, 0),
                              const quill.VerticalSpacing(0, 0),
                              const quill.VerticalSpacing(0, 0),
                              null),
                          h1: quill.DefaultTextBlockStyle(
                              TextStyle(
                                  color: textColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2),
                              const quill.HorizontalSpacing(0, 0),
                              const quill.VerticalSpacing(16, 0),
                              const quill.VerticalSpacing(0, 0),
                              null),
                          h2: quill.DefaultTextBlockStyle(
                              TextStyle(
                                  color: textColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600),
                              const quill.HorizontalSpacing(0, 0),
                              const quill.VerticalSpacing(16, 0),
                              const quill.VerticalSpacing(0, 0),
                              null),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. FROSTY GLASS HEADER (iOS Style)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: _backgroundImagePath != null
                      ? ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                      : ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: isLandscape ? 54 : 90, // Dynamic height for orientation
                    padding: EdgeInsets.only(
                        top: isLandscape ? 4 : MediaQuery.of(context).padding.top),
                    decoration: BoxDecoration(
                        color: (isEffectiveBgDark ? Colors.black : Colors.white)
                            .withOpacity(isEffectiveBgDark ? 0.3 : 0.85),
                        border: Border(
                            bottom: BorderSide(
                                color: isEffectiveBgDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.08)))),
                    child: NavigationToolbar(
                      leading: Padding(
                        padding: const EdgeInsets.only(left: 4.0, right: 4.0),
                        child: _headerBtn(
                            CupertinoIcons.back, () => _saveNote(), textColor),
                      ),
                      middle: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _headerBtn(CupertinoIcons.arrow_turn_up_left,
                              () => _quillController.undo(), textColor),
                          const SizedBox(width: 4),
                          _headerBtn(CupertinoIcons.arrow_turn_up_right,
                              () => _quillController.redo(), textColor),
                        ],
                      ),
                      trailing: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _headerBtn(
                                CupertinoIcons.share,
                                () => Share.share(
                                    _quillController.document.toPlainText()),
                                textColor),
                            // AI Button - Modern iOS Monochrome Style
                            GestureDetector(
                              onTap: _openAIAgent,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isLandscape ? 8 : 12, vertical: isLandscape ? 4 : 8),
                                decoration: BoxDecoration(
                                  color: textColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: textColor.withOpacity(0.12)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.sparkles,
                                        size: isLandscape ? 11 : 13, color: textColor),
                                    const SizedBox(width: 4),
                                    Text("AI",
                                        style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: isLandscape ? 11 : 13)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (_saveStatus != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(_saveStatus!,
                                    style: TextStyle(
                                        color: effectiveAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            // Save Button covering accent color request
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _saveNote,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isLandscape ? 10 : 14, vertical: isLandscape ? 4 : 8),
                                decoration: BoxDecoration(
                                  color: effectiveAccent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Save",
                                  style: TextStyle(
                                    color: isEffectiveBgDark
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isLandscape ? 11 : 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 4. FLOATING FROSTY TOOLBAR (Dock Style - hidden during AI diff preview)
            if (!_isInAIPreview && _showToolbar && MediaQuery.of(context).viewInsets.bottom < 100)
              Positioned(
                bottom: isLandscape ? 8 : 28,
                left: isLandscape ? 40 : 20,
                right: isLandscape ? 40 : 20,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 6 : 10, vertical: isLandscape ? 2 : 5),
                        constraints: BoxConstraints(maxWidth: isLandscape ? 480 : 400),
                        decoration: BoxDecoration(
                            color: isEffectiveBgDark
                                ? const Color(0xFF1C1C1E).withOpacity(0.90)
                                : Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: isEffectiveBgDark
                                    ? Colors.white.withOpacity(0.18)
                                    : Colors.black.withOpacity(0.12)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(isEffectiveBgDark ? 0.3 : 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8))
                            ]),
                        height: isLandscape ? 46 : 60,
                        child: PageView(
                          controller: _toolbarPageController,
                          children: [
                            // FORMATTING DOCK (Page 1: Basic Tools)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _dockBtn(quill.Attribute.bold,
                                    CupertinoIcons.bold, effectiveAccent, isEffectiveBgDark,
                                    isActive:
                                        _isAttrActive(quill.Attribute.bold)),
                                _dockBtn(quill.Attribute.italic,
                                    CupertinoIcons.italic, effectiveAccent, isEffectiveBgDark,
                                    isActive:
                                        _isAttrActive(quill.Attribute.italic)),
                                _dockBtn(quill.Attribute.h1, Icons.title,
                                    effectiveAccent, isEffectiveBgDark,
                                    isActive:
                                        _isAttrActive(quill.Attribute.h1)),
                                _dockBtn(quill.Attribute.ul,
                                    CupertinoIcons.list_bullet, effectiveAccent, isEffectiveBgDark,
                                    isActive:
                                        _isAttrActive(quill.Attribute.ul)),
                                _dockBtn(
                                    quill.Attribute.unchecked,
                                    CupertinoIcons.checkmark_rectangle,
                                    effectiveAccent, isEffectiveBgDark,
                                    isActive: _isAttrActive(
                                        quill.Attribute.unchecked)),
                                _highlightBtn(isEffectiveBgDark),
                                _fontSizeBtn(effectiveAccent, textColor, isEffectiveBgDark),
                                IconButton(
                                    icon: Icon(
                                        CupertinoIcons
                                            .chevron_right_circle_fill,
                                        color: isEffectiveBgDark ? Colors.white60 : Colors.black45),
                                    onPressed: () =>
                                        _toolbarPageController.nextPage(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.ease))
                              ],
                            ),
                            // MEDIA DOCK (Page 2: Media & Theme)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                    icon: Icon(
                                        CupertinoIcons.chevron_left_circle_fill,
                                        color: isEffectiveBgDark ? Colors.white60 : Colors.black45),
                                    onPressed: () =>
                                        _toolbarPageController.previousPage(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.ease)),
                                // Use Accent Color for main media entry points
                                _mediaBtn(CupertinoIcons.photo, effectiveAccent, isEffectiveBgDark,
                                    _insertImage),
                                _mediaBtn(CupertinoIcons.paintbrush_fill,
                                    effectiveAccent, isEffectiveBgDark, _showThemePicker),
                                _mediaBtn(CupertinoIcons.textformat_size,
                                    effectiveAccent, isEffectiveBgDark, _showFontSizePicker),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 5. FLOATING SELECTION AI PILL (When text is highlighted)
            if (!_isInAIPreview && _hasTextSelection)
              _buildFloatingSelectionAIPill(isEffectiveBgDark, textColor),

            // 6. FLOATING NOTION-STYLE DIFF REVIEW DOCK (When previewing AI edit)
            if (_isInAIPreview)
              _buildFloatingPreviewReviewDock(isEffectiveBgDark, textColor),
          ],
        ));
  }

  // --- NEW WIDGET HELPERS ---

  Widget _headerBtn(IconData icon, VoidCallback onTap, Color color) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
      minimumSize: const Size(30, 30),
    );
  }

  bool _isAttrActive(quill.Attribute attr) {
    final style = _quillController.getSelectionStyle();
    return style.attributes.containsKey(attr.key) &&
        style.attributes[attr.key]!.value == attr.value;
  }

  bool _isHighlightActive() {
    final style = _quillController.getSelectionStyle();
    return style.attributes.containsKey(quill.Attribute.background.key);
  }

  void _toggleHighlight(bool isEffectiveBgDark) {
    if (_isHighlightActive()) {
      _quillController.formatSelection(const quill.BackgroundAttribute(null));
    } else {
      _quillController.formatSelection(
        quill.BackgroundAttribute(isEffectiveBgDark ? '#FFD54F' : '#FFF59D'),
      );
    }
    setState(() {});
  }

  Widget _highlightBtn(bool isEffectiveBgDark) {
    final isActive = _isHighlightActive();
    final iconColor = isActive
        ? (isEffectiveBgDark ? Colors.black : Colors.white)
        : (isEffectiveBgDark ? Colors.white70 : Colors.black87);
    return GestureDetector(
      onTap: () => _toggleHighlight(isEffectiveBgDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? (isEffectiveBgDark ? Colors.white : Colors.black)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(CupertinoIcons.pencil_outline, size: 20, color: iconColor),
      ),
    );
  }

  Widget _dockBtn(quill.Attribute attr, IconData icon, Color accentColor, bool isEffectiveBgDark,
      {bool isActive = false}) {
    final effectiveAccent = isEffectiveBgDark ? Colors.white : Colors.black;
    final iconColor = isActive
        ? (isEffectiveBgDark ? Colors.black : Colors.white)
        : (isEffectiveBgDark ? Colors.white70 : Colors.black87);
    return GestureDetector(
      onTap: () {
        if (isActive) {
          _quillController.formatSelection(quill.Attribute.clone(attr, null));
        } else {
          _quillController.formatSelection(attr);
        }
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? (isEffectiveBgDark ? Colors.white : Colors.black)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }

  Widget _fontSizeBtn(Color accentColor, Color textColor, bool isEffectiveBgDark) {
    final effectiveAccent = isEffectiveBgDark ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: _showFontSizePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isEffectiveBgDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.textformat_size, size: 18, color: isEffectiveBgDark ? Colors.white70 : Colors.black87),
            const SizedBox(width: 3),
            Text(
              '${_fontSize.toInt()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: effectiveAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaBtn(IconData icon, Color color, bool isEffectiveBgDark, VoidCallback onTap) {
    final iconColor = isEffectiveBgDark ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isEffectiveBgDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isEffectiveBgDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
              width: 1),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }

  // --- POPUPS AND UTILS ---

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'bg_${const Uuid().v4()}.jpg';
      final savedImage =
          await File(image.path).copy('${appDir.path}/$fileName');
      setState(() {
        _backgroundImagePath = savedImage.path;
        _backgroundColor = null;
        _currentThemeId = 'custom';
      });
    }
  }

  Future<void> _insertImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final index = _quillController.selection.baseOffset;
      final length = _quillController.selection.extentOffset - index;
      _quillController.replaceText(
          index, length, quill.BlockEmbed.image(image.path), null);
    }
  }

  void _openDoodlePad() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Doodle Board",
                    style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color, fontSize: 18)),
                IconButton(
                  icon: Icon(Icons.check,
                      color: Provider.of<UserProvider>(context).accentColor),
                  onPressed: () async {
                    final Color inkColor = isDark ? Colors.white : Colors.black;

                    final ByteData? data =
                        await _doodleControl.toImage(color: inkColor);
                    if (data != null) {
                      final buffer = data.buffer.asUint8List();
                      final dir = await getApplicationDocumentsDirectory();
                      final fileName =
                          'doodle_${DateTime.now().millisecondsSinceEpoch}.png';
                      final file = File('${dir.path}/$fileName');
                      await file.writeAsBytes(buffer);
                      if (mounted) {
                        final index = _quillController.selection.baseOffset;
                        final safeIndex = index < 0 ? 0 : index;
                        _quillController.document.insert(safeIndex, "\n");
                        _quillController.document.insert(
                            safeIndex + 1, quill.BlockEmbed.image(file.path));
                        _quillController.document.insert(safeIndex + 2, "\n");
                        _doodleControl.clear();
                        Navigator.pop(ctx);
                      }
                    }
                  },
                )
              ],
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor)),
                child: HandSignature(
                  control: _doodleControl,
                  color: isDark ? Colors.white : Colors.black,
                  width: 3.0,
                  maxWidth: 6.0,
                  type: SignatureDrawType.shape,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _doodleControl.clear(),
              child: const Text("Clear", style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }

  void _showSmartButtonDialog() {
    String label = _buttonLabel ?? '';
    String link = _buttonLink ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Add Smart Link", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    CupertinoTextField(
                      placeholder: "Label (e.g. Flight Details)",
                      placeholderStyle: TextStyle(color: textColor.withOpacity(0.4)),
                      style: TextStyle(color: textColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      controller: TextEditingController(text: label),
                      onChanged: (v) => label = v,
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      placeholder: "URL (e.g. https://...)",
                      placeholderStyle: TextStyle(color: textColor.withOpacity(0.4)),
                      style: TextStyle(color: textColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      controller: TextEditingController(text: link),
                      onChanged: (v) => link = v,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("Cancel", style: TextStyle(color: textColor.withOpacity(0.5))),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          color: isDark ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () {
                            setState(() {
                              _buttonLabel = label;
                              _buttonLink = link;
                              _buttonColor = (isDark ? Colors.white : Colors.black).value;
                            });
                            Navigator.pop(ctx);
                          },
                          child: Text("Add", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.black : Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showThemePicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryColor = isDark ? Colors.white60 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: secondaryColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
                Text("Choose Vibe", style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _themeOption("Default", theme.scaffoldBackgroundColor, "midnight", textColor),
                    _themeOption("Cyber", const Color(0xFF121212), "cyber", Colors.white),
                    _themeOption("Paper", const Color(0xFFF5F5DC), "paper", Colors.black),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickBackgroundImage();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.photo_fill, color: secondaryColor, size: 20),
                        const SizedBox(width: 12),
                        Text("Custom Image Background", style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                        const Spacer(),
                        Icon(CupertinoIcons.chevron_right, color: secondaryColor, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _themeOption(String label, Color color, String id, Color? labelColor) {
    final bool isSelected =
        _currentThemeId == id && _backgroundImagePath == null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeBorder = isDark ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentThemeId = id;
          _backgroundImagePath = null;
          _backgroundColor = null;
        });
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: activeBorder, width: 3)
                  : Border.all(color: Colors.grey.withOpacity(0.3)),
              boxShadow: id == 'cyber'
                  ? [
                      BoxShadow(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.15), blurRadius: 10)
                    ]
                  : [],
            ),
          ),
          const SizedBox(height: 5),
          Text(label,
              style:
                  TextStyle(color: labelColor?.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  void _showFontSizePicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryColor = isDark ? Colors.white60 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: secondaryColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Text Size", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 17)),
                      Text("${_fontSize.toInt()} pt", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _presetSizeBtn("Small", 14.0, setSheetState),
                      _presetSizeBtn("Medium", 17.0, setSheetState),
                      _presetSizeBtn("Large", 20.0, setSheetState),
                      _presetSizeBtn("X-Large", 24.0, setSheetState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  CupertinoSlider(
                    value: _fontSize,
                    min: 12.0,
                    max: 32.0,
                    divisions: 20,
                    activeColor: isDark ? Colors.white : Colors.black,
                    onChanged: (val) {
                      setSheetState(() => _fontSize = val);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      "Text preview at ${_fontSize.toInt()}pt",
                      style: TextStyle(color: textColor, fontSize: _fontSize),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetSizeBtn(String label, double size, StateSetter setSheetState) {
    final theme = Theme.of(context);
    final isSelected = _fontSize == size;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        setSheetState(() => _fontSize = size);
        setState(() {}); // Update main editor view
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? textColor : textColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.scaffoldBackgroundColor : textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
