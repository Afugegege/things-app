import 'dart:io';
import 'package:flutter/material.dart';
import 'package:matrix_gesture_detector/matrix_gesture_detector.dart';
import '../../models/decoration_layer.dart';
import 'dart:math' as math;

class DecorationItem extends StatelessWidget {
  final DecorationLayer layer;
  final bool isSelected;
  final Function(DecorationLayer) onUpdate;
  final VoidCallback onTap;

  const DecorationItem({
    super.key,
    required this.layer,
    required this.isSelected,
    required this.onUpdate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: layer.x,
      top: layer.y,
      child: MatrixGestureDetector(
        shouldRotate: true,
        shouldScale: true,
        shouldTranslate: true,
        onMatrixUpdate: (m, tm, sm, rm) {
          final double deltaX = tm.getTranslation().x;
          final double deltaY = tm.getTranslation().y;
          final double deltaScale = sm.getMaxScaleOnAxis();
          final double deltaRotation = -math.atan2(rm.row1.x, rm.row0.x);

          final updatedLayer = DecorationLayer(
            id: layer.id,
            type: layer.type,
            content: layer.content,
            zIndex: layer.zIndex,
            x: layer.x + deltaX,
            y: layer.y + deltaY,
            scale: layer.scale * deltaScale,
            rotation: layer.rotation + deltaRotation,
          );

          onUpdate(updatedLayer);
        },
        child: GestureDetector(
          onTap: onTap,
          child: Transform.rotate(
            angle: layer.rotation,
            child: Transform.scale(
              scale: layer.scale,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(color: Colors.blueAccent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (layer.type == 'emoji') {
      return Text(
        layer.content,
        style: const TextStyle(fontSize: 50, decoration: TextDecoration.none),
      );
    } else if (layer.type == 'doodle' || layer.type == 'image') {
      // NEW: Handle Doodle/Image Rendering
      return Image.file(
        File(layer.content),
        width: 150,
        height: 150,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
      );
    }
    return const SizedBox();
  }
}