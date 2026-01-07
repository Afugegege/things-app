import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
import '../../widgets/glass_container.dart';
import '../../widgets/smart_button.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

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
  }

  // [FIX]: Robust Editor Setup to handle both JSON and Plain Text
  void _setupEditor() {
    try {
      if (widget.note?.content != null && widget.note!.content.isNotEmpty) {
        // 1. Try to parse as JSON Delta (The standard format)
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
      // 2. Fallback: If JSON parsing fails, treat content as Plain Text
      // This fixes notes that were saved as raw strings by the AI
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

    // [FIX]: Always save as JSON Delta to ensure consistency
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
    );

    if (widget.note != null) {
      notesProvider.updateNote(noteToSave);
    } else {
      notesProvider.addNote(noteToSave);
    }
    
    if (mounted) Navigator.pop(context);
  }

  // ... (Rest of the file remains exactly the same as before) ...
  // [Keeping existing methods: _pickBackgroundImage, _insertImage, _openDoodlePad, 
  // _showSmartButtonDialog, _showThemePicker, _themeOption, _getThemeDecoration, 
  // _getThemeTextColor, build, _buildSwipeToolbar, _formatBtn]

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text("Doodle Board", style: TextStyle(color: Colors.white, fontSize: 18)),
                 IconButton(
                   icon: const Icon(Icons.check, color: Colors.green),
                   onPressed: () async {
                     final ByteData? data = await _doodleControl.toImage(color: Colors.blue); 
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
                 decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                 child: HandSignature(
                   control: _doodleControl,
                   color: Colors.white,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Add Smart Link", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(hintText: "Label"), 
              style: const TextStyle(color: Colors.white), 
              onChanged: (v) => label = v,
              controller: TextEditingController(text: label),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(hintText: "URL"), 
              style: const TextStyle(color: Colors.white), 
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Choose Vibe", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _themeOption("Midnight", Colors.black, "midnight"),
                _themeOption("Cyber", Colors.indigo.shade900, "cyber"),
                _themeOption("Paper", const Color(0xFFF5F5DC), "paper"),
              ],
            ),
             const SizedBox(height: 20),
             ListTile(
               leading: const Icon(Icons.image, color: Colors.white54),
               title: const Text("Custom Image", style: TextStyle(color: Colors.white)),
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

  Widget _themeOption(String label, Color color, String id) {
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
              border: isSelected ? Border.all(color: Colors.white, width: 3) : Border.all(color: Colors.white24),
              boxShadow: id == 'cyber' ? [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10)] : [],
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  BoxDecoration _getThemeDecoration() {
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
        return BoxDecoration(color: _backgroundColor ?? Colors.black);
    }
  }

  Color _getThemeTextColor() {
    if (_currentThemeId == 'paper' && _backgroundImagePath == null) return Colors.black87;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _getThemeTextColor();

    return Scaffold(
      backgroundColor: Colors.black, 
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor), 
          onPressed: _saveNote
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: textColor), 
            onPressed: () => Share.share(_titleController.text)
          ),
          TextButton(
            onPressed: _saveNote, 
            child: const Text("Done", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: _getThemeDecoration(), 
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: TextField(
                      controller: _titleController,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
                      decoration: InputDecoration(
                        hintText: "Title", 
                        hintStyle: TextStyle(color: textColor.withOpacity(0.5)), 
                        border: InputBorder.none
                      ),
                    ),
                  ),
                  if (_buttonLabel != null && _buttonLink != null)
                     SmartButton(label: _buttonLabel!, link: _buttonLink!, colorValue: _buttonColor!),

                  // --- QUILL EDITOR ---
                  Expanded(
                    child: quill.QuillEditor.basic(
                      controller: _quillController,
                      scrollController: _pageScrollController,
                      focusNode: _editorFocusNode,
                      config: quill.QuillEditorConfig(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), 
                        autoFocus: false,
                        expands: true,
                        placeholder: "Start typing...",
                        embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                        customStyles: quill.DefaultStyles(
                          paragraph: quill.DefaultTextBlockStyle(
                            TextStyle(color: textColor, fontSize: 16), 
                            const quill.HorizontalSpacing(0,0), 
                            const quill.VerticalSpacing(0,0), 
                            const quill.VerticalSpacing(0,0), 
                            null
                          ),
                          h1: quill.DefaultTextBlockStyle(
                            TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold), 
                            const quill.HorizontalSpacing(0,0), 
                            const quill.VerticalSpacing(16,0), 
                            const quill.VerticalSpacing(0,0), 
                            null
                          ),
                        )
                      ),
                    ),
                  ),
                ],
              ),

              if (_showToolbar)
                Positioned(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 0,
                  right: 0,
                  child: _buildSwipeToolbar(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeToolbar() {
    return GlassContainer(
      borderRadius: 0,
      opacity: 0.1,
      blur: 20,
      child: SizedBox(
        height: 60,
        child: Stack(
          children: [
            PageView(
              controller: _toolbarPageController,
              onPageChanged: (index) => setState(() => _currentToolbarPage = index),
              children: [
                // PAGE 1: FORMATTING
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 20),
                      _formatBtn(quill.Attribute.bold, Icons.format_bold, "Bold"),
                      _formatBtn(quill.Attribute.italic, Icons.format_italic, "Italic"),
                      _formatBtn(quill.Attribute.h1, Icons.title, "Heading 1"),
                      _formatBtn(quill.Attribute.ol, Icons.format_list_numbered, "Numbered List"),
                      _formatBtn(quill.Attribute.ul, Icons.format_list_bulleted, "Bullet List"),
                      _formatBtn(quill.Attribute.unchecked, Icons.check_box_outlined, "Checkbox"),
                      const SizedBox(width: 20),
                    ],
                  ),
                ),
                // PAGE 2: MEDIA & VIBES
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.palette_outlined, color: Colors.purpleAccent), 
                        onPressed: _showThemePicker, 
                        tooltip: "Themes"
                      ),
                      IconButton(
                        icon: const Icon(Icons.image_outlined, color: Colors.blueAccent), 
                        onPressed: _insertImage, 
                        tooltip: "Image"
                      ),
                      IconButton(
                        icon: const Icon(Icons.draw, color: Colors.greenAccent), 
                        onPressed: _openDoodlePad, 
                        tooltip: "Doodle"
                      ),
                      IconButton(
                        icon: const Icon(Icons.link, color: Colors.orangeAccent), 
                        onPressed: _showSmartButtonDialog, 
                        tooltip: "Link"
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.white70),
                        tooltip: "Insert Date",
                        onPressed: () {
                           final dateStr = DateFormat('MMM d, yyyy').format(DateTime.now());
                           final index = _quillController.selection.baseOffset;
                           final safeIndex = index < 0 ? 0 : index;
                           _quillController.document.insert(safeIndex, "$dateStr ");
                        },
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                ),
              ],
            ),
             if (_currentToolbarPage == 0)
              Positioned(
                right: 5, top: 20, 
                child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white.withOpacity(0.3))
              ),
             if (_currentToolbarPage == 1)
              Positioned(
                left: 5, top: 20, 
                child: Icon(Icons.arrow_back_ios, size: 12, color: Colors.white.withOpacity(0.3))
              ),
          ],
        ),
      ),
    );
  }

  Widget _formatBtn(quill.Attribute attribute, IconData icon, String tooltip) {
    return StatefulBuilder(
      builder: (context, setState) {
        final isActive = _quillController.getSelectionStyle().attributes.containsKey(attribute.key);
        return IconButton(
          icon: Icon(
            icon, 
            color: isActive ? Colors.blueAccent : Colors.white54,
          ),
          tooltip: tooltip,
          onPressed: () {
            if (isActive) {
              _quillController.formatSelection(quill.Attribute.clone(attribute, null));
            } else {
              _quillController.formatSelection(attribute);
            }
            setState(() {});
          },
        );
      },
    );
  }
}