import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
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
                    onChanged: (val) => userProvider.toggleTheme(val),
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),
                
                // Accent Color Picker
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Accent Color", style: TextStyle(color: textColor)),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: colors.map((color) {
                            final isSelected = userProvider.accentColor.value == color.value;
                            return GestureDetector(
                              onTap: () => userProvider.updateAccentColor(color),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected 
                                    ? Border.all(color: textColor, width: 3) 
                                    : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
                                  boxShadow: isSelected 
                                    ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)] 
                                    : [],
                                ),
                                child: isSelected 
                                  ? const Icon(Icons.check, color: Colors.black, size: 20) 
                                  : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // --- ACCOUNT SECTION ---
          Text("ACCOUNT", style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Icon(CupertinoIcons.person_fill, color: textColor),
              title: Text("Profile Settings", style: TextStyle(color: textColor)),
              trailing: Icon(CupertinoIcons.chevron_right, size: 16, color: secondaryTextColor),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}