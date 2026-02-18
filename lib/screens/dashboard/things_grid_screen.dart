import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import '../../providers/notes_provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/events_provider.dart';

import '../../models/note_model.dart';
import '../../models/task_model.dart';
import '../../models/event_model.dart';

import '../../services/storage_service.dart';

import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart';
import '../notes/note_editor_screen.dart';
import '../apps/wallet_screen.dart';
import '../calendar/calendar_screen.dart';

import '../../widgets/smart_widgets/widget_factory.dart';
import '../../widgets/smart_widgets/expense_widget.dart';
import '../../widgets/smart_widgets/day_counter_widget.dart';
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
  Set<String> _activeFilters = {'All'}; // Changed to Set
  final TextEditingController _searchController = TextEditingController(); 
  bool _isSearching = false; 
  final Set<String> _recentlyCompletedIds = {}; 

  @override
  void initState() {
    super.initState();
    // Load persisted filters
    final saved = StorageService.loadDashboardFilters();
    if (saved.isNotEmpty) {
      _activeFilters = saved.toSet();
    }
  } 

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
        String lookup = key;
        if (key == 'Money') lookup = 'Wallet';
        if (key == 'Tasks') lookup = 'Focus';
        // Events is 'Events'
        return visibility[lookup] == true;
      }
    }

    // --- UNIVERSAL DATA GATHERING ---
    List<dynamic> pinnedItems = [];
    List<dynamic> unpinnedItems = [];

    // Helper map to store items by type for later sorting
    final Map<String, List<dynamic>> unpinnedByType = {
       'Notes': [],
       'Events': [],
       'Money': [],
       'Tasks': []
    };

    // 1. NOTES
    if (visibility['Brain'] == true || isFolderView) {
       final visibleNotes = notesProvider.notes.where((note) {
          if (isFolderView) {
             return note.folder == currentFolder || folderWidgets.contains(note.id);
          }
          return (_activeFilters.contains('All') || _activeFilters.contains('Notes')) && userProvider.isFolderVisible(note.folder);
       }).toList();
       
       pinnedItems.addAll(visibleNotes.where((n) => n.isPinned));
       unpinnedByType['Notes']!.addAll(visibleNotes.where((n) => !n.isPinned));
    }

    // 2. EVENTS
    if (isWidgetEnabled('Events') && (_activeFilters.contains('All') || _activeFilters.contains('Events'))) {
         final events = eventsProvider.dashboardEvents;
         // Separate pinned/unpinned events
         pinnedItems.addAll(events.where((e) => e.isPinned));
         unpinnedByType['Events']!.addAll(events.where((e) => !e.isPinned));
         
         if (!_activeFilters.contains('Events') && unpinnedByType['Events']!.whereType<Event>().length > 5) {
             // Basic capping logic if not focused on events
             // (Simplified for now as per previous block)
         }
    }

    // 3. MONEY
    if (isWidgetEnabled('Money') && (_activeFilters.contains('All') || _activeFilters.contains('Money'))) {
        unpinnedByType['Money']!.add('EXPENSE_WIDGET'); 
        
        final txns = moneyProvider.transactions;
        pinnedItems.addAll(txns.where((t) => t['isPinned'] == true));
        unpinnedByType['Money']!.addAll(txns.where((t) => t['isPinned'] != true).take(2));
    }
    
    // 4. TASKS
    if (isWidgetEnabled('Tasks') && (_activeFilters.contains('All') || _activeFilters.contains('Tasks'))) {
        final tasks = tasksProvider.tasks.where((t) => !t.isDone || _recentlyCompletedIds.contains(t.id));
        unpinnedByType['Tasks']!.addAll(tasks.take(4));
    }

    // COMBINE UNPINNED IN ORDER
    if (_activeFilters.contains('All') || _activeFilters.isEmpty) {
       // DEFAULT ORDER for "All"
       unpinnedItems.addAll(unpinnedByType['Notes']!);
       unpinnedItems.addAll(unpinnedByType['Events']!);
       unpinnedItems.addAll(unpinnedByType['Money']!);
       unpinnedItems.addAll(unpinnedByType['Tasks']!);
    } else {
       // RESPECT FILTER ORDER
       for (var filter in _activeFilters) {
          if (unpinnedByType.containsKey(filter)) {
             unpinnedItems.addAll(unpinnedByType[filter]!);
          }
       }
    }

    // COMBINE
    allItems.addAll(pinnedItems);
    allItems.addAll(unpinnedItems);
    
    return LifeAppScaffold(
      title: _isMultiSelect ? "${_selectedIds.length} SELECTED" : (isFolderView ? currentFolder.toUpperCase() : "DASHBOARD"),
      onOpenDrawer: () => widget.parentScaffoldKey.currentState?.openDrawer(),
      actions: [
        if (_isMultiSelect)
          IconButton(icon: const Icon(CupertinoIcons.clear_circled, color: Colors.redAccent), onPressed: _exitMultiSelect)
        else ...[
          // VISIBILITY FILTER / CUSTOMIZER

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
                  icon: Icon(Icons.merge, color: textColor), 
                  onPressed: () {
                     notesProvider.mergeNotes(_selectedIds.toList());
                     _exitMultiSelect();
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notes Merged!")));
                  }
                ),

              // PIN BUTTON (Optional, but useful)
              IconButton(
                icon: Icon(CupertinoIcons.pin, color: textColor),
                onPressed: () {
                   for (var id in _selectedIds) _togglePin(context, id);
                   _exitMultiSelect();
                }
              ),

              // MOVE BUTTON
              IconButton(
                tooltip: "Move to Folder",
                icon: Icon(CupertinoIcons.folder_badge_plus, color: textColor),
                onPressed: () {
                   _showFolderSelectionDialog(context);
                }
              ),

              // DELETE BUTTON
               IconButton(
                icon: Icon(CupertinoIcons.trash, color: textColor), 
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: theme.cardColor,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) {
                      final isDark = theme.brightness == Brightness.dark;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(height: 25),
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 24),
                            ),
                            const SizedBox(height: 15),
                            Text("Delete ${_selectedIds.length} item${_selectedIds.length > 1 ? 's' : ''}?", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text("This action cannot be undone.", style: TextStyle(color: secondaryTextColor, fontSize: 14)),
                            const SizedBox(height: 25),
                            Row(
                              children: [
                                Expanded(
                                  child: CupertinoButton(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Text("Cancel", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CupertinoButton(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(14),
                                    child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      for (var id in _selectedIds) {
                                        notesProvider.deleteNotes(id);
                                        tasksProvider.deleteTask(id);
                                        eventsProvider.removeEvent(id);
                                        moneyProvider.removeTransactionById(id);
                                      }
                                      Navigator.pop(ctx);
                                      _exitMultiSelect();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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
      child: Stack(
        children: [
          // 1. CONTENT LAYER
          Positioned.fill(
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
                        padding: const EdgeInsets.fromLTRB(15, 80, 15, 240),
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
                        padding: const EdgeInsets.fromLTRB(15, 80, 15, 240),
                        itemCount: allItems.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildSelectableItem(context, allItems[index]),
                        ),
                      ),
          ),

          // 2. HEADER LAYER (Blur + Gradient)
          if (!_isMultiSelect)
            Positioned(
              top: 0, left: 0, right: 0,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.black, Colors.transparent],
                    stops: [0.0, 0.7, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(bottom: 40, top: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.scaffoldBackgroundColor,
                            theme.scaffoldBackgroundColor.withOpacity(0.0), 
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          if (!_isSearching) 
                            SizedBox(
                              height: 40,
                              child: Center(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: () {
                                      // Default order
                                      List<String> allFilters = ["All", "Notes", "Tasks", "Money", "Events"];
                                      
                                      if (_activeFilters.contains('All')) {
                                        // Standard order if "All" is selected
                                        return allFilters.map((f) => _filterChip(f)).toList();
                                      } else {
                                        // Custom order: Selected filters first (in order of selection), then others
                                        List<String> orderedData = [];
                                        
                                        // 1. Add currently selected filters in their selection order (preserved by LinkedHashSet/standard Set behavior in Dart)
                                        for (var f in _activeFilters) {
                                           if (allFilters.contains(f)) orderedData.add(f);
                                        }
                                        
                                        // 2. Add remaining unselected filters
                                        for (var f in allFilters) {
                                           if (!orderedData.contains(f)) orderedData.add(f);
                                        }
                                        
                                        return orderedData.map((f) => _filterChip(f)).toList();
                                      }
                                    }(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  
  void _togglePin(BuildContext context, String id) {
     // Identify type and call provider
     final notesProvider = Provider.of<NotesProvider>(context, listen: false);
     final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
     final moneyProvider = Provider.of<MoneyProvider>(context, listen: false);

     if (notesProvider.notes.any((n) => n.id == id)) {
        notesProvider.togglePin(id);
     } else if (eventsProvider.events.any((e) => e.id == id)) {
        eventsProvider.togglePin(id);
     } else if (moneyProvider.transactions.any((t) => t['id'] == id)) {
        moneyProvider.togglePin(id);
     }
  }

  // --- ITEM RENDERING ---
  Widget _buildSelectableItem(BuildContext context, dynamic item) {
    String? id;
    if (item is Note) id = item.id;
    else if (item is Task) id = item.id;
    else if (item is Event) id = item.id;
    else if (item is Map && item.containsKey('id')) id = item['id'];

    final bool isSelected = id != null && _selectedIds.contains(id);
    
    final child = GestureDetector(
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

          }
        }
      },
      onLongPress: () {
        if (id != null) {
          setState(() { 
            _isMultiSelect = true; 
            _selectedIds.add(id!); 
          });
        }
      },
      child: AnimatedScale(
        scale: isSelected ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isMultiSelect, 
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

    if (item is Task && id != null) {
      return Dismissible(
        key: Key("task_$id"),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: 0.2},
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 28),
        ),
        onDismissed: (_) {
           Provider.of<TasksProvider>(context, listen: false).toggleTask(id!);
           ScaffoldMessenger.of(context).clearSnackBars();
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text("Task Completed"), 
               backgroundColor: Colors.green,
               duration: const Duration(milliseconds: 1500),
               action: SnackBarAction(label: "UNDO", textColor: Colors.white, onPressed: () {
                 Provider.of<TasksProvider>(context, listen: false).toggleTask(id!);
               }),
             )
           );
        },
        child: child,
      );
    }

    return child;
  }

  Widget _buildGridItem(BuildContext context, dynamic item) {
    if (item == 'EXPENSE_WIDGET') return const ExpenseSummaryWidget();
    if (item is Note) return WidgetFactory.build(context, item);
    if (item is Task) return _buildTaskCard(item);
    if (item is Event) return item.isDayCounter ? DayCounterWidget(event: item) : EventTicker(event: item);
    if (item is Map) return _buildMoneyCard(Map<String, dynamic>.from(item));
    return const SizedBox();
  }
  
  Widget _buildTaskCard(Task task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    
    // [THEME] Match other widgets (Black/Transparent look with border)
    Color cardColor = isDark ? theme.cardColor : Colors.white;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16), 
        // [THEME] Wider, more visible border
        border: isDark ? Border.all(color: Colors.white24, width: 2.0) : Border.all(color: theme.dividerColor, width: 2.0)
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
            // [INTERACTION] Toggle locally tracked "Recent Complete"
            setState(() {
              if (!task.isDone) {
                  _recentlyCompletedIds.add(task.id);
              } else {
                  _recentlyCompletedIds.remove(task.id); 
              }
            });
            Provider.of<TasksProvider>(context, listen: false).toggleTask(task.id);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                // Checkbox Visual
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Container(
                    width: 24, height: 24, 
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      border: Border.all(
                        color: task.priority == 3 ? Colors.redAccent : (task.priority == 2 ? Colors.orangeAccent : textColor), 
                        width: 2
                      ),
                      color: Colors.transparent 
                    ),
                    child: task.isDone 
                        ? Icon(Icons.check, size: 16, color: textColor) 
                        : null,
                  ),
                ),
                if (task.priority > 1) Icon(CupertinoIcons.exclamationmark_circle, size: 16, color: task.priority == 3 ? Colors.redAccent : Colors.orangeAccent),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.title, 
              style: TextStyle(
                color: textColor.withOpacity(task.isDone ? 0.5 : 1.0), 
                fontWeight: FontWeight.bold,
                decoration: task.isDone ? TextDecoration.lineThrough : null,
              ), 
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoneyCard(Map<String, dynamic> tx) {
    final bool isExp = (tx['amount'] as double) < 0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    
    final Color accentColor = isExp ? Colors.redAccent : Colors.greenAccent;
    final Color cardBg = isDark ? theme.cardColor : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white24, width: 2.0) : Border.all(color: accentColor.withOpacity(0.3), width: 2.0)
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        crossAxisAlignment: CrossAxisAlignment.start, 
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isExp ? CupertinoIcons.arrow_down_right : CupertinoIcons.arrow_up_right, color: accentColor, size: 18),
          const SizedBox(height: 5),
          Text(
            tx['title'], 
            style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "\$${(tx['amount'] as double).abs().toStringAsFixed(2)}", 
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
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
    final bool isSelected = _activeFilters.contains(label);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (label == 'All') {
             _activeFilters = {'All'};
          } else {
             if (_activeFilters.contains('All')) {
               _activeFilters.remove('All');
               _activeFilters.add(label);
             } else {
               if (_activeFilters.contains(label)) {
                 _activeFilters.remove(label);
                 if (_activeFilters.isEmpty) _activeFilters.add('All');
               } else {
                 _activeFilters.add(label);
               }
             }
          }
          StorageService.saveDashboardFilters(_activeFilters.toList());
        });
      },
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
                    crossAxisCount: 4, mainAxisSpacing: 25, crossAxisSpacing: 15,
                    children: [
                      _quickAddOption(context, CupertinoIcons.sparkles, "AI Assist", textColor, () { 
                        Navigator.pop(ctx); 
                        Provider.of<UserProvider>(context, listen: false).changeView('ai');
                      }),
                      _quickAddOption(context, CupertinoIcons.doc_text, "Note", textColor, () { 
                        Navigator.pop(ctx); 
                        Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(initialFolder: isFolderView ? currentFolder : null))); 
                      }),
                      _quickAddOption(context, CupertinoIcons.check_mark_circled, "Task", textColor, () { 
                        Navigator.pop(ctx); 
                        _showTaskCreator(context); 
                      }),
                      _quickAddOption(context, CupertinoIcons.money_dollar, "Expense", textColor, () { 
                        Navigator.pop(ctx); 
                        _showTransactionEditor(context, {'title': '', 'amount': 0.0}); 
                      }),
                      _quickAddOption(context, CupertinoIcons.calendar, "Event", textColor, () { 
                        Navigator.pop(ctx); 
                        _showEventEditor(context, Event(id: const Uuid().v4(), title: "", date: DateTime.now(), endTime: DateTime.now().add(const Duration(hours: 1)), location: "", isAllDay: false, isDayCounter: false, color: Colors.blue)); 
                      }),

                      // MOVE IN BUTTON
                       if (isFolderView)
                        _quickAddOption(context, CupertinoIcons.tray_arrow_down, "Move In", textColor, () => _showMoveInDialog(context)),
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
                          _buildDashboardToggle("Tasks", CupertinoIcons.check_mark_circled, textColor, 'Tasks'),
                          _buildDashboardToggle("Money", CupertinoIcons.money_dollar, textColor, 'Money'),
                          _buildDashboardToggle("Events", CupertinoIcons.calendar, textColor, 'Events'),

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

  Widget _quickAddOption(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
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
                         _folderWidgetOption(context, "Tasks", CupertinoIcons.check_mark_circled, Colors.greenAccent, enabled.contains('Tasks'), () => provider.toggleFolderWidget(folder, 'Tasks')),
                         _folderWidgetOption(context, "Events", CupertinoIcons.calendar, Colors.orangeAccent, enabled.contains('Events'), () => provider.toggleFolderWidget(folder, 'Events')),
                         _folderWidgetOption(context, "Money", CupertinoIcons.money_dollar, Colors.redAccent, enabled.contains('Money'), () => provider.toggleFolderWidget(folder, 'Money')),

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

  Widget _folderWidgetOption(BuildContext context, String label, IconData icon, Color color, bool isEnabled, VoidCallback onTap) {
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