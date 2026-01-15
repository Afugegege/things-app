import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/user_provider.dart';
import 'dashboard_drawer.dart';

class LifeAppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final bool useDrawer;

  const LifeAppScaffold({
    super.key, 
    required this.title, 
    required this.child,
    this.floatingActionButton,
    this.actions,
    this.useDrawer = true,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    // [FIX] Use the isDarkMode boolean directly for cleaner logic
    final bool isDark = userProvider.isDarkMode;
    final themeData = AppTheme.getThemeData(isDark);
    
    // Background Logic
    final BoxDecoration bgDecoration = BoxDecoration(color: themeData.scaffoldBackgroundColor);

    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: useDrawer ? const DashboardDrawer() : null,
        floatingActionButton: floatingActionButton,
        body: Container(
          decoration: bgDecoration,
          child: Stack(
            children: [
              // Content
              Positioned.fill(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: child,
                  ),
                ),
              ),
    
              // Glass Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: AppTheme.glassBlur, sigmaY: AppTheme.glassBlur),
                    child: Container(
                      color: themeData.colorScheme.surface.withOpacity(0.7),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Menu/Back Button
                            if (useDrawer)
                              Builder(
                                builder: (context) => GestureDetector(
                                  onTap: () => Scaffold.of(context).openDrawer(),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: themeData.iconTheme.color!.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.menu, color: themeData.iconTheme.color, size: 24),
                                  ),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: themeData.iconTheme.color!.withOpacity(0.1),
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