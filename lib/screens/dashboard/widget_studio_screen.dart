import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hand_signature/signature.dart';

import '../../models/note_model.dart';
import '../../models/decoration_layer.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/smart_widgets/widget_factory.dart';
import '../../widgets/smart_widgets/decoration_item.dart';

class WidgetStudioScreen extends StatefulWidget {
  final Note note;
  const WidgetStudioScreen({super.key, required this.note});

  @override
  State<WidgetStudioScreen> createState() => _WidgetStudioScreenState();
}

class _WidgetStudioScreenState extends State<WidgetStudioScreen> {
  late List<DecorationLayer> _layers;
  String? _selectedLayerId;

  @override
  void initState() {
    super.initState();
    _layers = List.from(widget.note.designLayers);
  }

  void _addLayer(String type, String content) {
    final newLayer = DecorationLayer(
      id: const Uuid().v4(),
      type: type,
      content: content,
      x: 100, // Default start position
      y: 100,
      scale: 1.0,
      rotation: 0.0,
      zIndex: _layers.length,
    );
    setState(() {
      _layers.add(newLayer);
      _selectedLayerId = newLayer.id;
    });
  }

  void _updateLayer(DecorationLayer updatedLayer) {
    setState(() {
      final index = _layers.indexWhere((l) => l.id == updatedLayer.id);
      if (index != -1) {
        _layers[index] = updatedLayer;
      }
    });
  }

  void _saveDesign() {
    final updatedNote = widget.note.copyWith(designLayers: _layers);
    Provider.of<NotesProvider>(context, listen: false).updateNote(updatedNote);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Design Saved! ✨")));
  }

  void _deleteSelected() {
    if (_selectedLayerId != null) {
      setState(() {
        _layers.removeWhere((l) => l.id == _selectedLayerId);
        _selectedLayerId = null;
      });
    }
  }

  // --- DRAWING LOGIC ---
  Future<void> _openDoodlePad() async {
    final control = HandSignatureControl();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                const Text("Draw Sticker", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () async {
                    if (control.paths.isNotEmpty) {
                      final ByteData? data = await control.toImage(color: Colors.white);
                      if (data != null) {
                        final buffer = data.buffer.asUint8List();
                        final dir = await getApplicationDocumentsDirectory();
                        final path = '${dir.path}/sticker_${DateTime.now().millisecondsSinceEpoch}.png';
                        await File(path).writeAsBytes(buffer);
                        _addLayer('doodle', path); // Add as doodle layer
                        if (mounted) Navigator.pop(ctx);
                      }
                    }
                  },
                  child: const Text("Done", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: HandSignature(
                    control: control,
                    color: Colors.white,
                    width: 4.0,
                    maxWidth: 8.0,
                    type: SignatureDrawType.shape,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.undo, color: Colors.white), onPressed: () => control.stepBack()),
                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => control.clear()),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- ENHANCED EMOJI PICKER ---
  void _showEmojiPicker() {
    // Comprehensive emoji list
    final List<String> emojis = [
      "🔥", "✨", "💀", "🚀", "💡", "❤️", "👀", "✅", "🎉", "💯", "📌", "🍔",
      "🌿", "🧠", "💼", "✈️", "🎵", "💰", "⚡", "🛑", "⚠️", "❓", "🔔", "⏰",
      "📅", "📝", "🖌️", "📷", "🎤", "💻", "📱", "🕶️", "🧢", "👟", "⚽", "🏀",
      "🧘", "🚴", "🚗", "🏠", "🏢", "🍕", "☕", "🍺", "🥂", "🎂", "🍎", "🥑",
      "🐶", "🐱", "🦁", "🦕", "🌵", "🌸", "☀️", "🌙", "🌧️", "❄️", "🌊", "🌍"
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4, 
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const Text("Add Sticker", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                       _addLayer('emoji', emojis[index]);
                       Navigator.pop(context);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const CloseButton(color: Colors.white),
        title: const Text("Widget Studio", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.check, color: Colors.greenAccent), onPressed: _saveDesign)
        ],
      ),
      body: Stack(
        children: [
          // CENTER PREVIEW AREA
          Center(
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // BASE WIDGET
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(child: WidgetFactory.build(context, widget.note)),
                    ),
                  ),
                  
                  // LAYERS (Using DecorationItem with MatrixGestureDetector)
                  ..._layers.map((layer) => DecorationItem(
                        layer: layer,
                        isSelected: layer.id == _selectedLayerId,
                        onTap: () => setState(() => _selectedLayerId = layer.id),
                        onUpdate: _updateLayer,
                      )),
                ],
              ),
            ),
          ),

          // BOTTOM TOOLBAR
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _toolBtn(Icons.emoji_emotions_outlined, "Emoji", _showEmojiPicker),
                  _toolBtn(Icons.draw, "Doodle", _openDoodlePad),
                  _toolBtn(Icons.delete_outline, "Remove", _deleteSelected, color: Colors.redAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}