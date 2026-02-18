import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/notes_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/money_provider.dart';
import '../../screens/notes/note_editor_screen.dart';
import '../../models/task_model.dart';

class FloatingBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

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
    _controller = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _expandAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    ); 
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

  void _handleQuickAction(String action) {
    _toggleMenu(); 
    Future.delayed(const Duration(milliseconds: 200), () {
      switch (action) {
        case "Note":
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditorScreen()));
          break;
        case "Task":
          Provider.of<TasksProvider>(context, listen: false).addTask(
            Task(id: const Uuid().v4(), title: "New Task", isDone: false, createdAt: DateTime.now())
          );
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New Task Created")));
          break;
        case "Spend":
          Provider.of<MoneyProvider>(context, listen: false).addTransaction("Quick Expense", -10.0, "General");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added -\$10 Expense")));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // [FIX] Access Dynamic Theme
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine colors based on theme
    final navBgColor = theme.cardColor.withOpacity(0.6); // Glassy surface
    final borderColor = theme.dividerColor.withOpacity(0.1);
    final shadowColor = isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.2);
    final barrierColor = isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1);

    return SizedBox(
      height: 350, 
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // --- 1. BACKDROP OVERLAY ---
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: barrierColor),
                ),
              ),
            ),

          // --- 2. BOTTOM GRADIENT FADE ---
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 100,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      theme.scaffoldBackgroundColor.withOpacity(0.9),
                      theme.scaffoldBackgroundColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- 3. THE FAN-OUT MENU ---
          Positioned(
            bottom: 100,
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: SizedBox(
                width: 300, height: 150,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    _buildMiniFab(0, "Note", CupertinoIcons.doc_text, Colors.blueAccent, -70),
                    _buildMiniFab(1, "Task", CupertinoIcons.check_mark, Colors.greenAccent, -35),
                    _buildMiniFab(2, "Spend", CupertinoIcons.money_dollar, Colors.orangeAccent, 0),
                    _buildMiniFab(3, "Voice", CupertinoIcons.mic, Colors.purpleAccent, 35),
                    _buildMiniFab(4, "Photo", CupertinoIcons.camera, Colors.pinkAccent, 70),
                  ],
                ),
              ),
            ),
          ),

          // --- 4. THE GLASS NAVIGATION BAR ---
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: navBgColor,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(color: shadowColor, blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, CupertinoIcons.square_grid_2x2_fill, theme),
                      _buildNavItem(1, CupertinoIcons.doc_text_fill, theme),
                      const SizedBox(width: 60), // Spacer for FAB
                      _buildNavItem(2, CupertinoIcons.sparkles, theme),
                      _buildNavItem(3, CupertinoIcons.calendar, theme),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- 5. THE MAIN FLOATING BUTTON ---
          Positioned(
            bottom: 35,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: _isOpen ? theme.cardColor : theme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isOpen ? theme.cardColor : theme.primaryColor).withOpacity(0.4),
                      blurRadius: 15, offset: const Offset(0, 5),
                    )
                  ],
                  border: Border.all(
                    color: _isOpen ? theme.dividerColor : Colors.white24,
                    width: 1.5
                  ),
                ),
                child: RotationTransition(
                  turns: _rotateAnimation,
                  child: Icon(
                    CupertinoIcons.add, 
                    size: 30, 
                    color: _isOpen ? theme.iconTheme.color : Colors.white // White icon on primary color
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, ThemeData theme) {
    final bool isSelected = widget.currentIndex == index;
    final color = isSelected ? theme.primaryColor : theme.iconTheme.color!.withOpacity(0.4);
    
    return GestureDetector(
      onTap: () => widget.onTap(index),
      child: Container(
        padding: const EdgeInsets.all(10),
        color: Colors.transparent,
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }

  Widget _buildMiniFab(int index, String label, IconData icon, Color color, double angleDeg) {
    final double rad = angleDeg * (math.pi / 180);
    const double distance = 120.0; 
    // Access theme for FAB background
    final theme = Theme.of(context);

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
              opacity: progress.clamp(0.0, 1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _handleQuickAction(label),
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: theme.cardColor, // Dynamic background
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.5)),
                        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)],
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Material(
                    color: Colors.transparent,
                    child: Text(label, style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}