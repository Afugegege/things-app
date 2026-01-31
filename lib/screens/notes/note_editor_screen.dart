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

  Color _getThemeTextColor(BuildContext context) {
    if (_currentThemeId == 'paper') return Colors.black87;
    if (_currentThemeId == 'cyber') return Colors.white;
    if (_backgroundImagePath != null) return Colors.white; 

    if (_backgroundColor != null) {
       return ThemeData.estimateBrightnessForColor(_backgroundColor!) == Brightness.dark ? Colors.white : Colors.black;
    }
    return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _getThemeTextColor(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true, // Allow automatic resizing for keyboard
      appBar: AppBar(
        backgroundColor: _currentThemeId == 'midnight' && _backgroundImagePath == null 
            ? theme.scaffoldBackgroundColor.withOpacity(0.8) 
            : Colors.transparent, 
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor), 
          onPressed: _saveNote
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.undo, color: textColor.withOpacity(0.7), size: 20),
              onPressed: () => _quillController.undo(),
              tooltip: "Undo",
            ),
            IconButton(
              icon: Icon(Icons.redo, color: textColor.withOpacity(0.7), size: 20),
              onPressed: () => _quillController.redo(),
              tooltip: "Redo",
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: textColor), 
            onPressed: () => Share.share(_titleController.text + "\n\n" + _quillController.document.toPlainText())
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.amber, weight: 900),
            onPressed: _saveNote, 
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: _getThemeDecoration(context), 
        child: SafeArea(
          child: Column(
            children: [
              // 1. Title Input
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: textColor, fontFamily: 'serif'),
                  decoration: InputDecoration(
                    hintText: "Untitled Document", 
                    hintStyle: TextStyle(color: textColor.withOpacity(0.4)), 
                    border: InputBorder.none
                  ),
                ),
              ),

              if (_buttonLabel != null && _buttonLink != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SmartButton(label: _buttonLabel!, link: _buttonLink!, colorValue: _buttonColor!),
                ),
              
              const Divider(height: 1),

              // 2. Editor Area (Expands to fill space)
              Expanded(
                child: quill.QuillEditor.basic(
                  controller: _quillController,
                  scrollController: _pageScrollController,
                  focusNode: _editorFocusNode,
                  configurations: quill.QuillEditorConfigurations(
                    padding: const EdgeInsets.all(24),
                    autoFocus: false,
                    expands: true,
                    placeholder: "Start typing...",
                    embedBuilders: FlutterQuillEmbeds.editorBuilders(),
                    customStyles: quill.DefaultStyles(
                      paragraph: quill.DefaultTextBlockStyle(
                        TextStyle(color: textColor, fontSize: 16, height: 1.5), 
                        const quill.HorizontalSpacing(0,0), 
                        const quill.VerticalSpacing(0,0), 
                        const quill.VerticalSpacing(0,0), 
                        null
                      ),
                      h1: quill.DefaultTextBlockStyle(
                        TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold), 
                        const quill.HorizontalSpacing(0,0), 
                        const quill.VerticalSpacing(16,0), 
                        const quill.VerticalSpacing(0,0), 
                        null
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Toolbar (Pinned to bottom)
              if (_showToolbar)
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
                  ),
                  height: 50,
                  child: PageView(
                    controller: _toolbarPageController,
                    onPageChanged: (index) => setState(() => _currentToolbarPage = index),
                    children: [
                      // PAGE 1: TEXT FORMATTING
                      ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        children: [
                          _formatBtn(quill.Attribute.bold, Icons.format_bold, "Bold", textColor),
                          _formatBtn(quill.Attribute.italic, Icons.format_italic, "Italic", textColor),
                          _formatBtn(quill.Attribute.underline, Icons.format_underline, "Underline", textColor),
                          _formatBtn(quill.Attribute.strikeThrough, Icons.strikethrough_s, "Strike", textColor),
                          _verticalDivider(isDark),
                          _formatBtn(quill.Attribute.h1, Icons.title, "Header", textColor),
                          _formatBtn(quill.Attribute.ol, Icons.format_list_numbered, "Numbers", textColor),
                          _formatBtn(quill.Attribute.ul, Icons.format_list_bulleted, "Bullets", textColor),
                          _formatBtn(quill.Attribute.unchecked, Icons.check_box_outlined, "Check", textColor),
                          _verticalDivider(isDark),
                          _formatBtn(quill.Attribute.leftAlignment, Icons.format_align_left, "Left", textColor),
                          _formatBtn(quill.Attribute.centerAlignment, Icons.format_align_center, "Center", textColor),
                          _formatBtn(quill.Attribute.rightAlignment, Icons.format_align_right, "Right", textColor),
                        ],
                      ),
                      // PAGE 2: MEDIA & EXTRAS
                      ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        children: [
                          IconButton(icon: Icon(Icons.palette_outlined, color: Colors.purpleAccent), onPressed: _showThemePicker),
                          IconButton(icon: Icon(Icons.image_outlined, color: Colors.blueAccent), onPressed: _insertImage),
                          IconButton(icon: Icon(Icons.draw_outlined, color: Colors.greenAccent), onPressed: _openDoodlePad),
                          IconButton(icon: Icon(Icons.link, color: Colors.orangeAccent), onPressed: _showSmartButtonDialog),
                          IconButton(
                            icon: Icon(Icons.calendar_today_outlined, color: textColor.withOpacity(0.7)),
                            onPressed: () {
                               final dateStr = DateFormat('MMM d, yyyy').format(DateTime.now());
                               _quillController.document.insert(_quillController.selection.baseOffset, "$dateStr ");
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget
  Widget _verticalDivider(bool isDark) {
    return Container(
      width: 1, 
      height: 20, 
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 15), 
      color: isDark ? Colors.white24 : Colors.black12
    );
  }

  Widget _formatBtn(quill.Attribute attribute, IconData icon, String tooltip, Color baseColor) {
    return Builder(
      builder: (context) {
        final currentStyle = _quillController.getSelectionStyle();
        final isActive = currentStyle.attributes.containsKey(attribute.key) && 
                         currentStyle.attributes[attribute.key]!.value == attribute.value;
        
        return IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            icon, 
            color: isActive ? Colors.blueAccent : baseColor.withOpacity(0.7),
            size: 20,
          ),
          tooltip: tooltip,
          onPressed: () {
            if (isActive) {
              // If it's an alignment attribute, we "turn it off" by setting alignment to null (default)
              // For others like bold, we clone with null to remove
              if (attribute.key == 'align') {
                 _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.leftAlignment, null));
              } else {
                 _quillController.formatSelection(quill.Attribute.clone(attribute, null));
              }
            } else {
              _quillController.formatSelection(attribute);
            }
            setState(() {});
          },
        );
      },
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
                   icon: const Icon(Icons.check, color: Colors.green),
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