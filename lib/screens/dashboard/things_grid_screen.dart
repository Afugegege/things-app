import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../providers/notes_provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/roam_provider.dart';

import '../../models/note_model.dart';
import '../../models/task_model.dart';
import '../../models/event_model.dart';

import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart';
import '../notes/note_editor_screen.dart';
import '../apps/wallet_screen.dart';
import '../calendar/calendar_screen.dart';
import '../tools/flashcard_screen.dart';
import '../tools/bucket_list_screen.dart';

import '../../widgets/smart_widgets/widget_factory.dart';
import '../../widgets/smart_widgets/expense_widget.dart';
import '../../widgets/smart_widgets/roam_widget.dart';
import '../../widgets/smart_widgets/day_counter_widget.dart';
import '../../widgets/smart_widgets/flashcard_home_widget.dart';
import '../../widgets/smart_widgets/bucket_list_achieving_widget.dart';
import '../../widgets/event_ticker.dart'; 
import 'widget_studio_screen.dart';

class ThingsGridScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState> parentScaffoldKey;
  const ThingsGridScreen({super.key, required this.parentScaffoldKey});

  @override
  State<ThingsGridScreen> createState() => _ThingsGridScreenState();
}

class _ThingsGridScreenState extends State<ThingsGridScreen> {
  bool _isGrid = true;
  bool _isMultiSelect = false;
  final Set<String> _selectedIds = {}; 
  String _activeFilter = 'All';
  final TextEditingController _searchController = TextEditingController(); 
  bool _isSearching = false; 

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final notesProvider = Provider.of<NotesProvider>(context);
    final moneyProvider = Provider.of<MoneyProvider>(context);
    final tasksProvider = Provider.of<TasksProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final eventsProvider = Provider.of<EventsProvider>(context);
    final roamProvider = Provider.of<RoamProvider>(context);

    final String currentFolder = notesProvider.selectedFolder;
    final bool isFolderView = currentFolder != 'All';
    final List<dynamic> allItems = [];
    final visibility = userProvider.appVisibility;
    
    // --- DATA GATHERING ---
    List<String> folderWidgets = notesProvider.getWidgetsForFolder(currentFolder);

    // Helper to check if a widget is enabled (Global or Folder-specific)
    bool isWidgetEnabled(String key) {
      if (isFolderView) {
        return folderWidgets.contains(key);
      } else {
        return visibility[key] == true;
      }
    }

    if (isWidgetEnabled('Events') && (_activeFilter == 'All' || _activeFilter == 'Events')) {
         final activeEvents = eventsProvider.dashboardEvents;
         if (_activeFilter == 'Events') {
            allItems.addAll(activeEvents); 
         } else {
            if (activeEvents.isNotEmpty) allItems.addAll(activeEvents.take(5));
         }
    }
    
    if (isWidgetEnabled('Roam') && (_activeFilter == 'All' || _activeFilter == 'Roam')) {
         if (roamProvider.trips.isNotEmpty) allItems.add(roamProvider.trips.first);
    }
    
    if (isWidgetEnabled('Money') && (_activeFilter == 'All' || _activeFilter == 'Money')) {
        allItems.add('EXPENSE_WIDGET');
        allItems.addAll(moneyProvider.transactions.take(2));
    }
    
    if (isWidgetEnabled('Tasks') && (_activeFilter == 'All' || _activeFilter == 'Tasks')) {
        allItems.addAll(tasksProvider.tasks.where((t) => !t.isDone).take(4));
    }
    
    if (isWidgetEnabled('Flashcards') && (_activeFilter == 'All' || _activeFilter == 'Study')) {
         allItems.add('FLASHCARD_WIDGET');
    }
      
    if (isWidgetEnabled('Bucket') && _activeFilter == 'All') { 
       allItems.add('BUCKET_WIDGET');
    }

    // Notes Logic (Always show notes for the folder, or global filtered notes)
    // If in Folder View, we ALWAYS show notes for that folder.
    // If Global, we show notes based on visibility.
    if ((visibility['Brain'] == true || isFolderView) && (_activeFilter == 'All' || _activeFilter == 'Notes')) {
       final visibleNotes = notesProvider.notes.where((note) {
          if (isFolderView) {
             // Show if belongs to folder OR is explicitly "pinned" via widget toggles
             return note.folder == currentFolder || folderWidgets.contains(note.id);
          }
          return userProvider.isFolderVisible(note.folder);
       }).toList();
       allItems.addAll(visibleNotes);
    }
    
