import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dashboard_drawer.dart'; 

class LifeAppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final bool useDrawer;
  final Widget? bottomSheet; // [ADDED]
  final VoidCallback? onBack; // [ADDED] Custom back action
  final VoidCallback? onOpenDrawer; // [ADDED] Allow opening parent drawer

  const LifeAppScaffold({
    super.key, 
    required this.title, 
    required this.child,
    this.floatingActionButton,
    this.actions,
    this.useDrawer = true,
    this.bottomSheet, // [ADDED]
    this.onBack, // [ADDED]
    this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    // Use the dynamic theme provided by main.dart
    final themeData = Theme.of(context);

    return Theme(
      data: themeData.copyWith(
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
      ),
      child: Scaffold(
        backgroundColor: themeData.scaffoldBackgroundColor,
        // If external drawer control is provided, do NOT attach a local drawer, 
        // effectively disabling the inner drawer so it doesn't conflict or use resources.
        drawer: (useDrawer && onOpenDrawer == null) ? const DashboardDrawer() : null,
        floatingActionButton: floatingActionButton,
        bottomSheet: bottomSheet, // [ADDED] Pass to Scaffold
      body: Stack(
        children: [
          // 1. Content Layer
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 100), // Space for header
                child: child,
              ),
            ),
          ),

          // 2. Seamless Header Layer (Transparent)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Container(
              color: themeData.scaffoldBackgroundColor, // Seamless match
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: SafeArea(
                bottom: false,
                  child: NavigationToolbar(
                    centerMiddle: true,
                    middleSpacing: 20.0,
                    leading: _buildLeading(context),
                    middle: Text(
                      title.toUpperCase(),
                      style: themeData.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0, 
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions ?? [],
                    ),
                  ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    if (useDrawer) {
      return Builder(
        builder: (context) => GestureDetector(
          onTap: () {
            if (onOpenDrawer != null) {
              onOpenDrawer!();
            } else {
              Scaffold.of(context).openDrawer();
            }
          },
          child: _buildHeaderIcon(context, Icons.menu),
        ),
      );
    } else if (Navigator.canPop(context) || onBack != null) {
      return GestureDetector(
        onTap: () {
          if (onBack != null) {
            onBack?.call();
          } else {
            Navigator.pop(context);
          }
        },
        child: _buildHeaderIcon(context, CupertinoIcons.back),
      );
    }
    return const SizedBox();
  }

  Widget _buildHeaderIcon(BuildContext context, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.iconTheme.color?.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: theme.iconTheme.color, size: 20),
    );
  }
}