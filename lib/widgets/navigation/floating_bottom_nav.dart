import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../config/theme.dart';

class FloatingBottomNav extends StatefulWidget {
  final Function(int) onTap; // Kept for compatibility, though we mostly use the FAB now

  const FloatingBottomNav({super.key, required this.onTap});

  @override
  State<FloatingBottomNav> createState() => _FloatingBottomNavState();
}

class _FloatingBottomNavState extends State<FloatingBottomNav> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _expandAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)); // 45 degrees
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // 1. BLUR OVERLAY (When Open)
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleMenu,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          ),

        // 2. THE FAN-OUT MENU
        Positioned(
          bottom: 100,
          child: IgnorePointer(
            ignoring: !_isOpen,
            child: SizedBox(
              width: 300,
              height: 200,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  _buildMiniFab(0, "Note", CupertinoIcons.doc_text, Colors.blueAccent, -60), // Left
                  _buildMiniFab(1, "Task", CupertinoIcons.check_mark, Colors.greenAccent, -30), // Mid-Left
                  _buildMiniFab(2, "Spend", CupertinoIcons.money_dollar, Colors.orangeAccent, 0), // Center
                  _buildMiniFab(3, "Voice", CupertinoIcons.mic, Colors.purpleAccent, 30), // Mid-Right
                  _buildMiniFab(4, "Photo", CupertinoIcons.camera, Colors.pinkAccent, 60), // Right
                ],
              ),
            ),
          ),
        ),

        // 3. THE MAIN FLOATING BUTTON
        Positioned(
          bottom: 30,
          child: GestureDetector(
            onTap: _toggleMenu,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _isOpen ? Colors.white : AppTheme.pureWhite.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: RotationTransition(
                turns: _rotateAnimation,
                child: Icon(
                  CupertinoIcons.add,
                  size: 32,
                  color: _isOpen ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniFab(int index, String label, IconData icon, Color color, double angleDeg) {
    final double rad = angleDeg * (math.pi / 180);
    const double distance = 110.0; // Distance from center

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final double progress = _expandAnimation.value;
        final double x = distance * math.sin(rad) * progress;
        final double y = -distance * math.cos(rad) * progress;

        return Transform.translate(
          offset: Offset(x, y),
          child: Transform.scale(
            scale: progress,
            child: Opacity(
              opacity: progress,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      _toggleMenu();
                      // TODO: TRIGGER ACTION based on index
                      print("Tapped $label");
                      // Example: widget.onTap(index + 10); // Pass a special code to MainScaffold
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)
                        ]
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}