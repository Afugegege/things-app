import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/user_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/events_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/life_app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final cardColor = theme.cardColor;
    final Color effectiveAccent = userProvider.accentColor;

    return LifeAppScaffold(
      title: "SETTINGS",
      useDrawer: false, // [CRITICAL] Shows Back Button
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- APPEARANCE SECTION ---
          Text("APPEARANCE",
              style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
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
                    activeTrackColor: effectiveAccent,
                    onChanged: (val) => userProvider.toggleTheme(val),
                  ),
                ),
                const Divider(height: 1),
                // Accent Color Swatches
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.paintbrush_fill, color: textColor, size: 20),
                              const SizedBox(width: 12),
                              Text("Accent Color", style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Text(
                            userProvider.isMonoAccent
                                ? "Monochrome"
                                : (UserProvider.presetAccentColors.firstWhere(
                                      (p) => (p['color'] as Color).value == userProvider.accentColor.value,
                                      orElse: () => {'name': 'Custom'},
                                    )['name'] as String),
                            style: TextStyle(
                              color: effectiveAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: UserProvider.presetAccentColors.map((preset) {
                            final isMono = preset['isMono'] == true;
                            final presetColor = preset['color'] as Color;
                            final isSelected = isMono
                                ? userProvider.isMonoAccent
                                : (!userProvider.isMonoAccent && userProvider.accentColor.value == presetColor.value);

                            return GestureDetector(
                              onTap: () {
                                if (isMono) {
                                  userProvider.updateAccentColor(Colors.transparent, isMono: true);
                                } else {
                                  userProvider.updateAccentColor(presetColor, isMono: false);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? (isMono
                                            ? (isDark ? Colors.white : Colors.black)
                                            : presetColor)
                                        : Colors.transparent,
                                    width: 2.2,
                                  ),
                                ),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isMono ? null : presetColor,
                                    gradient: isMono
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.black,
                                              Colors.black.withOpacity(0.8),
                                              Colors.white.withOpacity(0.8),
                                              Colors.white,
                                            ],
                                            stops: const [0.0, 0.5, 0.5, 1.0],
                                          )
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isMono ? Colors.black : presetColor).withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                          color: isMono
                                              ? (isDark ? Colors.white : Colors.black)
                                              : (presetColor.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Glassmorphism Opacity Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.drop, color: textColor, size: 20),
                              const SizedBox(width: 12),
                              Text("Glass Opacity", style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Text(
                            "${(userProvider.glassOpacity * 100).toStringAsFixed(0)}%",
                            style: TextStyle(color: effectiveAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Slider(
                        value: userProvider.glassOpacity.clamp(0.05, 0.50),
                        min: 0.05,
                        max: 0.50,
                        divisions: 9,
                        activeColor: effectiveAccent,
                        inactiveColor: isDark ? Colors.white24 : Colors.black12,
                        onChanged: (val) => userProvider.updateGlassOpacity(val),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Font Selector
                ListTile(
                  leading: Icon(CupertinoIcons.textformat, color: textColor),
                  title: Text("Typography Font", style: TextStyle(color: textColor)),
                  subtitle: Text("Current: ${userProvider.fontFamily}", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: ['Default', 'Outfit', 'Inter', 'Roboto', 'Serif'].contains(userProvider.fontFamily)
                        ? userProvider.fontFamily
                        : 'Default',
                    underline: const SizedBox(),
                    items: ['Default', 'Outfit', 'Inter', 'Roboto', 'Serif'].map((f) {
                      return DropdownMenuItem(value: f, child: Text(f));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) userProvider.updateFontFamily(val);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.download, color: textColor),
                  title: Text("Export All Data",
                      style: TextStyle(color: textColor)),
                  subtitle: Text("Backup as JSON",
                      style:
                          TextStyle(color: secondaryTextColor, fontSize: 12)),
                  trailing: Icon(Icons.share,
                      size: 20, color: effectiveAccent),
                  onTap: () => _exportData(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // --- DANGER ZONE SECTION ---
          Text("DANGER ZONE",
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
            ),
            child: ListTile(
              leading: const Icon(CupertinoIcons.trash_fill, color: Colors.redAccent),
              title: const Text("Delete Everything",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              subtitle: Text("Erase all notes, tasks, events, money & settings",
                  style: TextStyle(color: secondaryTextColor, fontSize: 12)),
              onTap: () => _confirmDeleteEverything(context),
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
      builder: (ctx) =>
          Center(child: CircularProgressIndicator(color: theme.primaryColor)),
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
      final XFile files = XFile.fromData(utf8.encode(jsonString),
          mimeType: 'application/json',
          name: 'things_backup_${DateTime.now().millisecond}.json');

      await Share.shareXFiles([files], text: 'My Things Backup');
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Close loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Export failed: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmDeleteEverything(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E20) : Colors.white,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.08),
            width: 1,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon Badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.trash_fill,
                  color: Colors.redAccent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                "Delete Everything?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                "This action is permanent and cannot be undone. All your notes, tasks, calendar events, wallet records, and custom settings will be completely erased.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 26),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.12),
                        ),
                        foregroundColor:
                            isDark ? Colors.white70 : Colors.black87,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        final notes =
                            Provider.of<NotesProvider>(context, listen: false);
                        final tasks =
                            Provider.of<TasksProvider>(context, listen: false);
                        final money =
                            Provider.of<MoneyProvider>(context, listen: false);
                        final events =
                            Provider.of<EventsProvider>(context, listen: false);
                        final user =
                            Provider.of<UserProvider>(context, listen: false);

                        nav.pop();
                        await StorageService.clearAllData();
                        await money.clearAllData();

                        notes.loadData();
                        tasks.loadTasks();
                        events.loadEvents();
                        user.loadUser();

                        messenger.showSnackBar(const SnackBar(
                          content:
                              Text("All data has been permanently deleted."),
                          backgroundColor: Colors.redAccent,
                          duration: Duration(seconds: 3),
                        ));
                      },
                      child: const Text(
                        "Delete All",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