    return LifeAppScaffold(
      title: _isMultiSelect ? "${_selectedIds.length} SELECTED" : (isFolderView ? currentFolder.toUpperCase() : "DASHBOARD"),
      onOpenDrawer: () => widget.parentScaffoldKey.currentState?.openDrawer(),
      actions: [
        if (_isMultiSelect)
          IconButton(icon: const Icon(CupertinoIcons.clear_circled), onPressed: _exitMultiSelect)
        else ...[
          // VISIBILITY FILTER / CUSTOMIZER
          IconButton(
            icon: Icon(isFolderView ? CupertinoIcons.slider_horizontal_3 : CupertinoIcons.slider_horizontal_3, color: textColor), // Same icon, different purpose logic
            onPressed: () {
               if (isFolderView) {
                 _showFolderCustomizer(context, currentFolder);
               } else {
                 _showVisibilityFilter(context);
               }
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? CupertinoIcons.clear : CupertinoIcons.search, color: textColor),
            onPressed: () {
               setState(() {
                 _isSearching = !_isSearching;
                 if (!_isSearching) _searchController.clear();
               });
            },
          ),
          IconButton(
            icon: Icon(_isGrid ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2, color: textColor),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ]
      ],
      floatingActionButton: _isMultiSelect ? null : Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton(
          onPressed: () => _showQuickAddMenu(context),
          backgroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
          shape: const CircleBorder(),
          child: Icon(CupertinoIcons.add, color: isDark ? Colors.black : Colors.white, size: 28),
        ),
      ),
      bottomSheet: _isMultiSelect ? (() {
        // [LOGIC] Check if merge is possible (at least 2 notes selected)
        final selectedNotesCount = _selectedIds.where((id) => notesProvider.notes.any((n) => n.id == id)).length;
        final canMerge = selectedNotesCount >= 2;

        return GlassContainer(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          height: 70,
          borderRadius: 35, 
          opacity: isDark ? 0.2 : 0.05,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // MERGE BUTTON
              if (canMerge)
                IconButton(
                  tooltip: "Merge Notes",
                  icon: const Icon(Icons.merge, color: Colors.blueAccent), 
                  onPressed: () {
                     notesProvider.mergeNotes(_selectedIds.toList());
                     _exitMultiSelect();
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notes Merged!")));
                  }
                ),

              // PIN BUTTON (Optional, but useful)
              IconButton(
                icon: const Icon(CupertinoIcons.pin, color: Colors.orangeAccent),
                onPressed: () {
                   for (var id in _selectedIds) notesProvider.togglePin(id);
                   _exitMultiSelect();
                }
              ),

              // MOVE BUTTON
              IconButton(
                tooltip: "Move to Folder",
                icon: const Icon(CupertinoIcons.folder_badge_plus, color: Colors.purpleAccent),
                onPressed: () {
                   _showFolderSelectionDialog(context);
                }
              ),

              // DELETE BUTTON
              IconButton(
                icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent), 
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: const Text("Delete items?"),
                      content: const Text("This action cannot be undone."),
                      actions: [
                        CupertinoDialogAction(child: const Text("Cancel"), onPressed: () => Navigator.pop(ctx)),
                        CupertinoDialogAction(
                          isDestructiveAction: true, 
                          child: const Text("Delete"), 
                          onPressed: () {
                            for (var id in _selectedIds) {
                               notesProvider.deleteNotes(id);
                               tasksProvider.deleteTask(id);
                               eventsProvider.removeEvent(id);
                               moneyProvider.removeTransactionById(id);
                            }
                            Navigator.pop(ctx);
                            _exitMultiSelect();
                          }
                        ),
                      ]
                    )
                  );
                }
              ),
              
