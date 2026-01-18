import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final accentColor = userProvider.accentColor;

    return LifeAppScaffold(
      title: "PROFILE",
      useDrawer: false, // [FIX] Disable drawer to show Back button
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Header
            StreamBuilder<AuthState>(
              stream: AuthService.authStateChanges,
              builder: (context, snapshot) {
                final user = AuthService.currentUser;
                final isLoggedIn = user != null;
                final displayName = user?.userMetadata?['full_name'] ?? user?.email ?? userProvider.user.name;

                return Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                          border: Border.all(color: textColor.withOpacity(0.2), width: 2),
                          image: (isLoggedIn && user?.userMetadata?['avatar_url'] != null)
                             ? DecorationImage(image: NetworkImage(user!.userMetadata!['avatar_url']), fit: BoxFit.cover)
                             : null
                        ),
                        child: (isLoggedIn && user?.userMetadata?['avatar_url'] != null) 
                            ? null 
                            : Icon(CupertinoIcons.person_solid, size: 50, color: textColor),
                      ),
                      const SizedBox(height: 15),
                      Text(displayName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                      if (isLoggedIn)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(user!.email ?? "", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                        ),
                      const SizedBox(height: 15),
                      
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "PRO MEMBER",
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (isLoggedIn)
                             GestureDetector(
                               onTap: () async {
                                 await AuthService.signOut();
                                 Navigator.popUntil(context, (r) => r.isFirst);
                                 Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                               },
                               child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.redAccent)
                                ),
                                child: const Text("Sign Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                               ),
                             )
                          else
                             GestureDetector(
                               onTap: () {
                                 Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                               },
                               child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: theme.primaryColor)
                                ),
                                child: Text("Sign In", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                               ),
                             )

                        ],
                      ),
                    ],
                  ),
                );
              }
            ),

            const SizedBox(height: 40),

            // 2. Settings Section
            // 2. Settings Section
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text("SETTINGS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: secondaryTextColor, letterSpacing: 2)),
            ),
            const SizedBox(height: 15),
            _buildSettingsTile(
              context,
              icon: CupertinoIcons.cloud_upload,
              title: "Backup Data",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Backing up to Cloud... Done."), backgroundColor: Colors.green)
                );
              },
            ),

            _buildSettingsTile(
              context,
              icon: CupertinoIcons.lock,
              title: "Privacy & Security",
              onTap: () {},
            ),

            const SizedBox(height: 30),

            // 3. AI Memory Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text("AI MEMORY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: secondaryTextColor, letterSpacing: 2)),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: textColor),
                  onPressed: () => _showAddMemoryDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            if (user.aiMemory.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("Teach AI about you to personalize suggestions.", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
              )),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: user.aiMemory.length,
              itemBuilder: (context, index) {
                final memory = user.aiMemory[index];
                return Dismissible(
                  key: Key(memory),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    userProvider.removeMemory(memory);
                  },
                  child: GlassContainer(
                    margin: const EdgeInsets.only(bottom: 10),
                    height: 60,
                    borderRadius: 15,
                    opacity: isDark ? 0.1 : 0.05,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.psychology, color: userProvider.accentColor, size: 24),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              memory,
                              style: TextStyle(color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, Widget? trailing}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 10),
        height: 60,
        borderRadius: 15,
        opacity: isDark ? 0.05 : 0.03,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 15),
              Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (trailing != null) ...[trailing!, const SizedBox(width: 10)],
              Icon(Icons.chevron_right, color: theme.textTheme.bodyMedium?.color),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMemoryDialog(BuildContext context) {
    final ctrl = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
        final isDark = theme.brightness == Brightness.dark;
        final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 40, top: 25, left: 25, right: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 25),
              Text("TEACH AI A NEW FACT", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 20),
              
              CupertinoTextField(
                controller: ctrl,
                placeholder: "e.g., I am allergic to peanuts",
                placeholderStyle: TextStyle(color: secondaryTextColor),
                style: TextStyle(color: textColor),
                decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(16),
                autofocus: true,
              ),
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: textColor,
                  borderRadius: BorderRadius.circular(15),
                  child: Text("Add Memory", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (ctrl.text.isNotEmpty) {
                      Provider.of<UserProvider>(context, listen: false).addMemory(ctrl.text);
                    }
                    Navigator.pop(ctx);
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

