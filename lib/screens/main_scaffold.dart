import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

// Screens
import 'notes/notes_list_screen.dart'; 
import 'tasks/tasks_list_screen.dart';
import 'chat/chat_screen.dart';
import 'calendar/calendar_screen.dart';
import 'user/user_profile_screen.dart';
import 'dashboard/things_grid_screen.dart';
import 'apps/wallet_screen.dart';
import 'apps/roam_screen.dart';
import 'apps/pulse_screen.dart';

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
  String _currentAppId = 'notes'; 
  bool _isDockEditing = false;

  @override
  void initState() {
    super.initState();
    NotificationService.requestPermissions();
  }

  Widget _getScreenForId(String id) {
    switch (id) {
      case 'notes': return ThingsGridScreen(parentScaffoldKey: _mainScaffoldKey);
      case 'tasks': return const TasksListScreen();
      case 'ai': return const ChatScreen();
      case 'calendar': return const CalendarScreen();
      case 'profile': return const UserProfileScreen();
      case 'wallet': return const WalletScreen();
      case 'roam': return const RoamScreen();
      case 'pulse': return const PulseScreen();
      default: return const Center(child: Text("App not found"));
    }
  }

  void _toggleEditMode() {
    setState(() => _isDockEditing = !_isDockEditing);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final dockItems = userProvider.dockItems;

    return Scaffold(
      key: _mainScaffoldKey, 
      backgroundColor: Colors.black,
      drawer: const DashboardDrawer(),
      body: Stack(
        children: [
          // 1. ACTIVE SCREEN
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(_currentAppId),
                child: _getScreenForId(_currentAppId),
              ),
            ),
          ),

          // 2. EDIT MODE OVERLAY
          if (_isDockEditing)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleEditMode,
                child: Container(color: Colors.black.withOpacity(0.7)),
              ),
            ),
          
          // 3. EDIT MODE APP DRAWER
          if (_isDockEditing)
             Positioned(
               bottom: 120, left: 20, right: 20,
               child: _buildAppDrawer(userProvider),
             ),

          // 4. FLOATING DOCK
          Positioned(
            left: 20, right: 20, bottom: 30,
            child: GestureDetector(
              onLongPress: _toggleEditMode,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: _isDockEditing ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: _isDockEditing ? Colors.amber.withOpacity(0.5) : Colors.white.withOpacity(0.1), 
                    width: 1.5
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: _isDockEditing 
                        ? _buildEditableDockList(userProvider)
                        : _buildPlayableDockList(dockItems, userProvider),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A. Normal Mode: Just Icons
  Widget _buildPlayableDockList(List<String> dockItems, UserProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: dockItems.map((id) {
        final meta = provider.availableApps[id];
        final bool isSelected = _currentAppId == id;
        // [FIX] Consuming IconData directly
        final IconData icon = meta['icon'] as IconData;

        return GestureDetector(
          onTap: () {
            setState(() => _currentAppId = id);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            child: AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.white38, size: 26),
            ),
          ),
        );
      }).toList(),
    );
  }

  // B. Edit Mode: Reorderable List
  Widget _buildEditableDockList(UserProvider provider) {
    return ReorderableListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      onReorder: provider.reorderDock,
      children: provider.dockItems.map((id) {
        final meta = provider.availableApps[id];
        // [FIX] Consuming IconData directly
        final IconData icon = meta['icon'] as IconData;
        
        return Container(
          key: ValueKey(id),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => provider.removeFromDock(id),
                child: const Icon(Icons.remove_circle, color: Colors.white, size: 14),
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  // C. App Drawer
  Widget _buildAppDrawer(UserProvider provider) {
    final available = provider.availableApps.keys.where((k) => !provider.dockItems.contains(k)).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DRAG TO DOCK", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          if (available.isEmpty)
             const Text("All apps are in the dock!", style: TextStyle(color: Colors.white38))
          else
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: available.map((id) {
                final meta = provider.availableApps[id];
                // [FIX] Consuming IconData directly
                final IconData icon = meta['icon'] as IconData;
                
                return GestureDetector(
                  onTap: () => provider.addToDock(id),
                  child: Column(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
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