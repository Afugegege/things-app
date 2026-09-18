import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
      x: 100,
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Design Saved!")));
  }

  void _deleteSelected() {
    if (_selectedLayerId != null) {
      setState(() {
        _layers.removeWhere((l) => l.id == _selectedLayerId);
        _selectedLayerId = null;
      });
    }
  }

  // --- BADGE STICKER PICKER (Minimalist Monochrome) ---
  void _showBadgePicker() {
    final List<String> badges = [
      "PRIORITY", "FOCUS", "DRAFT", "URGENT", "NOTE", "STAR",
      "DONE", "APPROVED", "TODO", "GOAL", "KEY", "IDEA"
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("ADD BADGE STICKER",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 2)),
            const SizedBox(height: 15),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _addLayer('badge', badges[index]);
                      Navigator.pop(context);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        badges[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
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
        elevation: 0,
        leading: IconButton(icon: const Icon(CupertinoIcons.xmark, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text("WIDGET STUDIO", style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(CupertinoIcons.check_mark, color: Colors.greenAccent), onPressed: _saveDesign)
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: IgnorePointer(child: Center(child: WidgetFactory.build(context, widget.note)))),
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
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _toolBtn(CupertinoIcons.tag, "Sticker", _showBadgePicker),
                  _toolBtn(CupertinoIcons.pencil_outline, "Doodle", _openDoodlePad), // Ensure _openDoodlePad exists or is imported
                  _toolBtn(CupertinoIcons.trash, "Remove", _deleteSelected, color: Colors.redAccent),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  // Reuse existing _openDoodlePad logic from your original file here...
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
                const Text("DRAW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
                TextButton(
                  onPressed: () async {
                    if (control.paths.isNotEmpty) {
                      final ByteData? data = await control.toImage(color: Colors.white);
                      if (data != null) {
                        final buffer = data.buffer.asUint8List();
                        final dir = await getApplicationDocumentsDirectory();
                        final path = '${dir.path}/sticker_${DateTime.now().millisecondsSinceEpoch}.png';
                        await File(path).writeAsBytes(buffer);
                        _addLayer('doodle', path); 
                        if (mounted) Navigator.pop(ctx);
                      }
                    }
                  },
                  child: Text("Done", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 20),
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
                IconButton(icon: const Icon(CupertinoIcons.arrow_turn_up_left, color: Colors.white), onPressed: () => control.stepBack()),
                IconButton(icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent), onPressed: () => control.clear()),
              ],
            )
          ],
        ),
      ),
    );
  }
}