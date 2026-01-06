import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/glass_container.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(CupertinoIcons.person_solid, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.isPro ? "PRO MEMBER" : "FREE TIER",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 2. Settings Section
            const Text("Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white54)),
            const SizedBox(height: 10),
            _buildSettingsTile(
              icon: CupertinoIcons.cloud_upload,
              title: "Backup Data",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Backing up to Cloud... Done."), backgroundColor: Colors.green)
                );
              },
            ),
            _buildSettingsTile(
              icon: CupertinoIcons.lock,
              title: "Privacy & Security",
              onTap: () {},
            ),

            const SizedBox(height: 30),

            // 3. AI Memory Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("AI Memory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white54)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.white),
                  onPressed: () => _showAddMemoryDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
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
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    userProvider.removeMemory(memory);
                  },
                  child: GlassContainer(
                    margin: const EdgeInsets.only(bottom: 10),
                    height: 60,
                    borderRadius: 15,
                    opacity: 0.1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.psychology, color: Colors.purpleAccent, size: 24),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              memory,
                              style: const TextStyle(color: Colors.white),
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

  Widget _buildSettingsTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        margin: const EdgeInsets.only(bottom: 10),
        height: 60,
        borderRadius: 15,
        opacity: 0.05,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 15),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMemoryDialog(BuildContext context) {
    String newFact = "";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Teach AI a new fact", style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g., I am allergic to peanuts",
            hintStyle: TextStyle(color: Colors.white38),
          ),
          onChanged: (val) => newFact = val,
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (newFact.isNotEmpty) {
                Provider.of<UserProvider>(context, listen: false).addMemory(newFact);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }
}