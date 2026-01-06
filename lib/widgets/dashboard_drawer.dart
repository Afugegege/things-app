import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/user_provider.dart';
import '../providers/notes_provider.dart';

// Screens
import '../screens/settings/settings_screen.dart';
import '../screens/user/user_profile_screen.dart';
import '../screens/apps/wallet_screen.dart';
import '../screens/apps/roam_screen.dart';
import '../screens/tasks/tasks_list_screen.dart';
import '../screens/notes/notes_list_screen.dart'; // Keep this for now if needed, but BrainScreen replaces it conceptually for "Brain"
import '../screens/apps/pulse_screen.dart';
import '../screens/apps/brain_screen.dart'; // <--- ADD THIS IMPORT

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final notesProvider = Provider.of<NotesProvider>(context);
    final user = userProvider.user;

    return Drawer(
      backgroundColor: Colors.transparent,
      width: 320,
      child: Stack(
        children: [
          // 1. FROSTED GLASS BACKGROUND
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF050505).withOpacity(0.9), // Deep matte black
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
                    padding: const EdgeInsets.fromLTRB(25, 40, 25, 30),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 15)],
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white10,
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : "U",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.withOpacity(0.5), width: 0.5),
                              ),
                              child: const Text("PRO MEMBER", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const Divider(color: Colors.white10, height: 1),

                // --- SCROLLABLE LIST ---
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                    children: [
                      _sectionHeader("LIFE APPS"),
                      _buildAppRow(context, "Wallet", CupertinoIcons.money_dollar, const WalletScreen(), userProvider),
                      _buildAppRow(context, "Roam", CupertinoIcons.map, const RoamScreen(), userProvider),
                      _buildAppRow(context, "Focus", CupertinoIcons.checkmark_alt_circle, const TasksListScreen(), userProvider),
                      // LINK BRAIN APP TO BRAIN SCREEN
                      _buildAppRow(context, "Brain", CupertinoIcons.lightbulb, const BrainScreen(), userProvider),
                      _buildAppRow(context, "Pulse", CupertinoIcons.heart, const PulseScreen(), userProvider),

                      const SizedBox(height: 35),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionHeader("COLLECTIONS"),
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Icon(Icons.add, color: Colors.white.withOpacity(0.3), size: 18),
                          ),
                        ],
                      ),
                      
                      // DYNAMIC FOLDERS
                      ...notesProvider.folders.map((folder) {
                        return _buildFolderRow(context, folder, userProvider);
                      }),
                      
                      // Quick Add Button
                      GestureDetector(
                        onTap: () => notesProvider.createFolder("New Folder ${notesProvider.folders.length + 1}"),
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, left: 10),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Colors.white.withOpacity(0.4), size: 18),
                              const SizedBox(width: 12),
                              Text("Create Collection", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- SETTINGS FOOTER ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(CupertinoIcons.settings, color: Colors.white70, size: 20),
                    ),
                    title: const Text("Settings", style: TextStyle(color: Colors.white, fontSize: 16)),
                    trailing: const Icon(CupertinoIcons.chevron_forward, color: Colors.white24, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
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
      padding: const EdgeInsets.fromLTRB(10, 0, 0, 15),
      child: Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
    );
  }

  // APP ROW: Custom Checkbox + Title
  Widget _buildAppRow(BuildContext context, String name, IconData icon, Widget screen, UserProvider userProvider) {
    final isVisible = userProvider.appVisibility[name] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // 1. The Toggle (Sleek Circle)
          GestureDetector(
            onTap: () => userProvider.toggleAppVisibility(name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              margin: const EdgeInsets.only(right: 15, left: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isVisible ? Colors.white : Colors.transparent,
                border: Border.all(color: isVisible ? Colors.white : Colors.white24, width: 2),
                boxShadow: isVisible ? [BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 8)] : [],
              ),
              child: isVisible 
                ? const Icon(Icons.check, size: 14, color: Colors.black) 
                : null,
            ),
          ),

          // 2. The Navigation Tile
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  child: Row(
                    children: [
                      Icon(icon, color: isVisible ? Colors.white : Colors.white38, size: 20),
                      const SizedBox(width: 15),
                      Text(
                        name, 
                        style: TextStyle(
                          color: isVisible ? Colors.white : Colors.white38, 
                          fontSize: 16, 
                          fontWeight: isVisible ? FontWeight.w600 : FontWeight.normal
                        )
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FOLDER ROW
  Widget _buildFolderRow(BuildContext context, String folder, UserProvider userProvider) {
    final isVisible = userProvider.isFolderVisible(folder);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Toggle
          GestureDetector(
            onTap: () => userProvider.toggleFolderVisibility(folder),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              margin: const EdgeInsets.only(right: 15, left: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6), // Squared for folders
                color: isVisible ? Colors.blueAccent : Colors.transparent,
                border: Border.all(color: isVisible ? Colors.blueAccent : Colors.white24, width: 2),
                boxShadow: isVisible ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 8)] : [],
              ),
              child: isVisible 
                ? const Icon(Icons.check, size: 14, color: Colors.white) 
                : null,
            ),
          ),

          // Name
          Expanded(
            child: Text(
              folder, 
              style: TextStyle(
                color: isVisible ? Colors.white : Colors.white38, 
                fontSize: 16,
                fontWeight: isVisible ? FontWeight.w500 : FontWeight.normal
              )
            ),
          ),
        ],
      ),
    );
  }
}