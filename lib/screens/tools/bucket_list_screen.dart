import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/life_app_scaffold.dart'; // [UPDATED] Theme
import '../../widgets/glass_container.dart';

import 'package:provider/provider.dart';
import '../../providers/bucket_list_provider.dart';
import '../../models/bucket_item_model.dart';

class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key});

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final provider = Provider.of<BucketListProvider>(context);
    final _items = provider.items;

    final completedCount = _items.where((i) => i.isDone).length;
    final progress = _items.isEmpty ? 0.0 : completedCount / _items.length;

    return LifeAppScaffold(
      title: "BUCKET LIST",
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton(
          onPressed: () => _showEditor(context, null),
          backgroundColor: isDark ? Colors.white : Colors.black, // High Contrast
          elevation: 0,
          shape: const CircleBorder(),
          child: Icon(CupertinoIcons.add, color: isDark ? Colors.black : Colors.white, size: 28),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // PROGRESS HEADER (Wallet-style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("DREAMS ACHIEVED", style: TextStyle(color: secondaryTextColor, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("$completedCount / ${_items.length}", style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: -1)),
                  ],
                ),
                SizedBox(
                  width: 60, height: 60,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(value: progress, strokeWidth: 4, backgroundColor: theme.dividerColor, color: Colors.blueAccent),
                      Center(child: Text("${(progress * 100).toInt()}%", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // GRID CONTENT
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.star, size: 60, color: theme.dividerColor),
                        const SizedBox(height: 20),
                        Text("Dream big. Add a goal.", style: TextStyle(color: secondaryTextColor)),
                      ],
                    ),
                  )
                : MasonryGridView.count(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _buildBucketCard(context, _items[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBucketCard(BuildContext context, BucketItem item, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine card height based on content to create staggered effect
    final double height = item.description != null && item.description!.isNotEmpty ? 220 : 160;

    return GestureDetector(
      onTap: () => Provider.of<BucketListProvider>(context, listen: false).toggleDone(item.id),
      onLongPress: () => _showOptions(context, item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: height,
        decoration: BoxDecoration(
          color: item.isDone ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100) : item.color,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            if (!item.isDone)
              BoxShadow(color: item.color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text("#${index + 1}", style: TextStyle(color: item.isDone ? theme.textTheme.bodyMedium?.color : Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Icon(
                  item.isDone ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                  color: item.isDone ? Colors.green : Colors.black54,
                  size: 24,
                ),
              ],
            ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.w800,
                    color: item.isDone ? theme.textTheme.bodyLarge?.color?.withOpacity(0.5) : Colors.black87,
                    decoration: item.isDone ? TextDecoration.lineThrough : null,
                    height: 1.1,
                  ),
                ),
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: item.isDone ? theme.textTheme.bodyMedium?.color?.withOpacity(0.5) : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- POPUPS ---

  void _showEditor(BuildContext context, BucketItem? existing) {
    final titleCtrl = TextEditingController(text: existing?.title);
    final descCtrl = TextEditingController(text: existing?.description);
    Color selectedColor = existing?.color ?? const Color(0xFFB2DFDB);
    bool isDone = existing?.isDone ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40, top: 20, left: 25, right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(existing == null ? "NEW GOAL" : "EDIT GOAL", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    if (existing != null)
                      Row(
                        children: [
                          Text("Completed", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                          Switch(
                            value: isDone,
                            activeColor: Colors.green,
                            onChanged: (val) => setSheetState(() => isDone = val),
                          )
                        ],
                      )
                  ],
                ),
                const SizedBox(height: 25),

                CupertinoTextField(
                  controller: titleCtrl,
                  placeholder: "I want to...",
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 15),
                CupertinoTextField(
                  controller: descCtrl,
                  placeholder: "Details or notes (optional)",
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                  maxLines: 3,
                ),

                const SizedBox(height: 25),
                Text("COLOR LABEL", style: TextStyle(color: secondaryTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Color(0xFFF8BBD0), // Pink
                      const Color(0xFFB39DDB), // Purple
                      const Color(0xFFC5CAE9), // Indigo
                      const Color(0xFFB2DFDB), // Teal
                      const Color(0xFFFFCCBC), // Orange
                      const Color(0xFFFFF9C4), // Yellow
                      const Color(0xFFDCEDC8), // Light Green
                    ].map((c) => GestureDetector(
                      onTap: () => setSheetState(() => selectedColor = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 15),
                        width: 45, height: 45,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == c ? textColor : Colors.transparent, 
                            width: 3
                          ),
                          boxShadow: [if (selectedColor == c) BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
                        ),
                        child: selectedColor == c ? const Icon(Icons.check, color: Colors.black54) : null,
                      ),
                    )).toList(),
                  ),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: textColor,
                    borderRadius: BorderRadius.circular(15),
                    child: Text(existing == null ? "Add to List" : "Save Changes", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (titleCtrl.text.isNotEmpty) {
                        if (existing == null) {
                          Provider.of<BucketListProvider>(context, listen: false).addItem(titleCtrl.text, descCtrl.text, selectedColor);
                        } else {
                          Provider.of<BucketListProvider>(context, listen: false).updateItem(existing.id, titleCtrl.text, descCtrl.text, selectedColor, isDone);
                        }
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showOptions(BuildContext context, BucketItem item) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(CupertinoIcons.pencil, color: Colors.blueAccent),
              title: Text("Edit Goal", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(ctx); _showEditor(context, item); },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.check_mark_circled, color: Colors.green),
              title: Text(item.isDone ? "Mark as Incomplete" : "Mark as Complete", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(ctx); Provider.of<BucketListProvider>(context, listen: false).toggleDone(item.id); },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
              title: const Text("Delete Goal", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                Provider.of<BucketListProvider>(context, listen: false).deleteItem(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}