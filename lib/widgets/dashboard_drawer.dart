import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/notes_provider.dart';
import '../widgets/profile_avatar.dart';
import '../models/note_model.dart';
import 'package:uuid/uuid.dart';
import '../widgets/glass_container.dart';

// SCREEN IMPORTS
import '../screens/notes/note_editor_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/user/user_profile_screen.dart';
import '../screens/tasks/tasks_list_screen.dart';
import '../screens/apps/brain_screen.dart';
import '../screens/apps/wallet_screen.dart';
import '../screens/apps/pulse_screen.dart';
import '../screens/apps/roam_screen.dart';
import '../screens/tools/flashcard_screen.dart';
import '../screens/tools/bucket_list_screen.dart';

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    
    final userProvider = Provider.of<UserProvider>(context);
    final notesProvider = Provider.of<NotesProvider>(context);
    final folders = notesProvider.folders;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      width: 300,
      child: Column(
        children: [
          // 1. User Header
          GestureDetector(
            onTap: () {
              Navigator.pop(context); 
              userProvider.changeView('profile');
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              ),
              child: Row(
                children: [
                  const ProfileAvatar(radius: 24),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userProvider.user.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                        Text("View Profile", style: TextStyle(fontSize: 12, color: theme.primaryColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.settings, size: 20),
                    color: textColor,
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  )
                ],
              ),
            ),
          ),

          // 2. Navigation Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                // APPS SECTION
                _buildSectionHeader(context, "APPS"),
                
                // Dashboard (Root)
                _buildMenuItem(
                  context, 
                  icon: CupertinoIcons.home, 
                  label: "Dashboard", 
                  onTap: () {
                    // This logic ensures we go back to the very first screen (Dashboard)
                    // and clear any other screens stacked on top.
                    Navigator.pop(context); // Close drawer
                    Navigator.popUntil(context, (route) => route.isFirst);
                    userProvider.changeView('dashboard');
                  }
                ),

                // Sub-Apps (Using changeView to keep dock visible)
                _buildMenuItem(context, icon: CupertinoIcons.chat_bubble_2, label: "AI Assistant", onTap: () => _navTo(context, userProvider, 'ai')),
                _buildMenuItem(context, icon: CupertinoIcons.doc_text, label: "Notes", onTap: () => _navTo(context, userProvider, 'notes')),
                _buildMenuItem(context, icon: CupertinoIcons.check_mark_circled, label: "Tasks", onTap: () => _navTo(context, userProvider, 'tasks')),
                _buildMenuItem(context, icon: CupertinoIcons.money_dollar_circle, label: "Finance", onTap: () => _navTo(context, userProvider, 'wallet')),
                _buildMenuItem(context, icon: CupertinoIcons.heart, label: "Health", onTap: () => _navTo(context, userProvider, 'pulse')),
                _buildMenuItem(context, icon: CupertinoIcons.airplane, label: "Travel", onTap: () => _navTo(context, userProvider, 'roam')),
                _buildMenuItem(context, icon: CupertinoIcons.bolt_horizontal_circle, label: "Flashcards", onTap: () => _navTo(context, userProvider, 'flashcards')),
                _buildMenuItem(context, icon: CupertinoIcons.star_circle, label: "Bucket List", onTap: () => _navTo(context, userProvider, 'bucket')),

                const SizedBox(height: 30),
                
                // FOLDERS SECTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader(context, "COLLECTIONS"),
                    IconButton(
                      icon: Icon(Icons.add, size: 20, color: secondaryTextColor),
                      onPressed: () => _showAddFolderDialog(context, notesProvider),
                      tooltip: "New Folder",
                    ),
                  ],
                ),
                
                if (folders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: Text("No collections yet.", style: TextStyle(color: secondaryTextColor, fontSize: 13, fontStyle: FontStyle.italic)),
                  ),

                ...folders.map((folder) {
                  final isProtected = folder == 'All' || folder == 'General';
                  return _buildFolderItem(context, folder, notesProvider, isProtected);
                }),
              ],
            ),
          ),
          
          // 3. Footer
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text("v1.0.4", style: TextStyle(color: secondaryTextColor.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  // --- HELPERS ---

  void _navTo(BuildContext context, UserProvider provider, String viewId) {
    Navigator.pop(context); // Close Drawer
    Navigator.popUntil(context, (route) => route.isFirst); // Clear stack
    provider.changeView(viewId);
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // Updated builder to handle both direct onTap (Dashboard) and Widget targets (Apps)
  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String label, Widget? target, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodyLarge?.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () {
          if (onTap != null) {
            onTap();
          } else if (target != null) {
            Navigator.pop(context); // Close Drawer first
            Navigator.push(context, MaterialPageRoute(builder: (_) => target));
          }
        },
      ),
    );
  }

  Widget _buildFolderItem(BuildContext context, String folder, NotesProvider notesProvider, bool isProtected) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final isSelected = notesProvider.selectedFolder == folder;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? theme.primaryColor.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.only(left: 12, right: 5),
        leading: Icon(
          isSelected ? CupertinoIcons.folder_open : CupertinoIcons.folder, 
          size: 18, 
          color: isSelected ? Provider.of<UserProvider>(context).accentColor : theme.textTheme.bodyMedium?.color
        ),
        title: Text(folder, style: TextStyle(color: textColor, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        trailing: SizedBox(
          width: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _showFolderAddOptions(context, folder, notesProvider),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.add, size: 20, color: theme.textTheme.bodyMedium?.color),
                ),
              ),
              if (!isProtected) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _confirmDeleteFolder(context, folder, notesProvider),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(CupertinoIcons.trash, size: 18, color: Colors.redAccent.withOpacity(0.6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        onTap: () {
          notesProvider.selectFolder(folder);
          Navigator.pop(context);
          // Navigate to Dashboard (Folder View)
          Provider.of<UserProvider>(context, listen: false).changeView('dashboard');
        },
      ),
    );
  }

  // --- ACTIONS & POPUPS ---

  void _showFolderAddOptions(BuildContext context, String folder, NotesProvider provider) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text("ADD TO '$folder'", style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
              const SizedBox(height: 20),
              
              // Option 1: Create Note
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(CupertinoIcons.doc_text, color: Colors.blueAccent)),
                title: const Text("Create Note"),
                subtitle: const Text("Start writing a new entry"),
                onTap: () {
                  Navigator.pop(ctx); // Close Sheet
                  Navigator.pop(context); // Close Drawer
                  // Set folder and open editor
                  provider.selectFolder(folder);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditorScreen()));
                },
              ),
              
              const SizedBox(height: 10),

              // Option 2: Add Widget
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(CupertinoIcons.square_grid_2x2, color: Colors.purpleAccent)),
                title: const Text("Add Widget"),
                subtitle: const Text("Create a tool or sticker"),
                onTap: () {
                  Navigator.pop(ctx); 
                  _showWidgetTypeSelector(context, folder, provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWidgetTypeSelector(BuildContext context, String folder, NotesProvider provider) {
     final theme = Theme.of(context);
     
     showModalBottomSheet(
       context: context,
       backgroundColor: theme.cardColor,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
       builder: (ctx) => SafeArea(
         child: Container(
           padding: const EdgeInsets.all(20),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                Text("SELECT WIDGET TYPE", style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildWidgetOption(ctx, "Sticker", CupertinoIcons.smiley, Colors.orangeAccent, folder, provider, 'sticker'),
                    _buildWidgetOption(ctx, "Monitor", CupertinoIcons.graph_circle, Colors.greenAccent, folder, provider, 'monitor'),
                    _buildWidgetOption(ctx, "Quote", CupertinoIcons.quote_bubble, Colors.blueAccent, folder, provider, 'quote'),
                    _buildWidgetOption(ctx, "Timer", CupertinoIcons.timer, Colors.redAccent, folder, provider, 'timer'),
                  ],
                )
             ],
           ),
         ),
       )
     );
  }

  Widget _buildWidgetOption(BuildContext context, String label, IconData icon, Color color, String folder, NotesProvider provider, String type) {
    return GestureDetector(
      onTap: () {
        // Create Widget Note
        final newWidget = Note(
          id: const Uuid().v4(),
          title: "$label Widget",
          content: "",
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          folder: folder,
          widgetType: type,
          backgroundColor: color.value,
        );
        provider.addNote(newWidget);
        provider.selectFolder(folder);
        Navigator.pop(context); // Close Selector
        Navigator.pop(context); // Close Drawer
        // Go to Brain Screen
        provider.selectFolder(folder);
        Provider.of<UserProvider>(context, listen: false).changeView('notes');
      },
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 11)),
        ],
      ),
    );
  }

  void _showAddFolderDialog(BuildContext context, NotesProvider provider) {
    final controller = TextEditingController();
    final Set<String> selectedWidgets = {'Tasks', 'Events'}; // Defaults

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final accentColor = Provider.of<UserProvider>(context).accentColor;

          Widget _buildWidgetToggle(String label, IconData icon, Color color, String key) {
             final bool isSelected = selectedWidgets.contains(key);
             return GestureDetector(
               onTap: () {
                 setState(() {
                   if (isSelected) selectedWidgets.remove(key);
                   else selectedWidgets.add(key);
                 });
               },
               child: Container(
                 width: 80, 
                 padding: const EdgeInsets.symmetric(vertical: 10),
                 decoration: BoxDecoration(
                   color: isSelected ? color.withOpacity(0.2) : theme.dividerColor.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(15),
                   border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
                 ),
                 child: Column(
                   children: [
                     Icon(icon, color: isSelected ? color : theme.disabledColor, size: 24),
                     const SizedBox(height: 5),
                     Text(label, style: TextStyle(color: isSelected ? textColor : theme.disabledColor, fontSize: 10, fontWeight: FontWeight.bold))
                   ],
                 ),
               ),
             );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 25, left: 25, right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 25),
                Text("NEW COLLECTION", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 20),
                
                // Name Input
                CupertinoTextField(
                  controller: controller,
                  placeholder: "Collection Name (e.g. Work, Study)",
                  placeholderStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  style: TextStyle(color: textColor),
                  autofocus: true,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                
                const SizedBox(height: 25),
                Text("INCLUDE DASHBOARD WIDGETS", style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                
                // Widgets Grid
                Wrap(
                  spacing: 12, runSpacing: 12,
                  children: [
                    _buildWidgetToggle("Tasks", CupertinoIcons.check_mark_circled, Colors.greenAccent, 'Tasks'),
                    _buildWidgetToggle("Money", CupertinoIcons.money_dollar, Colors.redAccent, 'Money'),
                    _buildWidgetToggle("Events", CupertinoIcons.calendar, Colors.orangeAccent, 'Events'),
                    _buildWidgetToggle("Roam", CupertinoIcons.airplane, Colors.blueAccent, 'Roam'),
                    _buildWidgetToggle("Flashcards", CupertinoIcons.bolt_horizontal, Colors.purpleAccent, 'Flashcards'),
                    _buildWidgetToggle("Bucket", CupertinoIcons.star, Colors.amber, 'Bucket'),
                  ],
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(15),
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        final String newFolder = controller.text.trim();
                        // 1. Create Folder
                        provider.addFolder(newFolder);
                        // 2. Add Widgets
                        for (var w in selectedWidgets) {
                          provider.toggleFolderWidget(newFolder, w);
                        }
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text("Create Collection", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, String folder, NotesProvider provider) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Collection?"),
        content: Text("Are you sure you want to delete '$folder'?\nNotes inside will be moved to 'All'.", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () {
              provider.deleteFolder(folder);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}