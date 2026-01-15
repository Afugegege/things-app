import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/storage_service.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final prefs = user.preferences;
    final isDark = userProvider.isDarkMode;
    
    // Dynamic Colors based on theme context
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- SECTION 1: ACCOUNT ---
          _buildSectionHeader(context, "ACCOUNT"),
          _buildContainer(
            context,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blueAccent,
                  child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : "U", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(user.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(user.email, style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: textColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(CupertinoIcons.pencil, color: textColor, size: 16),
                ),
                onTap: () => _editNameDialog(context, userProvider),
              ),
              _buildDivider(context),
              ListTile(
                leading: const Icon(CupertinoIcons.power, color: Colors.redAccent),
                title: const Text("Log Out", style: TextStyle(color: Colors.redAccent)),
                onTap: () => _handleLogout(context),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // --- SECTION 2: APPEARANCE ---
          _buildSectionHeader(context, "APPEARANCE"),
          _buildContainer(
            context,
            children: [
              SwitchListTile(
                activeColor: Colors.blueAccent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                title: Text("Dark Mode", style: TextStyle(color: textColor, fontSize: 16)),
                secondary: Icon(isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill, color: textColor),
                value: isDark,
                onChanged: (val) => userProvider.toggleTheme(val),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // --- SECTION 3: GENERAL ---
          _buildSectionHeader(context, "GENERAL"),
          _buildContainer(
            context,
            children: [
              _buildSwitchTile(
                context, 
                "Notifications", 
                CupertinoIcons.bell, 
                prefs['notifications'] ?? true, 
                (val) => _updatePref(context, 'notifications', val)
              ),
              _buildDivider(context),
              _buildSwitchTile(
                context, 
                "Sound Effects", 
                CupertinoIcons.speaker_2, 
                prefs['sounds'] ?? true, 
                (val) => _updatePref(context, 'sounds', val)
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ACTIONS ---

  void _handleLogout(BuildContext context) async {
    await StorageService.clearAuth();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _editNameDialog(BuildContext context, UserProvider provider) {
    final controller = TextEditingController(text: provider.user.name);
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final cardColor = Theme.of(context).cardColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text("Edit Name", style: TextStyle(color: textColor)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: "Enter Name", 
            hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor.withOpacity(0.2))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: textColor.withOpacity(0.5)))),
          TextButton(
            onPressed: () {
              provider.updateName(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _updatePref(BuildContext context, String key, dynamic value) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final newPrefs = Map<String, dynamic>.from(userProvider.user.preferences);
    newPrefs[key] = value;
    userProvider.updatePreferences(newPrefs);
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 10),
      child: Text(
        title, 
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.4), 
          fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2
        ),
      ),
    );
  }

  Widget _buildContainer(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(height: 1, color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.1), indent: 16, endIndent: 16);
  }

  Widget _buildSwitchTile(BuildContext context, String title, IconData icon, bool value, Function(bool) onChanged) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    return SwitchListTile(
      activeColor: Colors.blueAccent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 16)),
      secondary: Icon(icon, color: textColor),
      value: value,
      onChanged: onChanged,
    );
  }
}