              // CLOSE BUTTON
              Container(width: 1, height: 30, color: theme.dividerColor),
              IconButton(icon: Icon(CupertinoIcons.xmark, color: secondaryTextColor), onPressed: _exitMultiSelect),
            ],
          ),
        );
      }()) : null,
      child: Column(
        children: [
          const SizedBox(height: 10),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: GlassContainer(
                height: 50,
                borderRadius: 15,
                opacity: isDark ? 0.2 : 0.05,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Search...", 
                    border: InputBorder.none, 
                    prefixIcon: Icon(CupertinoIcons.search, color: secondaryTextColor, size: 20),
                    hintStyle: TextStyle(color: secondaryTextColor),
                    contentPadding: const EdgeInsets.only(top: 12)
                  ),
                  onChanged: (v) => setState(() {}),
                ),
              ),
            ),
          if (!_isMultiSelect && !_isSearching) 
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _filterChip("All"),
                  _filterChip("Notes"),
                  _filterChip("Tasks"),
                  _filterChip("Money"),
                  _filterChip("Events"),
                  _filterChip("Roam"), 
                  _filterChip("Study"),
                ],
              ),
            ),

          Expanded(
            child: allItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.square_grid_2x2, size: 48, color: secondaryTextColor.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text("Your dashboard is empty.", style: TextStyle(color: secondaryTextColor, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text("Add items or enable apps in Settings.", style: TextStyle(color: secondaryTextColor.withOpacity(0.7), fontSize: 13)),
                      ]
                    )
                  )
                : _isGrid 
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(15, 20, 15, 120),
                        child: StaggeredGrid.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: allItems.map((item) {
                          // Force every widget to span only 1 column
                            return StaggeredGridTile.fit(
                              crossAxisCellCount: 1, 
                              child: _buildSelectableItem(context, item),
                            );
                        }).toList(),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(15, 20, 15, 120),
                        itemCount: allItems.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildSelectableItem(context, allItems[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // --- ITEM RENDERING ---
  Widget _buildSelectableItem(BuildContext context, dynamic item) {
    String? id;
    if (item is Note) id = item.id;
    else if (item is Task) id = item.id;
    else if (item is Event) id = item.id;
    else if (item is Map && item.containsKey('id')) id = item['id'];

    final bool isSelected = id != null && _selectedIds.contains(id);
    
    return GestureDetector(
      onTap: () {
        if (_isMultiSelect && id != null) {
          _toggleSelection(id);
        } else {
          // SAFE NAVIGATION
          if (item is Note) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: item)));
          } else if (item is Event) {
            _showEventEditor(context, item); 
          } else if (item is Map && item.containsKey('amount')) {
            _showTransactionEditor(context, Map<String, dynamic>.from(item)); 
          } else if (item == 'EXPENSE_WIDGET') {
            Provider.of<UserProvider>(context, listen: false).changeView('wallet');
          } else if (item == 'FLASHCARD_WIDGET') {
            Provider.of<UserProvider>(context, listen: false).changeView('flashcards');
          } else if (item == 'BUCKET_WIDGET') {
            Provider.of<UserProvider>(context, listen: false).changeView('bucket');
          }
        }
      },
      onLongPress: () {
        if (id != null) {
          setState(() { 
            _isMultiSelect = true; 
            _selectedIds.add(id!); // FIX: Added ! to fix compilation error 
          });
        }
      },
      child: AnimatedScale(
        scale: isSelected ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: true, 
              child: _buildGridItem(context, item),
            ),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Provider.of<UserProvider>(context).accentColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Provider.of<UserProvider>(context).accentColor, width: 3),
                  ),
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.all(10),
                  child: const Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, dynamic item) {
    if (item == 'EXPENSE_WIDGET') return const ExpenseSummaryWidget();
    if (item is Note) return WidgetFactory.build(context, item);
    if (item is Task) return _buildTaskCard(item);
    if (item is Event) return item.isDayCounter ? DayCounterWidget(event: item) : EventTicker(event: item);
    if (item is Map) {
      if (item.containsKey('distance_km')) return RoamWidget(trip: Map<String, dynamic>.from(item));
      return _buildMoneyCard(Map<String, dynamic>.from(item));
    }
    if (item == 'FLASHCARD_WIDGET') return const FlashcardHomeWidget();
    if (item == 'BUCKET_WIDGET') return const BucketListAchievingWidget();
    return const SizedBox();
  }
  
  Widget _buildTaskCard(Task task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Provider.of<UserProvider>(context).accentColor))),
              if (task.priority > 1) const Icon(CupertinoIcons.exclamationmark_circle, size: 14, color: Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title, 
            style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold), 
            maxLines: 2, 
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyCard(Map<String, dynamic> tx) {
    final bool isExp = (tx['amount'] as double) < 0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12)
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        crossAxisAlignment: CrossAxisAlignment.start, 
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isExp ? CupertinoIcons.arrow_down_right : CupertinoIcons.arrow_up_right, color: isExp ? Colors.redAccent : Colors.greenAccent, size: 18),
          const SizedBox(height: 5),
          Text(
            tx['title'], 
            style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "\$${(tx['amount'] as double).abs().toStringAsFixed(2)}", 
            style: TextStyle(color: isExp ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isMultiSelect = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() { _isMultiSelect = false; _selectedIds.clear(); });
  }

  Widget _filterChip(String label) {
    final bool isSelected = _activeFilter == label;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? textColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : theme.dividerColor),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? theme.scaffoldBackgroundColor : textColor.withOpacity(0.7), 
            fontWeight: FontWeight.bold, 
            fontSize: 12
          )
        ),
      ),
    );
  }

  // --- POPUPS ---

  void _showEventEditor(BuildContext context, Event existingEvent) {
    final titleCtrl = TextEditingController(text: existingEvent.title);
    final locCtrl = TextEditingController(text: existingEvent.location);
    DateTime selectedDate = existingEvent.date;
    TimeOfDay startTime = TimeOfDay.fromDateTime(existingEvent.date);
    TimeOfDay endTime = TimeOfDay.fromDateTime(existingEvent.endTime);
    bool isAllDay = existingEvent.isAllDay;
    bool isDayCounter = existingEvent.isDayCounter;
    Color selectedColor = existingEvent.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

          Future<void> pickTime(bool isStart) async {
            final picked = await showTimePicker(context: context, initialTime: isStart ? startTime : endTime, builder: (context, child) => Theme(data: theme, child: child!));
            if (picked != null) setSheetState(() { if (isStart) startTime = picked; else endTime = picked; });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40, top: 20, left: 25, right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                   Text("Edit Event", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                   IconButton(icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent), onPressed: () {
                       Provider.of<EventsProvider>(context, listen: false).removeEvent(existingEvent.id);
                       Navigator.pop(ctx);
                   })
                ]),
                const SizedBox(height: 25),
                CupertinoTextField(controller: titleCtrl, placeholder: "Title", placeholderStyle: TextStyle(color: secondaryTextColor), style: TextStyle(color: textColor), decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16)),
                const SizedBox(height: 15),
                CupertinoTextField(controller: locCtrl, placeholder: "Location", placeholderStyle: TextStyle(color: secondaryTextColor), style: TextStyle(color: textColor), prefix: Padding(padding: const EdgeInsets.only(left: 16), child: Icon(Icons.location_on_outlined, color: secondaryTextColor, size: 18)), decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16)),
                const SizedBox(height: 15),
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("All-day", style: TextStyle(color: textColor, fontSize: 16)),
                    Switch(value: isAllDay, activeColor: textColor, onChanged: (val) => setSheetState(() => isAllDay = val)),
                ])),
                if (!isAllDay) ...[
                  const SizedBox(height: 15),
                  Row(children: [
                    Expanded(child: _buildTimeInput(context, "Start", startTime.format(context), () => pickTime(true))),
                    const SizedBox(width: 15),
                    Expanded(child: _buildTimeInput(context, "End", endTime.format(context), () => pickTime(false))),
                  ]),
                ],
                const SizedBox(height: 15),
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)), child: Row(children: [
                    Icon(CupertinoIcons.sparkles, color: isDayCounter ? Colors.amber : secondaryTextColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Special Day Counter", style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)), Text("Show on dashboard", style: TextStyle(color: secondaryTextColor, fontSize: 11))])),
                    Switch(value: isDayCounter, activeColor: Colors.amber, onChanged: (val) => setSheetState(() => isDayCounter = val)),
                ])),
                const SizedBox(height: 30),
                SizedBox(width: double.infinity, child: CupertinoButton(color: textColor, borderRadius: BorderRadius.circular(15), child: Text("Update Event", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)), onPressed: () {
                      DateTime startDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                      DateTime endDt = startDt;
                      if (!isAllDay) {
                         startDt = startDt.add(Duration(hours: startTime.hour, minutes: startTime.minute));
                         endDt = endDt.add(Duration(hours: endTime.hour, minutes: endTime.minute));
                         if (endDt.isBefore(startDt)) endDt = endDt.add(const Duration(days: 1));
                      }
                      Provider.of<EventsProvider>(context, listen: false).editEvent(Event(id: existingEvent.id, title: titleCtrl.text, location: locCtrl.text, date: startDt, endTime: endDt, isAllDay: isAllDay, isDayCounter: isDayCounter, color: selectedColor));
                      Navigator.pop(ctx);
                }))
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTransactionEditor(BuildContext context, Map<String, dynamic> tx) {
    final titleCtrl = TextEditingController(text: tx['title']);
    final amountCtrl = TextEditingController(text: (tx['amount'] as double).abs().toString());
    String selectedCat = tx['category'] ?? 'General';
    bool isExpense = (tx['amount'] as double) < 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final moneyProvider = Provider.of<MoneyProvider>(context);
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40, top: 25, left: 25, right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                     Text("Edit Transaction", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                     IconButton(icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent), onPressed: () {
                        if (tx['id'] != null) Provider.of<MoneyProvider>(context, listen: false).removeTransactionById(tx['id']);
                        Navigator.pop(ctx);
                     })
                ]),
                const SizedBox(height: 20),
                Container(decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)), child: Row(children: [
                      Expanded(child: GestureDetector(onTap: () => setSheetState(() => isExpense = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isExpense ? textColor : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Text("Expense", textAlign: TextAlign.center, style: TextStyle(color: isExpense ? theme.scaffoldBackgroundColor : secondaryTextColor, fontWeight: FontWeight.bold))))),
                      Expanded(child: GestureDetector(onTap: () => setSheetState(() => isExpense = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: !isExpense ? textColor : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Text("Income", textAlign: TextAlign.center, style: TextStyle(color: !isExpense ? theme.scaffoldBackgroundColor : secondaryTextColor, fontWeight: FontWeight.bold))))),
                ])),
                const SizedBox(height: 25),
                CupertinoTextField(controller: titleCtrl, placeholder: "Title", placeholderStyle: TextStyle(color: secondaryTextColor), style: TextStyle(color: textColor), decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16)),
                const SizedBox(height: 15),
                CupertinoTextField(controller: amountCtrl, placeholder: "0.00", keyboardType: const TextInputType.numberWithOptions(decimal: true), placeholderStyle: TextStyle(color: secondaryTextColor), style: TextStyle(color: textColor), prefix: Padding(padding: const EdgeInsets.only(left: 16), child: Icon(CupertinoIcons.money_dollar, color: secondaryTextColor, size: 18)), decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16)),
                const SizedBox(height: 25),
                if (isExpense) SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
                   ...moneyProvider.categories.map((cat) {
                      final isSelected = selectedCat == cat;
                      return GestureDetector(onTap: () => setSheetState(() => selectedCat = cat), child: Container(margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: isSelected ? textColor : inputBg, borderRadius: BorderRadius.circular(20)), child: Text(cat, style: TextStyle(color: isSelected ? theme.scaffoldBackgroundColor : secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold))));
                   }),
                ])),
                const SizedBox(height: 30),
                SizedBox(width: double.infinity, child: CupertinoButton(color: textColor, borderRadius: BorderRadius.circular(15), child: Text("Update", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)), onPressed: () {
                   double val = double.tryParse(amountCtrl.text) ?? 0.0;
                   if (isExpense) val = -val.abs(); else val = val.abs();
                   if (tx['id'] != null) Provider.of<MoneyProvider>(context, listen: false).editTransaction(tx['id'], titleCtrl.text, val, isExpense ? selectedCat : 'Income');
                   Navigator.pop(ctx);
                }))
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTaskCreator(BuildContext context) {
    final titleCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("NEW TASK", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: titleCtrl,
                    placeholder: "What needs to be done?",
                    placeholderStyle: const TextStyle(color: Colors.grey),
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: BoxDecoration(color: Colors.transparent),
                    autofocus: true,
                    onSubmitted: (val) {
                       if (val.trim().isNotEmpty) {
                         Provider.of<TasksProvider>(context, listen: false).addTask(Task(id: const Uuid().v4(), title: val, isDone: false, createdAt: DateTime.now()));
                         Navigator.pop(ctx);
                       }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.arrow_up_circle_fill, color: Colors.blueAccent, size: 30),
                  onPressed: () {
                     if (titleCtrl.text.trim().isNotEmpty) {
                         Provider.of<TasksProvider>(context, listen: false).addTask(Task(id: const Uuid().v4(), title: titleCtrl.text, isDone: false, createdAt: DateTime.now()));
                         Navigator.pop(ctx);
                     }
                  },
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInput(BuildContext context, String label, String value, VoidCallback onTap) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  void _showMoveInDialog(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final String currentFolder = notesProvider.selectedFolder;
    // Get widgets NOT in current folder
    final availableWidgets = notesProvider.notes.where((n) => n.widgetType != null && n.folder != currentFolder).toList();
    final Set<String> selectedForMove = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

          return Container(
             height: 500,
             padding: const EdgeInsets.all(20),
             child: Column(
               children: [
                 Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                 const SizedBox(height: 20),
                 Text("MOVE WIDGETS HERE", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                 const SizedBox(height: 10),
                 Text("Select widgets to move to '$currentFolder'", style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12)),
                 const SizedBox(height: 20),
                 Expanded(
                   child: availableWidgets.isEmpty 
                     ? Center(child: Text("No other widgets found.", style: TextStyle(color: theme.disabledColor)))
                     : ListView.builder(
                         itemCount: availableWidgets.length,
                         itemBuilder: (ctx, i) {
                           final w = availableWidgets[i];
                           final isSelected = selectedForMove.contains(w.id);
                           return GestureDetector(
                             onTap: () => setSheetState(() {
                               if (isSelected) selectedForMove.remove(w.id);
                               else selectedForMove.add(w.id);
                             }),
                             child: Container(
                               margin: const EdgeInsets.only(bottom: 10),
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                 color: isSelected ? Provider.of<UserProvider>(context).accentColor.withOpacity(0.1) : theme.dividerColor.withOpacity(0.05),
                                 borderRadius: BorderRadius.circular(15),
                                 border: Border.all(color: isSelected ? Provider.of<UserProvider>(context).accentColor : Colors.transparent),
                               ),
                               child: Row(
                                 children: [
                                   Icon(CupertinoIcons.cube_box, color: Color(w.backgroundColor ?? Colors.grey.value)),
                                   const SizedBox(width: 15),
                                   Expanded(child: Text(w.title.isNotEmpty ? w.title : "Widget", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                                   if (isSelected) Icon(CupertinoIcons.check_mark_circled_solid, color: Provider.of<UserProvider>(context).accentColor)
                                 ],
                               ),
                             ),
                           );
                         }
                       ),
                 ),
                 const SizedBox(height: 20),
                 SizedBox(
                   width: double.infinity,
                   child: CupertinoButton(
                     color: Provider.of<UserProvider>(context).accentColor,
                     borderRadius: BorderRadius.circular(15),
                     onPressed: selectedForMove.isEmpty ? null : () {
                       notesProvider.batchMoveNotes(selectedForMove.toList(), currentFolder);
                       Navigator.pop(ctx);
                       Navigator.pop(context); // Close Quick Add too
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved ${selectedForMove.length} widgets to $currentFolder")));
                     },
                     child: const Text("Move Selected", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   ),
                 )
               ],
             ),
          );
        },
      ),
    );
  }

  void _createWidgetNote(BuildContext context, String title, String type, Color color) {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final String currentFolder = provider.selectedFolder;
    final newWidget = Note(
      id: const Uuid().v4(),
      title: title,
      content: "",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: currentFolder,
      widgetType: type,
      backgroundColor: color.value,
    );
    provider.addNote(newWidget);
    Navigator.pop(context); // Close Quick Add
  }

  void _showQuickAddMenu(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final String currentFolder = notesProvider.selectedFolder;
    final bool isFolderView = currentFolder != 'All';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow taller
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Re-fetch enabled widgets to update UI
          final enabledWidgets = notesProvider.getWidgetsForFolder(currentFolder);
          
          // Fetch user's existing "widget notes" (notes that act as widgets)
          final myWidgets = notesProvider.notes.where((n) => n.widgetType != null && n.folder != currentFolder).toList();

          Widget _buildDashboardToggle(String label, IconData icon, Color color, String key) {
             final bool isEnabled = enabledWidgets.contains(key);
             return GestureDetector(
               onTap: () {
                 notesProvider.toggleFolderWidget(currentFolder, key);
                 setSheetState(() {}); // Refresh local check
               },
               child: Container(
                 width: 70,
                 margin: const EdgeInsets.only(right: 12),
                 decoration: BoxDecoration(
                   color: isEnabled ? color.withOpacity(0.2) : theme.dividerColor.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(15),
                   border: Border.all(color: isEnabled ? color : Colors.transparent, width: 2),
                 ),
                 padding: const EdgeInsets.symmetric(vertical: 10),
                 child: Column(
                   children: [
                     Icon(icon, color: isEnabled ? color : theme.disabledColor, size: 22),
                     const SizedBox(height: 5),
                     Text(label, style: TextStyle(color: isEnabled ? textColor : theme.disabledColor, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                   ],
                 ),
               ),
             );
          }

          return Container(
            padding: const EdgeInsets.all(25),
            height: isFolderView ? 700 : 550, 
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 25),
                Text("QUICK ADD", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 25),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3, mainAxisSpacing: 25, crossAxisSpacing: 25,
                    childAspectRatio: 1.1, 
                    children: [
                      _quickAddOption(CupertinoIcons.doc_text, "Note", Provider.of<UserProvider>(context).accentColor, () { 
                        Navigator.pop(ctx); 
                        Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(initialFolder: isFolderView ? currentFolder : null))); 
                      }),
                      _quickAddOption(CupertinoIcons.check_mark_circled, "Task", Colors.greenAccent, () { 
                        Navigator.pop(ctx); 
                        _showTaskCreator(context); 
                      }),
                      _quickAddOption(CupertinoIcons.calendar, "Event", Colors.orangeAccent, () { 
                        Navigator.pop(ctx); 
                        _showEventEditor(context, Event(id: const Uuid().v4(), title: "", date: DateTime.now(), endTime: DateTime.now().add(const Duration(hours: 1)), location: "", isAllDay: false, isDayCounter: false, color: Colors.blue)); 
                      }),
                      _quickAddOption(CupertinoIcons.sparkles, "Day Counter", Colors.pinkAccent, () { 
                        Navigator.pop(ctx); 
                        _showEventEditor(context, Event(id: const Uuid().v4(), title: "", date: DateTime.now(), endTime: DateTime.now(), location: "", isAllDay: true, isDayCounter: true, color: Colors.amber)); 
                      }),
                      _quickAddOption(CupertinoIcons.money_dollar, "Expense", Colors.redAccent, () { 
                        Navigator.pop(ctx); 
                        _showTransactionEditor(context, {'title': '', 'amount': 0.0}); 
                      }),
                      _quickAddOption(CupertinoIcons.book, "Study", Colors.purpleAccent, () { 
                        Navigator.pop(ctx); 
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashCardScreen())); 
                      }),
                      // SPECIFIC WIDGETS
                       _quickAddOption(CupertinoIcons.smiley, "Sticker", Colors.yellow, () => _createWidgetNote(context, "Sticker", 'sticker', Colors.yellow)),
                       _quickAddOption(CupertinoIcons.quote_bubble, "Quote", Colors.cyanAccent, () => _createWidgetNote(context, "Quote", 'quote', Colors.cyanAccent)),
                       _quickAddOption(CupertinoIcons.timer, "Timer", Colors.deepOrangeAccent, () => _createWidgetNote(context, "Timer", 'timer', Colors.deepOrangeAccent)),
                       _quickAddOption(CupertinoIcons.graph_circle, "Monitor", Colors.tealAccent, () => _createWidgetNote(context, "Monitor", 'monitor', Colors.tealAccent)),
                       // MOVE IN BUTTON
                       if (isFolderView)
                        _quickAddOption(CupertinoIcons.tray_arrow_down, "Move In", Colors.blueGrey, () => _showMoveInDialog(context)),
                    ],
                  ),
                ),
                if (isFolderView) ...[
                   const Divider(),
                   const SizedBox(height: 10),
                   
                   // EXISTING WIDGETS (My Widgets)
                   if (myWidgets.isNotEmpty) ...[
                      Align(alignment: Alignment.centerLeft, child: Text("MY WIDGETS", style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 10, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 70,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: myWidgets.map((note) => _buildDashboardToggle(
                            note.title.isNotEmpty ? note.title : "Widget", 
                            CupertinoIcons.plus_square_fill_on_square_fill, 
                            Color(note.backgroundColor ?? Colors.blueAccent.value), 
                            note.id
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 15),
                   ],

                   // APP WIDGETS
                   Align(alignment: Alignment.centerLeft, child: Text("APPS", style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 10, fontWeight: FontWeight.bold))),
                   const SizedBox(height: 10),
                   SizedBox(
                     height: 70,
                     child: ListView(
                       scrollDirection: Axis.horizontal,
                       children: [
                          _buildDashboardToggle("Tasks", CupertinoIcons.check_mark_circled, Colors.greenAccent, 'Tasks'),
                          _buildDashboardToggle("Money", CupertinoIcons.money_dollar, Colors.redAccent, 'Money'),
                          _buildDashboardToggle("Events", CupertinoIcons.calendar, Colors.orangeAccent, 'Events'),
                          _buildDashboardToggle("Roam", CupertinoIcons.airplane, Colors.blueAccent, 'Roam'),
                          _buildDashboardToggle("Bucket", CupertinoIcons.star, Colors.amber, 'Bucket'),
                          _buildDashboardToggle("Flashcards", CupertinoIcons.bolt_horizontal, Colors.purpleAccent, 'Flashcards'),
                       ],
                     ),
                   )
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _quickAddOption(IconData icon, String label, Color color, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 60, height: 60, 
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), 
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? Colors.transparent : color.withOpacity(0.2))
            ), 
            child: Icon(icon, color: color, size: 28)
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _showFolderSelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final notesProvider = Provider.of<NotesProvider>(context, listen: false);
        final folders = notesProvider.folders;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          height: 300,
          child: Column(
            children: [
              Text("Move to Folder", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    if (folder == 'All') return const SizedBox.shrink(); // Skip 'All'
                    return ListTile(
                      leading: const Icon(CupertinoIcons.folder),
                      title: Text(folder),
                      onTap: () {
                        notesProvider.batchMoveNotes(_selectedIds.toList(), folder);
                        Navigator.pop(ctx);
                        _exitMultiSelect();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved to $folder")));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFolderCustomizer(BuildContext context, String folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
         return StatefulBuilder(
           builder: (context, setState) {
             final provider = Provider.of<NotesProvider>(context);
             final enabled = provider.getWidgetsForFolder(folder);
             final theme = Theme.of(context);
             final textColor = theme.textTheme.bodyLarge?.color;

             return Container(
               padding: const EdgeInsets.all(20),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                   const SizedBox(height: 20),
                   Text("CUSTOMIZE '$folder'", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                   const SizedBox(height: 10),
                   Text("Select widgets to display in this folder.", style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12)),
                   const SizedBox(height: 20),
                   Expanded(
                     child: ListView(
                       children: [
                         _folderWidgetOption("Tasks", CupertinoIcons.check_mark_circled, Colors.greenAccent, enabled.contains('Tasks'), () => provider.toggleFolderWidget(folder, 'Tasks')),
                         _folderWidgetOption("Events", CupertinoIcons.calendar, Colors.orangeAccent, enabled.contains('Events'), () => provider.toggleFolderWidget(folder, 'Events')),
                         _folderWidgetOption("Money", CupertinoIcons.money_dollar, Colors.redAccent, enabled.contains('Money'), () => provider.toggleFolderWidget(folder, 'Money')),
                         _folderWidgetOption("Flashcards", CupertinoIcons.bolt_horizontal, Colors.purpleAccent, enabled.contains('Flashcards'), () => provider.toggleFolderWidget(folder, 'Flashcards')),
                         _folderWidgetOption("Roam", CupertinoIcons.airplane, Colors.blueAccent, enabled.contains('Roam'), () => provider.toggleFolderWidget(folder, 'Roam')),
                         _folderWidgetOption("Bucket List", CupertinoIcons.star, Colors.amber, enabled.contains('Bucket'), () => provider.toggleFolderWidget(folder, 'Bucket')),
                       ],
                     ),
                   )
                 ],
               ),
             );
           }
         );
      }
    );
  }

  Widget _folderWidgetOption(String label, IconData icon, Color color, bool isEnabled, VoidCallback onTap) {
     return ListTile(
       leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
       title: Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
       trailing: Switch(
         value: isEnabled, 
         activeColor: color,
         onChanged: (_) => onTap(),
       ),
       onTap: onTap,
     );
  }

  void _showVisibilityFilter(BuildContext context) {
    // ... existing ...
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final userProvider = Provider.of<UserProvider>(context);
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        
        final labels = {
          'Brain': 'Notes (Brain)',
          'Focus': 'Tasks (Focus)',
          'Wallet': 'Wallet & Money',
          'Events': 'Calendar Events',
          'Roam': 'Travel (Roam)',
          'Flashcards': 'Study (Flashcards)',
          'Bucket': 'Bucket List',
        };

        return Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
               const SizedBox(height: 25),
               Text("DASHBOARD WIDGETS", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
               const SizedBox(height: 20),
               ...userProvider.appVisibility.keys.map((key) {
                 if (!labels.containsKey(key)) return const SizedBox();
                 final isVisible = userProvider.appVisibility[key] ?? true;
                 return SwitchListTile(
                   title: Text(labels[key]!, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                   value: isVisible, 
                   activeColor: userProvider.accentColor,
                   onChanged: (val) => userProvider.toggleAppVisibility(key),
                 );
               }),
            ],
          ),
        );
      }
    );
  }
}