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
import '../../utils/markdown_to_quill.dart'; // [ADDED] Markdown Parser

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
  int _currentToolbarPage = 0;
  bool _showToolbar = true;

  Color? _backgroundColor;
  String? _backgroundImagePath;
  String _currentThemeId = 'midnight'; 

  String? _buttonLabel;
  String? _buttonLink;
  int? _buttonColor;

  String? _currentNoteId;
  DateTime? _createdAt;
  
  // Auto-Save State
  Timer? _autoSaveTimer;
  String? _saveStatus;

  @override
  void initState() {
    super.initState();
    _currentNoteId = widget.note?.id;
    _createdAt = widget.note?.createdAt;
    _loadNoteData();
    _setupEditor();

    _pageScrollController.addListener(() {
      if (_pageScrollController.hasClients) {
        if (_pageScrollController.position.userScrollDirection == ScrollDirection.reverse) {
          if (_showToolbar) setState(() => _showToolbar = false);
        } else {
          if (!_showToolbar) setState(() => _showToolbar = true);
        }
      }
    });

    // SLASH COMMAND LISTENER
    _quillController.addListener(_checkForSlashCommand);
    
    // AUTO-SAVE LISTENER
    _quillController.changes.listen((event) {
       if (event.source == quill.ChangeSource.local) {
         _scheduleAutoSave();
       }
    });
  }

  @override
  void dispose() {
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
         if (prevChar.trim().isEmpty) { // Whitespace or newline
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
    final itemBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
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
                width: 36, height: 4,
                decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Icon(CupertinoIcons.slash_circle, size: 16, color: secondaryColor),
                  const SizedBox(width: 8),
                  Text("Insert block", style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15)),
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
                  _slashItem(ctx, CupertinoIcons.textformat_size, "Heading 1", "Big section heading", itemBg, textColor, secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.h1);
                  }),
                  _slashItem(ctx, CupertinoIcons.textformat, "Heading 2", "Medium section heading", itemBg, textColor, secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.h2);
                  }),
                  _slashItem(ctx, CupertinoIcons.checkmark_square, "To-do list", "Track tasks with checkboxes", itemBg, textColor, secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.unchecked);
                  }),
                  _slashItem(ctx, CupertinoIcons.list_bullet, "Bulleted list", "Simple bulleted list", itemBg, textColor, secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.ul);
                  }),
                  _slashItem(ctx, CupertinoIcons.list_number, "Numbered list", "List with numbers", itemBg, textColor, secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.ol);
                  }),
                  _slashItem(ctx, CupertinoIcons.text_quote, "Quote", "Capture a quote", itemBg, textColor, secondaryColor, () {
                    _quillController.formatSelection(quill.Attribute.blockQuote);
                  }),
                  _slashItem(ctx, CupertinoIcons.minus, "Divider", "Visual separator", itemBg, textColor, secondaryColor, () {
                    final idx = _quillController.selection.baseOffset;
                    _quillController.replaceText(idx, 0, quill.BlockEmbed('divider', 'hr'), null);
                  }),

                  const SizedBox(height: 12),

                  // ── MEDIA ──
                  _slashSection("MEDIA", secondaryColor),
                  _slashItem(ctx, CupertinoIcons.photo, "Image", "Upload or embed an image", itemBg, textColor, secondaryColor, () {
                    _insertImage();
                  }),

                  const SizedBox(height: 12),

                  // ── AI ──
                  _slashSection("AI", secondaryColor),
                  _slashItem(ctx, CupertinoIcons.sparkles, "Ask AI", "Write, edit, or brainstorm with AI", itemBg, textColor, secondaryColor, () {
                    _openAIAgent();
                  }, isAI: true),
                  _slashItem(ctx, CupertinoIcons.arrow_right_circle, "Continue writing", "Let AI continue from here", itemBg, textColor, secondaryColor, () {
                    _openAIAgent(initialAction: 'continue');
                  }, isAI: true),
                  _slashItem(ctx, CupertinoIcons.doc_plaintext, "Summarize", "Summarize current note", itemBg, textColor, secondaryColor, () {
                    _openAIAgent(initialAction: 'summarize');
                  }, isAI: true),
                  _slashItem(ctx, CupertinoIcons.wand_stars, "Style Note", "Format structure & style", itemBg, textColor, secondaryColor, () {
                    _openAIAgent(initialAction: 'style');
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
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    );
  }

  Widget _slashItem(BuildContext ctx, IconData icon, String title, String subtitle, Color bg, Color textColor, Color secondaryColor, VoidCallback onTap, {bool isAI = false}) {
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
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isAI ? textColor.withOpacity(0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: isAI ? textColor : textColor.withOpacity(0.6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: TextStyle(color: secondaryColor, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAIAgent({String? initialAction}) {
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
        onReplaceContent: (text) {
           _quillController.document = markdownToQuill(text);
           _saveNote(false);
        },
        onInsertContent: (text) {
           final idx = _quillController.selection.baseOffset;
           final insertIdx = idx >= 0 ? idx : _quillController.document.length - 1;
           
           // Build a delta: retain to cursor, then concat new content
           final composed = dqd.Delta();
           if (insertIdx > 0) composed.retain(insertIdx);
           final newDelta = markdownToQuill("\n$text\n").toDelta();
           composed.concat(newDelta);
           
           _quillController.compose(composed, _quillController.selection, quill.ChangeSource.local);
           _saveNote(false);
        },
        onReplaceSelection: selectedText != null ? (text) {
           final start = selection.start;
           final length = selection.end - selection.start;
           
           // Delete existing selection
           final deleteDelta = dqd.Delta();
           if (start > 0) deleteDelta.retain(start);
           deleteDelta.delete(length);
           _quillController.compose(deleteDelta, selection, quill.ChangeSource.local);
           
           // Insert new content at start
           final insertDelta = dqd.Delta();
           if (start > 0) insertDelta.retain(start);
           insertDelta.concat(markdownToQuill(text).toDelta());
           _quillController.compose(insertDelta, _quillController.selection, quill.ChangeSource.local);
           
           _saveNote(false);
        } : null,
        initialAction: initialAction, // [ADDED] Pass action
      ),
    );
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
        if (contentToLoad.trim().startsWith('[') && contentToLoad.contains('insert')) {
          final List<dynamic> json = jsonDecode(contentToLoad);
          // Check if this is a single-element list containing a JSON string
          if (json.isNotEmpty && json.length == 1 && json[0] is Map && json[0]['insert'] is String) {
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
    _backgroundColor = widget.note?.backgroundColor != null ? Color(widget.note!.backgroundColor!) : null;
    _backgroundImagePath = widget.note?.backgroundImage;
    _buttonLabel = widget.note?.buttonLabel;
    _buttonLink = widget.note?.buttonLink;
    _buttonColor = widget.note?.buttonColor;
    _currentThemeId = widget.note?.themeId ?? 'midnight'; 
  }



  void _saveNote([bool close = true]) {
    _autoSaveTimer?.cancel();
    final title = _titleController.text.trim();
    final String plainText = _quillController.document.toPlainText().trim();
    final bool isEmpty = title.isEmpty && plainText.isEmpty && _backgroundImagePath == null;

    if (_currentNoteId == null && isEmpty) {
      if (!close && mounted) setState(() => _saveStatus = null);
      if (close && mounted) Navigator.pop(context);
      return;
    }

    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    // Determine ID
    if (_currentNoteId == null) {
      _currentNoteId = const Uuid().v4();
    }

    // Determine CreatedAt
    if (_createdAt == null) {
      _createdAt = DateTime.now();
    }

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
      folder: widget.note?.folder ?? widget.initialFolder ?? 'All',
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

  // --- THEME LOGIC ---

  BoxDecoration _getThemeDecoration(BuildContext context) {
    if (_backgroundImagePath != null) {
       return BoxDecoration(
        image: DecorationImage(image: FileImage(File(_backgroundImagePath!)), fit: BoxFit.cover),
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
        return BoxDecoration(color: _backgroundColor ?? Theme.of(context).scaffoldBackgroundColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context); // Access UserProvider
    final accentColor = userProvider.accentColor;

    // Determine Text Color based on background
    Color textColor = isDark ? Colors.white : Colors.black;
    if (_backgroundImagePath != null || _currentThemeId == 'cyber') {
      textColor = Colors.white;
    }
    if (_currentThemeId == 'paper') textColor = Colors.black87;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false, 
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
                const SizedBox(height: 100), // Space for Header
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.w700, 
                      color: textColor.withOpacity(0.9), 
                      fontFamily: isDark ? 'Courier' : null, 
                      letterSpacing: -0.5
                    ),
                    decoration: InputDecoration(
                      hintText: "Untitled Note", 
                      hintStyle: TextStyle(color: textColor.withOpacity(0.3)), 
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero
                    ),
                  ),
                ),
                
                // Smart Link Button (if exists)
                if (_buttonLabel != null && _buttonLink != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SmartButton(label: _buttonLabel!, link: _buttonLink!, colorValue: _buttonColor!),
                    ),
                  ),

                // Editor
                Expanded(
                  child: quill.QuillEditor.basic(
                    controller: _quillController,
                    scrollController: _pageScrollController,
                    focusNode: _editorFocusNode,
                    configurations: quill.QuillEditorConfigurations(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100), 
                      autoFocus: false,
                      expands: true,
                      placeholder: "Start typing...",
                      embedBuilders: kIsWeb ? null : FlutterQuillEmbeds.editorBuilders(),
                      customStyles: quill.DefaultStyles(
                        paragraph: quill.DefaultTextBlockStyle(
                          TextStyle(color: textColor.withOpacity(0.9), fontSize: 17, height: 1.6), 
                          const quill.HorizontalSpacing(0,0), 
                          const quill.VerticalSpacing(0,0), 
                          const quill.VerticalSpacing(0,0), 
                          null
                        ),
                        h1: quill.DefaultTextBlockStyle(
                          TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold, height: 1.2), 
                          const quill.HorizontalSpacing(0,0), 
                          const quill.VerticalSpacing(16,0), 
                          const quill.VerticalSpacing(0,0), 
                          null
                        ),
                        h2: quill.DefaultTextBlockStyle(
                          TextStyle(color: textColor.withOpacity(0.9), fontSize: 24, fontWeight: FontWeight.w600), 
                          const quill.HorizontalSpacing(0,0), 
                          const quill.VerticalSpacing(16,0), 
                          const quill.VerticalSpacing(0,0), 
                          null
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 3. FROSTY GLASS HEADER (iOS Style)
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: _backgroundImagePath != null 
                    ? ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20) 
                    : ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 90, // Include StatusBar area
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.2),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))
                  ),
                  child: NavigationToolbar(
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                      child: _headerBtn(CupertinoIcons.back, () => _saveNote(), textColor),
                    ),
                    middle: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _headerBtn(CupertinoIcons.arrow_turn_up_left, () => _quillController.undo(), textColor),
                        const SizedBox(width: 8),
                         _headerBtn(CupertinoIcons.arrow_turn_up_right, () => _quillController.redo(), textColor),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _headerBtn(CupertinoIcons.share, () => Share.share(_quillController.document.toPlainText()), textColor),
                        const SizedBox(width: 8),
                         // AI Button with Glow and Accent Color
                        // AI Button - Modern iOS Monochrome Style
                        GestureDetector(
                          onTap: _openAIAgent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: textColor.withOpacity(0.12)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("AI", style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13))
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                         if (_saveStatus != null)
                           Padding(
                             padding: const EdgeInsets.only(right: 12),
                             child: Text(_saveStatus!, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                           ),
                         // Save Button covering accent color request
                         CupertinoButton(
                           padding: EdgeInsets.zero,
                           minSize: 30,
                           onPressed: _saveNote,
                           child: Container(
                             width: 36, height: 36,
                             decoration: BoxDecoration(color: accentColor.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: accentColor.withOpacity(0.5))),
                             child: Icon(CupertinoIcons.checkmark_alt, color: accentColor, size: 18),
                           ),
                         ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. FLOATING FROSTY TOOLBAR (Dock Style)
          if (_showToolbar && MediaQuery.of(context).viewInsets.bottom < 100) 
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                      ]
                    ),
                    height: 60,
                    child: PageView(
                      controller: _toolbarPageController,
                      children: [
                        // FORMATTING DOCK (Page 1: Basic Tools)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _dockBtn(quill.Attribute.bold, CupertinoIcons.bold, accentColor, isActive: _isAttrActive(quill.Attribute.bold)),
                            _dockBtn(quill.Attribute.italic, CupertinoIcons.italic, accentColor, isActive: _isAttrActive(quill.Attribute.italic)),
                            _dockBtn(quill.Attribute.h1, Icons.title, accentColor, isActive: _isAttrActive(quill.Attribute.h1)), 
                            _dockBtn(quill.Attribute.ul, CupertinoIcons.list_bullet, accentColor, isActive: _isAttrActive(quill.Attribute.ul)),
                            _dockBtn(quill.Attribute.ol, CupertinoIcons.list_number, accentColor, isActive: _isAttrActive(quill.Attribute.ol)),
                            _dockBtn(quill.Attribute.unchecked, CupertinoIcons.checkmark_rectangle, accentColor, isActive: _isAttrActive(quill.Attribute.unchecked)),
                            IconButton(
                              icon: const Icon(CupertinoIcons.chevron_right_circle_fill, color: Colors.grey), 
                              onPressed: () => _toolbarPageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease)
                            )
                          ],
                        ),
                        // MEDIA DOCK (Page 2: Media & Theme)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(CupertinoIcons.chevron_left_circle_fill, color: Colors.grey), 
                              onPressed: () => _toolbarPageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease)
                            ),
                            // Use Accent Color for main media entry points
                            _mediaBtn(CupertinoIcons.photo, accentColor, _insertImage),
                            _mediaBtn(CupertinoIcons.paintbrush_fill, accentColor, _showThemePicker), 
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      )
    );
  }

  // --- NEW WIDGET HELPERS ---

  Widget _headerBtn(IconData icon, VoidCallback onTap, Color color) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 30,
      onPressed: onTap,
      child: Container(
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  bool _isAttrActive(quill.Attribute attr) {
     final style = _quillController.getSelectionStyle();
     return style.attributes.containsKey(attr.key) && style.attributes[attr.key]!.value == attr.value;
  }

  Widget _dockBtn(quill.Attribute attr, IconData icon, Color accentColor, {bool isActive = false}) {
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
          color: isActive ? accentColor.withOpacity(0.2) : Colors.transparent, // Gentle highlight
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon, 
          size: 22, 
          color: isActive ? accentColor : (Theme.of(context).iconTheme.color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87))
        ),
      ),
    );
  }


  Widget _mediaBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 24, color: color),
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
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
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
        _quillController.replaceText(index, length, quill.BlockEmbed.image(image.path), null);
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
                 Text("Doodle Board", style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 18)),
                 IconButton(
                   icon: Icon(Icons.check, color: Provider.of<UserProvider>(context).accentColor),
                   onPressed: () async {
                     final Color inkColor = isDark ? Colors.white : Colors.black;
                     
                     final ByteData? data = await _doodleControl.toImage(color: inkColor); 
                     if (data != null) {
                       final buffer = data.buffer.asUint8List();
                       final dir = await getApplicationDocumentsDirectory();
                       final fileName = 'doodle_${DateTime.now().millisecondsSinceEpoch}.png';
                       final file = File('${dir.path}/$fileName');
                       await file.writeAsBytes(buffer);
                       if (mounted) {
                          final index = _quillController.selection.baseOffset;
                          final safeIndex = index < 0 ? 0 : index;
                          _quillController.document.insert(safeIndex, "\n");
                          _quillController.document.insert(safeIndex + 1, quill.BlockEmbed.image(file.path));
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
                 decoration: BoxDecoration(border: Border.all(color: theme.dividerColor)),
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
    final textColor = theme.textTheme.bodyLarge?.color;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text("Add Smart Link", style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(hintText: "Label", hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color)), 
              style: TextStyle(color: textColor), 
              onChanged: (v) => label = v,
              controller: TextEditingController(text: label),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(hintText: "URL", hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color)), 
              style: TextStyle(color: textColor), 
              onChanged: (v) => link = v,
              controller: TextEditingController(text: link),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() { 
                _buttonLabel = label; 
                _buttonLink = link; 
                _buttonColor = 0xFF2196F3; 
              });
              Navigator.pop(ctx);
            }, 
            child: const Text("Add")
          ),
        ],
      ),
    );
  }

  void _showThemePicker() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Choose Vibe", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _themeOption("Default", theme.scaffoldBackgroundColor, "midnight", textColor),
                _themeOption("Cyber", Colors.indigo.shade900, "cyber", Colors.white),
                _themeOption("Paper", const Color(0xFFF5F5DC), "paper", Colors.black),
              ],
            ),
             const SizedBox(height: 20),
             ListTile(
               leading: Icon(Icons.image, color: theme.textTheme.bodyMedium?.color),
               title: Text("Custom Image", style: TextStyle(color: textColor)),
               onTap: () {
                 Navigator.pop(ctx);
                 _pickBackgroundImage();
               },
             )
          ],
        ),
      ),
    );
  }

  Widget _themeOption(String label, Color color, String id, Color? labelColor) {
    final bool isSelected = _currentThemeId == id && _backgroundImagePath == null;
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
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.blueAccent, width: 3) : Border.all(color: Colors.grey.withOpacity(0.3)),
              boxShadow: id == 'cyber' ? [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10)] : [],
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: labelColor?.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }
}