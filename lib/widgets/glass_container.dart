import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20.0,
    this.blur = 15.0,
    this.opacity = 0.1,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Layer 1: Blur Effect
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blur, 
                  sigmaY: blur
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(opacity),
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            
            // Layer 2: Content
            Container(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}