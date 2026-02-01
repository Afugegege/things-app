import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart'; 
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
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
  
  final PageController _toolbarPageController = PageController();
  int _currentToolbarPage = 0;
  bool _showToolbar = true;

  Color? _backgroundColor;
  String? _backgroundImagePath;
  String _currentThemeId = 'midnight'; 

  String? _buttonLabel;
  String? _buttonLink;
  int? _buttonColor;

  final HandSignatureControl _doodleControl = HandSignatureControl();

  @override
  void initState() {
    super.initState();
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
    // Remove the slash that triggered this
    final index = _quillController.selection.baseOffset;
    _quillController.replaceText(index - 1, 1, '', null);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Insert Block", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: Icon(Icons.check_box_outlined, color: Colors.blue),
              title: Text("To-do List"),
              onTap: () {
                Navigator.pop(ctx);
                _quillController.formatSelection(quill.Attribute.unchecked);
              },
            ),
            ListTile(
              leading: Icon(Icons.title, color: Colors.orange),
              title: Text("Heading 1"),
              onTap: () {
                Navigator.pop(ctx);
                _quillController.formatSelection(quill.Attribute.h1);
              },
            ),
            ListTile(
              leading: Icon(Icons.format_list_bulleted, color: Colors.purple),
              title: Text("Bulleted List"),
              onTap: () {
                Navigator.pop(ctx);
                _quillController.formatSelection(quill.Attribute.ul);
              },
            ),
            ListTile(
              leading: Icon(Icons.image, color: Colors.green),
              title: Text("Image"),
              onTap: () {
                Navigator.pop(ctx);
                _insertImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_awesome, color: Colors.pink),
              title: Text("Ask AI"),
              onTap: () {
                Navigator.pop(ctx);
                _openAIAgent();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _openAIAgent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AIAgentSheet(
        currentContent: _quillController.document.toPlainText(),
        onReplaceContent: (text) {
           _quillController.document.delete(0, _quillController.document.length);
           _quillController.document.insert(0, text);
           Navigator.pop(ctx); // Close sheet
        },
        onInsertContent: (text) {
           final index = _quillController.selection.baseOffset;
           _quillController.document.insert(index >= 0 ? index : _quillController.document.length - 1, "\n$text\n");
           Navigator.pop(ctx); // Close sheet
        },
      ),
    );
  }

  void _setupEditor() {
    try {
      if (widget.note?.content != null && widget.note!.content.isNotEmpty) {
        final List<dynamic> jsonContent = jsonDecode(widget.note!.content);
        final doc = quill.Document.fromJson(jsonContent);
        _quillController = quill.QuillController(
          document: doc, 
          selection: const TextSelection.collapsed(offset: 0)
        );
      } else {
        _quillController = quill.QuillController.basic();
      }
    } catch (e) {
      final doc = quill.Document();
      if (widget.note?.content != null) {
        doc.insert(0, widget.note!.content);
      }
      _quillController = quill.QuillController(
        document: doc, 
        selection: const TextSelection.collapsed(offset: 0)
      );
    }
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

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _pageScrollController.dispose();
    _toolbarPageController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final String plainText = _quillController.document.toPlainText().trim();
    final bool isEmpty = title.isEmpty && plainText.isEmpty && _backgroundImagePath == null;

    if (widget.note == null && isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    final noteToSave = Note(
      id: widget.note?.id ?? const Uuid().v4(),
      title: title.isEmpty ? "Untitled" : title,
      content: contentJson, 
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      backgroundColor: _backgroundColor?.value,
      backgroundImage: _backgroundImagePath,
      buttonLabel: _buttonLabel,
      buttonLink: _buttonLink,
      buttonColor: _buttonColor,
      themeId: _currentThemeId,
      folder: widget.note?.folder ?? widget.initialFolder ?? 'All', // Use initialFolder
    );

    if (widget.note != null) {
      notesProvider.updateNote(noteToSave);
    } else {
      notesProvider.addNote(noteToSave);
    }
    
    if (mounted) Navigator.pop(context);
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
    if (_backgroundImagePath != null || _currentThemeId == 'cyber' || _currentThemeId == 'midnight') {
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
                const SizedBox(height: 60), // Space for Header
                
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
                      embedBuilders: FlutterQuillEmbeds.editorBuilders(),
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
                    leading: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
                      ), 
                      onPressed: _saveNote
                    ),
                    middle: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _headerBtn(CupertinoIcons.arrow_turn_up_left, () => _quillController.undo()),
                        const SizedBox(width: 8),
                         _headerBtn(CupertinoIcons.arrow_turn_up_right, () => _quillController.redo()),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _headerBtn(CupertinoIcons.share, () => Share.share(_quillController.document.toPlainText())),
                        const SizedBox(width: 8),
                         // AI Button with Glow and Accent Color
                        GestureDetector(
                          onTap: _openAIAgent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accentColor.withOpacity(0.5))
                            ),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.sparkles, color: accentColor, size: 14),
                                const SizedBox(width: 4),
                                Text("AI", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12))
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                        // FORMATTING DOCK
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
                        // MEDIA DOCK
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(CupertinoIcons.chevron_left_circle_fill, color: Colors.grey), 
                              onPressed: () => _toolbarPageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease)
                            ),
                            // Use Accent Color for main media entry points
                            _mediaBtn(CupertinoIcons.photo, accentColor, _insertImage),
                            _mediaBtn(CupertinoIcons.paintbrush, Colors.pinkAccent, _openDoodlePad), // Keep distinct
                            _mediaBtn(CupertinoIcons.link, Colors.orangeAccent, _showSmartButtonDialog),
                            _mediaBtn(CupertinoIcons.paintbrush_fill, Colors.purpleAccent, _showThemePicker), 
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

  Widget _headerBtn(IconData icon, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 30,
      onPressed: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
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
          color: isActive ? accentColor : Colors.black87
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