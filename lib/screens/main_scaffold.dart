import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';

// Screens
import 'notes/notes_list_screen.dart'; 
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
      case 'brain': return const BrainScreen(); 
      case 'tasks': return const TasksListScreen();
      case 'ai': return const ChatScreen();
      case 'calendar': return const CalendarScreen();
      case 'wallet': return const WalletScreen();
      case 'profile': return const UserProfileScreen();
      // Settings and Profile are handled by Navigator.push, not here.
      default: return ThingsGridScreen(parentScaffoldKey: _mainScaffoldKey);
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

    return Scaffold(
      key: _mainScaffoldKey, 
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const DashboardDrawer(),
      
      body: Stack(
        children: [
          // 1. ACTIVE SCREEN (Switches based on State)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(currentAppId),
                child: _getScreenForId(currentAppId),
              ),
            ),
          ),

          // 2. BOTTOM GRADIENT FADE
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 150,
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

          // 3. EDIT MODE OVERLAY
          if (_isDockEditing)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleEditMode,
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Text("Tap to Exit Edit Mode", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          
          // 4. APP DRAWER (Tray)
          if (_isDockEditing)
             Positioned(
               bottom: 130, left: 20, right: 20,
               child: _buildAppDrawer(userProvider),
             ),

          // 5. FLOATING DOCK
          Positioned(
            left: 20, right: 20, bottom: 30,
            child: GestureDetector(
              onLongPress: _toggleEditMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 75,
                decoration: BoxDecoration(
                  color: _isDockEditing 
                      ? (theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1))
                      : (theme.brightness == Brightness.dark 
                          ? const Color(0xFF1C1C1E).withOpacity(0.65) 
                          : Colors.white.withOpacity(0.85)), 
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark 
                        ? (_isDockEditing ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1))
                        : (_isDockEditing ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
                    width: 1.5
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.brightness == Brightness.dark 
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
                        : _buildPlayableDockList(dockItems, userProvider, currentAppId),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DOCK BUILDERS ---

  Widget _buildPlayableDockList(List<String> dockItems, UserProvider provider, String currentId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: dockItems.map((id) {
        final meta = provider.availableApps[id];
        if (meta == null) return const SizedBox();

        final bool isSelected = currentId == id;
        final IconData icon = meta['icon'] as IconData;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact(); 
            provider.changeView(id);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: AnimatedScale(
              scale: isSelected ? 1.3 : 1.0,
              curve: Curves.elasticOut,
              duration: const Duration(milliseconds: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon, 
                    color: isSelected 
                        ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black) 
                        : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4)), 
                    size: 28
                  ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 4, height: 4, 
                        decoration: BoxDecoration(color: provider.accentColor, shape: BoxShape.circle),
                      )
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditableDockList(UserProvider provider) {
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
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                ),
                child: Icon(icon, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, size: 24),
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
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800, 
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(CupertinoIcons.minus, color: Colors.white, size: 12),
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
    final available = provider.availableApps.keys.where((k) => !provider.dockItems.contains(k)).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DRAG TO DOCK", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 15),
          if (available.isEmpty)
             const Padding(
               padding: EdgeInsets.all(8.0),
               child: Text("All apps are in the dock!", style: TextStyle(color: Colors.white38)),
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
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white10, 
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white12)
                        ),
                        child: Icon(icon, color: Colors.white),
                      ),
                      const SizedBox(height: 5),
                      Text(meta['label'], style: const TextStyle(color: Colors.white70, fontSize: 10)),
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