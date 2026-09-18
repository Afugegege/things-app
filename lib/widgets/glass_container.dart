import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class GlassContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final double? opacity;
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final bool hasBorder;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20.0,
    this.blur = 15.0,
    this.opacity,
    this.padding,
    this.margin,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    double activeOpacity = opacity ?? 0.1;
    try {
      final userProv = Provider.of<UserProvider>(context, listen: false);
      activeOpacity = opacity ?? userProv.glassOpacity;
    } catch (_) {}

    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          alignment: Alignment.center,
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
                    color: Theme.of(context).colorScheme.surface.withOpacity(activeOpacity),
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: hasBorder ? Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.0,
                    ) : null,
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