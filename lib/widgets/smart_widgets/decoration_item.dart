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
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
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
    if (layer.type == 'badge' || layer.type == 'emoji') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          layer.content,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.2,
            decoration: TextDecoration.none,
          ),
        ),
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