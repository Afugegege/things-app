import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/storage_service.dart';
import '../auth/login_screen.dart'; // Import Login Screen

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final prefs = user.preferences;

    final String currentTheme = prefs['theme'] ?? 'Minimalist Dark';
    
    // Default prefs if null
    final bool bioAuth = prefs['bio_auth'] ?? false;
    final bool notifications = prefs['notifications'] ?? true;
    final bool soundEffects = prefs['sounds'] ?? true;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- SECTION 1: ACCOUNT ---
          _buildSectionHeader("ACCOUNT"),
          _buildContainer(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blueAccent,
                  child: Text(user.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(user.email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(CupertinoIcons.pencil, color: Colors.white, size: 16),
                ),
                onTap: () => _editNameDialog(context, userProvider),
              ),
              _buildDivider(),
              ListTile(
                leading: const Icon(CupertinoIcons.arrow_2_circlepath, color: Colors.blueAccent),
                title: const Text("Switch Account", style: TextStyle(color: Colors.blueAccent)),
                onTap: () => _handleLogout(context), // Goes to login
              ),
              _buildDivider(),
              ListTile(
                leading: const Icon(CupertinoIcons.power, color: Colors.redAccent),
                title: const Text("Log Out", style: TextStyle(color: Colors.redAccent)),
                onTap: () => _handleLogout(context),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // --- SECTION 2: APPEARANCE ---
          _buildSectionHeader("APPEARANCE"),
          _buildContainer(
            children: [
              _buildThemeOption(
                context, 
                title: "Minimalist Dark", 
                value: "Minimalist Dark", 
                groupValue: currentTheme, 
                onChanged: (val) => _updateTheme(context, val),
              ),
              _buildDivider(),
              _buildThemeOption(
                context, 
                title: "Cyberpunk (Neon)", 
                value: "Cyberpunk", 
                groupValue: currentTheme, 
                onChanged: (val) => _updateTheme(context, val),
              ),
              _buildDivider(),
              _buildThemeOption(
                context, 
                title: "OLED Black", 
                value: "OLED Black", 
                groupValue: currentTheme, 
                onChanged: (val) => _updateTheme(context, val),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // --- SECTION 3: GENERAL ---
          _buildSectionHeader("GENERAL"),
          _buildContainer(
            children: [
              _buildSwitchTile(
                context, 
                "Notifications", 
                CupertinoIcons.bell, 
                notifications, 
                (val) => _updatePref(context, 'notifications', val)
              ),
              _buildDivider(),
              _buildSwitchTile(
                context, 
                "Sound Effects", 
                CupertinoIcons.speaker_2, 
                soundEffects, 
                (val) => _updatePref(context, 'sounds', val)
              ),
            ],
          ),

          const SizedBox(height: 30),

          // --- SECTION 4: DATA & SECURITY ---
          _buildSectionHeader("DATA & SECURITY"),
          _buildContainer(
            children: [
              _buildSwitchTile(
                context, 
                "Bio-Auth Lock", 
                CupertinoIcons.lock_shield, 
                bioAuth, 
                (val) => _updatePref(context, 'bio_auth', val)
              ),
              _buildDivider(),
              ListTile(
                leading: const Icon(CupertinoIcons.cloud_download, color: Colors.white),
                title: const Text("Export Data", style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Exporting data to JSON..."))
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 30),

          // --- SECTION 5: ABOUT ---
          _buildSectionHeader("ABOUT"),
          _buildContainer(
            children: [
              const ListTile(
                leading: Icon(CupertinoIcons.info, color: Colors.white),
                title: Text("Version", style: TextStyle(color: Colors.white)),
                trailing: Text("2.1.0 Pro", style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
              "Things OS", 
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontWeight: FontWeight.bold, letterSpacing: 1.5)
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- ACTIONS ---

  void _handleLogout(BuildContext context) async {
    // 1. Clear Token
    await StorageService.clearAuth();
    
    // 2. Navigate to Login (Remove all previous routes)
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _editNameDialog(BuildContext context, UserProvider provider) {
    final controller = TextEditingController(text: provider.user.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Edit Name", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter Name", 
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
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

  void _updateTheme(BuildContext context, String newTheme) {
    _updatePref(context, 'theme', newTheme);
  }

  void _updatePref(BuildContext context, String key, dynamic value) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    // Create a copy of the current preferences map
    final newPrefs = Map<String, dynamic>.from(userProvider.user.preferences);
    newPrefs[key] = value;
    
    // Call the method directly (Type Safe)
    userProvider.updatePreferences(newPrefs);
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 10),
      child: Text(
        title, 
        style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.white.withOpacity(0.1), indent: 16, endIndent: 16);
  }

  Widget _buildSwitchTile(BuildContext context, String title, IconData icon, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      activeColor: Colors.greenAccent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      secondary: Icon(icon, color: Colors.white),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildThemeOption(BuildContext context, {required String title, required String value, required String groupValue, required Function(String) onChanged}) {
    final bool isSelected = value == groupValue;
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: isSelected 
          ? const Icon(CupertinoIcons.checkmark_alt, color: Colors.blueAccent) 
          : null,
      onTap: () => onChanged(value),
    );
  }
}