import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Screens
import 'tasks/tasks_list_screen.dart';
import 'chat/chat_screen.dart';
import 'calendar/calendar_screen.dart';
import 'user/user_profile_screen.dart';
import 'dashboard/things_grid_screen.dart';
import 'apps/wallet_screen.dart';
import 'apps/brain_screen.dart';

import '../widgets/dashboard_drawer.dart';
import '../services/notification_service.dart';
import '../providers/user_provider.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final GlobalKey<ScaffoldState> _mainScaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDockEditing = false;
  bool _isDrawerOpen = false;
  bool _isSwipingForward = true;
  double _horizontalDragDistance = 0.0;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  double _dockDragDistance = 0.0;

  void _handleSwipe(bool isNext) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final dockItems = userProvider.dockItems;
    final currentId = userProvider.currentView;
    int currentIndex = dockItems.indexOf(currentId);
    if (currentIndex == -1) {
      if (dockItems.isNotEmpty) {
        userProvider.changeView(dockItems.first);
      }
      return;
    }

    if (isNext && currentIndex < dockItems.length - 1) {
      setState(() => _isSwipingForward = true);
      HapticFeedback.lightImpact();
      userProvider.changeView(dockItems[currentIndex + 1]);
    } else if (!isNext && currentIndex > 0) {
      setState(() => _isSwipingForward = false);
      HapticFeedback.lightImpact();
      userProvider.changeView(dockItems[currentIndex - 1]);
    }
  }

  @override
  void initState() {
    super.initState();
    NotificationService.requestPermissions();
  }

  // [FIX] Correct mapping of IDs to Screens
  Widget _getScreenForId(String id) {
    switch (id) {
      case 'dashboard':
        return ThingsGridScreen(parentScaffoldKey: _mainScaffoldKey);
      case 'notes':
        return const BrainScreen(); // [FIX] Mapped 'notes' to BrainScreen
      case 'brain':
        return const BrainScreen();
      case 'tasks':
        return const TasksListScreen();
      case 'ai':
        return const ChatScreen();
      case 'calendar':
        return const CalendarScreen();
      case 'wallet':
        return const WalletScreen();
      case 'profile':
        return const UserProfileScreen();
      // Settings and Profile are handled by Navigator.push, not here.
      default:
        return ThingsGridScreen(parentScaffoldKey: _mainScaffoldKey);
    }
  }

  void _toggleEditMode() {
    HapticFeedback.mediumImpact();
    setState(() => _isDockEditing = !_isDockEditing);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final dockItems = userProvider.dockItems;
    final theme = Theme.of(context);

    final currentAppId = userProvider.currentView;

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _mainScaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const DashboardDrawer(),
      onDrawerChanged: (isOpen) => setState(() => _isDrawerOpen = isOpen),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          _horizontalDragDistance = 0.0;
          _dragStartX = details.globalPosition.dx;
          _dragStartY = details.globalPosition.dy;
        },
        onHorizontalDragUpdate: (details) {
          _horizontalDragDistance += details.primaryDelta ?? 0.0;
        },
        onHorizontalDragEnd: (details) {
          if (_isDockEditing || _isDrawerOpen) return;

          final velocity = details.primaryVelocity ?? 0.0;
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;

          // Trigger screen swipe if user moved >= 40px OR had a quick flick (> 180 velocity with >= 15px movement)
          final bool swipedLeft = _horizontalDragDistance < -40 ||
              (velocity < -180 && _horizontalDragDistance < -15);
          final bool swipedRight = _horizontalDragDistance > 40 ||
              (velocity > 180 && _horizontalDragDistance > 15);

          // Prevent conflict on screens that have horizontal gesture controls
          if (currentAppId == 'calendar') {
            // Calendar month pager is at the top
            final bool isAllowedCalendarSwipe = _dragStartX <= 80 ||
                _dragStartX >= screenWidth - 80 ||
                _dragStartY >= 400;
            if (!isAllowedCalendarSwipe) {
              return;
            }
          }

          if (swipedLeft) {
            _handleSwipe(true); // Dragged left -> switch to next screen
          } else if (swipedRight) {
            _handleSwipe(false); // Dragged right -> switch to previous screen
          }
        },
        child: Stack(
          children: [
            // 1. ACTIVE SCREEN (Switches based on State with smooth directional slide & fade)
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final offsetTween = Tween<Offset>(
                    begin: Offset(_isSwipingForward ? 0.20 : -0.20, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic));
                  return SlideTransition(
                    position: animation.drive(offsetTween),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey(currentAppId),
                  child: _getScreenForId(currentAppId),
                ),
              ),
            ),

            // 2. BOTTOM GRADIENT FADE (hidden when drawer open)
            if (!_isDrawerOpen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: isLandscape ? 80 : 150,
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
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

            // 3. EDIT MODE OVERLAY (hidden when drawer open, theme adaptive)
            if (_isDockEditing && !_isDrawerOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleEditMode,
                  child: Container(
                    color: isDark
                        ? Colors.black.withOpacity(0.65)
                        : Colors.black.withOpacity(0.2),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.15)
                                : Colors.black.withOpacity(0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.checkmark_circle_fill,
                                size: 16, color: userProvider.accentColor),
                            const SizedBox(width: 8),
                            Text(
                              "Tap anywhere to exit edit mode",
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 4. APP DRAWER (Tray) (hidden when drawer open)
            if (_isDockEditing && !_isDrawerOpen)
              Positioned(
                bottom: isLandscape ? 80 : 130,
                left: isLandscape ? 60 : 20,
                right: isLandscape ? 60 : 20,
                child: _buildAppDrawer(userProvider),
              ),

            // 5. FLOATING DOCK (hidden when sidebar open, supports horizontal swipe)
            if (!_isDrawerOpen)
              Positioned(
                left: isLandscape ? 60 : 20,
                right: isLandscape ? 60 : 20,
                bottom: isLandscape ? 12 : 30,
                child: GestureDetector(
                  onLongPress: _toggleEditMode,
                  onHorizontalDragStart: (_) => _dockDragDistance = 0.0,
                  onHorizontalDragUpdate: (details) =>
                      _dockDragDistance += details.primaryDelta ?? 0.0,
                  onHorizontalDragEnd: (details) {
                    if (_isDockEditing) return;
                    final velocity = details.primaryVelocity ?? 0;
                    if (_dockDragDistance < -30 || velocity < -180) {
                      _handleSwipe(true);
                    } else if (_dockDragDistance > 30 || velocity > 180) {
                      _handleSwipe(false);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: isLandscape ? 56 : 75,
                    decoration: BoxDecoration(
                      color: _isDockEditing
                          ? (isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.06))
                          : (isDark
                              ? const Color(0xFF1C1C1E).withOpacity(0.65)
                              : Colors.white.withOpacity(0.85)),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                          color: isDark
                              ? (_isDockEditing
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1))
                              : (_isDockEditing
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.1)),
                          width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.4)
                                : Colors.grey.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: _isDockEditing
                            ? _buildEditableDockList(userProvider)
                            : _buildPlayableDockList(
                                dockItems, userProvider, currentAppId),
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

  // --- DOCK BUILDERS ---

  Widget _buildPlayableDockList(
      List<String> dockItems, UserProvider provider, String currentId) {
    return Row(
      children: dockItems.map((id) {
        final meta = provider.availableApps[id];
        if (meta == null) return const SizedBox();

        final bool isSelected = currentId == id;
        final IconData icon = meta['icon'] as IconData;

        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final oldIndex = dockItems.indexOf(currentId);
              final newIndex = dockItems.indexOf(id);
              if (newIndex != -1 && oldIndex != -1 && newIndex != oldIndex) {
                setState(() => _isSwipingForward = newIndex > oldIndex);
              }
              HapticFeedback.lightImpact();
              provider.changeView(id);
            },
            child: Container(
              alignment: Alignment.center,
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.15 : 1.0,
                    curve: Curves.easeOutBack,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(icon,
                        color: isSelected
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.4)
                                : Colors.black.withOpacity(0.4)),
                        size: 24),
                  ),
                  const SizedBox(height: 3),
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: provider.accentColor, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditableDockList(UserProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ReorderableListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      onReorder: (oldIndex, newIndex) {
        HapticFeedback.selectionClick();
        provider.reorderDock(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      children: provider.dockItems.map((id) {
        final meta = provider.availableApps[id];
        if (meta == null) return const SizedBox(key: ValueKey('null'));
        final IconData icon = meta['icon'] as IconData;

        return Container(
          key: ValueKey(id),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1)),
                ),
                child: Icon(icon,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 24),
              ),
              Positioned(
                top: -5,
                right: -5,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    provider.removeFromDock(id);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.minus,
                        color: Colors.white, size: 11),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAppDrawer(UserProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final available = provider.availableApps.keys
        .where((k) => !provider.dockItems.contains(k))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C1E).withOpacity(0.95)
            : Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.5)
                : Colors.grey.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.plus_circle,
                  size: 14,
                  color: isDark ? Colors.white70 : Colors.black54),
              const SizedBox(width: 6),
              Text(
                "ADD TO DOCK",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (available.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "All apps are in the dock!",
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            )
          else
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: available.map((id) {
                final meta = provider.availableApps[id];
                if (meta == null) return const SizedBox();
                final IconData icon = meta['icon'] as IconData;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    provider.addToDock(id);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : Colors.black.withOpacity(0.08),
                            )),
                        child: Icon(icon,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 5),
                      Text(meta['label'],
                          style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
