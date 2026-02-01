import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/user_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/life_app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final cardColor = theme.cardColor;
    
    // Palette Options
    final List<Color> colors = [
      Colors.white, 
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.redAccent,
    ];

    return LifeAppScaffold(
      title: "SETTINGS",
      useDrawer: false, // [CRITICAL] Shows Back Button
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- APPEARANCE SECTION ---
          Text("APPEARANCE", style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Dark Mode Switch
                ListTile(
                  leading: Icon(CupertinoIcons.moon_fill, color: textColor),
                  title: Text("Dark Mode", style: TextStyle(color: textColor)),
                  trailing: CupertinoSwitch(
                    value: userProvider.isDarkMode,
                    activeColor: userProvider.accentColor,
                    onChanged: (val) => userProvider.toggleTheme(val),
                  ),
                ),
// ...
                ListTile(
                  leading: Icon(Icons.download, color: textColor),
                  title: Text("Export All Data", style: TextStyle(color: textColor)),
                  subtitle: Text("Backup as JSON", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                  trailing: Icon(Icons.share, size: 20, color: userProvider.accentColor),
                  onTap: () => _exportData(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(child: CircularProgressIndicator(color: theme.primaryColor)),
    );

    try {
      // 1. Gather all data
      final Map<String, dynamic> allData = {
        'export_date': DateTime.now().toIso8601String(),
        'user': StorageService.loadUser()?.toJson(),
        'notes': StorageService.loadNotes().map((e) => e.toJson()).toList(),
        'tasks': StorageService.loadTasks().map((e) => e.toJson()).toList(),
        'finance': StorageService.loadTransactions(),
        'finance_settings': StorageService.loadMoneySettings(),
        'roam_trips': StorageService.loadTrips(),
        'pulse_health': StorageService.loadHealthData(),
        'chat_history': StorageService.loadChatHistory(),
        'folder_widgets': StorageService.loadFolderWidgets(),
      };

      // 2. Convert to JSON
      final String jsonString = jsonEncode(allData);

      if (context.mounted) Navigator.pop(context); // Close loading

      // 3. Share using Memory (Web Safe)
      final XFile files = XFile.fromData(
        utf8.encode(jsonString),
        mimeType: 'application/json',
        name: 'things_backup_${DateTime.now().millisecond}.json'
      );

      await Share.shareXFiles([files], text: 'My Things Backup');

    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Close loading
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e"), backgroundColor: Colors.red));
      }
    }
  }
}