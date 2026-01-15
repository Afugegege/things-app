import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/notes_provider.dart';

// Screens
import '../screens/main_scaffold.dart'; // For Dashboard reset
import '../screens/settings/settings_screen.dart';
import '../screens/user/user_profile_screen.dart';
import '../screens/apps/wallet_screen.dart';
import '../screens/apps/roam_screen.dart';
import '../screens/tasks/tasks_list_screen.dart';
import '../screens/apps/brain_screen.dart';
import '../screens/apps/pulse_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/tools/flashcard_screen.dart';
import '../screens/tools/bucket_list_screen.dart';

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final notesProvider = Provider.of<NotesProvider>(context);
    final user = userProvider.user;

    return Drawer(
      backgroundColor: Colors.transparent,
      width: 300,
      child: Stack(
        children: [
          // 1. BLURRED BACKGROUND
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withOpacity(0.85),
                border: const Border(right: BorderSide(color: Colors.white10)),
              ),
            ),
          ),

          // 2. CONTENT
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- PROFILE HEADER ---
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.blueAccent,
                          child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : "U", 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Text("View Profile", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const Divider(color: Colors.white10, height: 1),

                // --- MAIN NAVIGATION ---
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    children: [
                      // 1. DASHBOARD HOME
                      _buildNavItem(context, "Dashboard", CupertinoIcons.home, onTap: () {
                        // Pop everything to go back to MainScaffold root
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }, isHighlight: true),

                      const SizedBox(height: 20),
                      _sectionHeader("CORE APPS"),
                      
                      _buildNavItem(context, "Plan", CupertinoIcons.calendar, 
                        screen: const CalendarScreen()),
                      _buildNavItem(context, "Companion", CupertinoIcons.sparkles, 
                        screen: const ChatScreen()),
                      _buildNavItem(context, "Focus", CupertinoIcons.check_mark_circled, 
                        screen: const TasksListScreen()),
                      _buildNavItem(context, "Brain", CupertinoIcons.lightbulb, 
                        screen: const BrainScreen()),
                      _buildNavItem(context, "Wallet", CupertinoIcons.money_dollar, 
                        screen: const WalletScreen()),
                      _buildNavItem(context, "Roam", CupertinoIcons.map, 
                        screen: const RoamScreen()),
                      _buildNavItem(context, "Pulse", CupertinoIcons.heart, 
                        screen: const PulseScreen()),

                      const SizedBox(height: 20),
                      _sectionHeader("TOOLS"),
                      
                      _buildNavItem(context, "Flashcards", CupertinoIcons.book, 
                        screen: const FlashCardScreen()),
                      _buildNavItem(context, "Bucket List", CupertinoIcons.star, 
                        screen: const BucketListScreen()),

                      const SizedBox(height: 20),
                      _sectionHeader("COLLECTIONS"),
                      
                      // Dynamic Folders
                      ...notesProvider.folders.map((folder) => 
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder, color: Colors.white38, size: 18),
                          title: Text(folder, style: const TextStyle(color: Colors.white70)),
                          onTap: () {
                            notesProvider.selectFolder(folder);
                            Navigator.pop(context); // Close drawer to see filtered dashboard
                          },
                        )
                      ),
                    ],
                  ),
                ),

                // --- SETTINGS ---
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: const Icon(CupertinoIcons.settings, color: Colors.white54),
                  title: const Text("Settings", style: TextStyle(color: Colors.white54)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, bottom: 10),
      child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildNavItem(BuildContext context, String title, IconData icon, {Widget? screen, VoidCallback? onTap, bool isHighlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: isHighlight ? BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ) : null,
      child: ListTile(
        leading: Icon(icon, color: isHighlight ? Colors.blueAccent : Colors.white70, size: 22),
        title: Text(title, style: TextStyle(color: isHighlight ? Colors.white : Colors.white70, fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal)),
        onTap: onTap ?? () {
          Navigator.pop(context);
          if (screen != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
          }
        },
      ),
    );
  }
}