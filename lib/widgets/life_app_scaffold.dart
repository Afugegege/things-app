import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/user_provider.dart';

class LifeAppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const LifeAppScaffold({
    super.key, 
    required this.title, 
    required this.child,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final themeId = userProvider.currentTheme;
    final themeData = AppTheme.getThemeData(themeId);
    
    // Determine Background
    BoxDecoration bgDecoration;
    if (themeId == 'Cyberpunk') {
      bgDecoration = const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F0C29), Color(0xFF302b63), Color(0xFF24243e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else {
      bgDecoration = BoxDecoration(color: themeData.scaffoldBackgroundColor);
    }

    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: Colors.transparent, 
        floatingActionButton: floatingActionButton,
        body: Container(
          decoration: bgDecoration,
          child: Stack(
            children: [
              // 1. Content Body
              Positioned.fill(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: child,
                  ),
                ),
              ),
    
              // 2. Glass Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: AppTheme.glassBlur, sigmaY: AppTheme.glassBlur),
                    child: Container(
                      color: themeData.colorScheme.surface.withValues(alpha: 0.7), // Fixed deprecation
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back Button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: themeData.iconTheme.color!.withValues(alpha: 0.1), // Fixed deprecation
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(CupertinoIcons.back, color: themeData.iconTheme.color, size: 20),
                              ),
                            ),
                            
                            // Title
                            Text(
                              title.toUpperCase(),
                              style: themeData.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                            
                            // Actions
                            Row(children: actions ?? [const SizedBox(width: 40)]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}