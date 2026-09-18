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
import '../../providers/chat_provider.dart';

import '../../models/note_model.dart';
import '../../models/task_model.dart';
import '../../models/event_model.dart';
import '../../models/currency_model.dart';

import '../../services/storage_service.dart';

import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart';
import '../notes/note_editor_screen.dart';
import '../apps/wallet_screen.dart';
import '../calendar/calendar_screen.dart';

import '../../widgets/smart_widgets/widget_factory.dart';
import '../../widgets/smart_widgets/expense_widget.dart';
import '../../widgets/smart_widgets/expenses_chart_widget.dart';
import '../../widgets/smart_widgets/task_priority_widget.dart';
import '../../widgets/smart_widgets/savings_goal_widget.dart';
import '../../widgets/smart_widgets/sleep_energy_widget.dart';
import '../../widgets/smart_widgets/day_counter_widget.dart';
import '../../widgets/smart_widgets/ios_widget_gallery_sheet.dart';
import '../../widgets/event_ticker.dart';
import '../../widgets/receipt_scanner_sheet.dart';
import '../../widgets/ai_briefing_sheet.dart';
import 'widget_studio_screen.dart';
import '../../widgets/common/minimalist_toast.dart';

class ThingsGridScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState> parentScaffoldKey;
  const ThingsGridScreen({super.key, required this.parentScaffoldKey});

  @override
  State<ThingsGridScreen> createState() => _ThingsGridScreenState();
}

class _ThingsGridScreenState extends State<ThingsGridScreen> {
  bool _isGrid = true;
  bool _isMultiSelect = false;
  String _sortOrder = "Orderly"; // [ADDED]
  final Set<String> _selectedIds = {};
  Set<String> _activeFilters = {'All'}; // Changed to Set
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final Set<String> _recentlyCompletedIds = {};
  List<String> _sessionOrder = [];

  String _getItemId(dynamic item) {
    if (item is Note) return 'note_${item.id}';
    if (item is Task) return 'task_${item.id}';
    if (item is Event) return 'event_${item.id}';
    if (item is Map) return 'money_${item['id'] ?? 'tx_${item['title']}_${item['amount']}'}';
    if (item is String) return item;
    return item.toString();
  }

  @override
  void initState() {
    super.initState();
    _isGrid = Provider.of<UserProvider>(context, listen: false).isGrid;
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
    List<String> folderWidgets =
        notesProvider.getWidgetsForFolder(currentFolder);

    // Helper to check if a widget is enabled (Global or Folder-specific)
    bool isWidgetEnabled(String key) {
      if (isFolderView) {
        return folderWidgets.contains(key);
      } else {
        String lookup = key;
        if (key == 'Money') lookup = 'Wallet';
        if (key == 'Tasks') lookup = 'Focus';
        // Events is 'Events'
        return visibility[lookup] == true || folderWidgets.contains(key);
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
          return note.folder == currentFolder ||
              folderWidgets.contains(note.id);
        }
        final bool tagMatches = _activeFilters.any((f) => f.startsWith('#'))
            ? _activeFilters.any((f) => f.startsWith('#') && (note.title.contains(f) || note.content.contains(f)))
            : true;
        return (_activeFilters.contains('All') ||
                _activeFilters.contains('Notes') ||
                tagMatches) &&
            userProvider.isFolderVisible(note.folder);
      }).where((note) {
        if (!_isSearching || _searchController.text.isEmpty) return true;
        final q = _searchController.text.toLowerCase();
        return note.title.toLowerCase().contains(q) || note.content.toLowerCase().contains(q);
      }).toList();

      pinnedItems.addAll(visibleNotes.where((n) => n.isPinned));
      (unpinnedByType['Notes'] ??= []).addAll(visibleNotes.where((n) => !n.isPinned));
    }

    // 2. EVENTS
    if (isWidgetEnabled('Events') &&
        (_activeFilters.contains('All') || _activeFilters.contains('Events'))) {
      final events = eventsProvider.dashboardEvents.where((e) {
        if (!_isSearching || _searchController.text.isEmpty) return true;
        final q = _searchController.text.toLowerCase();
        return e.title.toLowerCase().contains(q) || e.description.toLowerCase().contains(q);
      }).toList();
      // Separate pinned/unpinned events
      pinnedItems.addAll(events.where((e) => e.isPinned));
      (unpinnedByType['Events'] ??= []).addAll(events.where((e) => !e.isPinned));

      if (!_activeFilters.contains('Events') &&
          (unpinnedByType['Events'] ?? []).whereType<Event>().length > 5) {
        // Basic capping logic if not focused on events
        // (Simplified for now as per previous block)
      }
    }

    // 3. MONEY
    final bool hasMoneyWidgets = isWidgetEnabled('Money') ||
        folderWidgets.contains('EXPENSES_CHART_WIDGET') ||
        folderWidgets.contains('SAVINGS_GOAL_WIDGET');
    if (hasMoneyWidgets &&
        (_activeFilters.contains('All') || _activeFilters.contains('Money'))) {
      final isSearchActive = _isSearching && _searchController.text.isNotEmpty;
      if (!isSearchActive) {
        if (isWidgetEnabled('Money')) {
          (unpinnedByType['Money'] ??= []).add('EXPENSE_WIDGET');
        }
        if (folderWidgets.contains('EXPENSES_CHART_WIDGET') ||
            visibility['ExpensesChart'] == true) {
          (unpinnedByType['Money'] ??= []).add('EXPENSES_CHART_WIDGET');
        }
        if (folderWidgets.contains('SAVINGS_GOAL_WIDGET') ||
            visibility['SavingsGoal'] == true) {
          (unpinnedByType['Money'] ??= []).add('SAVINGS_GOAL_WIDGET');
        }
      }
      if (!isSearchActive &&
          (folderWidgets.contains('SLEEP_ENERGY_WIDGET') ||
              visibility['SleepEnergy'] == true)) {
        (unpinnedByType['Notes'] ??= []).add('SLEEP_ENERGY_WIDGET');
      }

      final txns = moneyProvider.transactions.where((t) {
        if (!isSearchActive) return true;
        final q = _searchController.text.toLowerCase();
        final title = t['title']?.toString().toLowerCase() ?? '';
        final category = t['category']?.toString().toLowerCase() ?? '';
        return title.contains(q) || category.contains(q);
      }).toList();

      pinnedItems.addAll(txns.where((t) => t['isPinned'] == true));
      final unpinnedTxns = txns.where((t) => t['isPinned'] != true);
      (unpinnedByType['Money'] ??= []).addAll(isSearchActive ? unpinnedTxns : unpinnedTxns.take(2));
    }

    // 4. TASKS
    final bool hasTaskWidgets = isWidgetEnabled('Tasks') ||
        folderWidgets.contains('TASK_PRIORITY_WIDGET');
    if (hasTaskWidgets &&
        (_activeFilters.contains('All') || _activeFilters.contains('Tasks'))) {
      final isSearchActive = _isSearching && _searchController.text.isNotEmpty;
      if (!isSearchActive &&
          (folderWidgets.contains('TASK_PRIORITY_WIDGET') ||
              visibility['TaskPriority'] == true)) {
        (unpinnedByType['Tasks'] ??= []).add('TASK_PRIORITY_WIDGET');
      }
      if (isWidgetEnabled('Tasks')) {
        final tasks = tasksProvider.tasks
            .where((t) => !t.isDone || _recentlyCompletedIds.contains(t.id))
            .where((t) {
              if (!_isSearching || _searchController.text.isEmpty) return true;
              return t.title.toLowerCase().contains(_searchController.text.toLowerCase());
            });
        // Add all matching tasks if searching, otherwise cap at 4
        (unpinnedByType['Tasks'] ??= []).addAll((_isSearching && _searchController.text.isNotEmpty) ? tasks : tasks.take(4));
      }
    }

    // COMBINE UNPINNED IN ORDER
    if (_activeFilters.contains('All') || _activeFilters.isEmpty) {
      // DEFAULT ORDER for "All"
      unpinnedItems.addAll(unpinnedByType['Notes'] ?? []);
      unpinnedItems.addAll(unpinnedByType['Events'] ?? []);
      unpinnedItems.addAll(unpinnedByType['Money'] ?? []);
      unpinnedItems.addAll(unpinnedByType['Tasks'] ?? []);
    } else {
      // RESPECT FILTER ORDER
      for (var filter in _activeFilters) {
        if (unpinnedByType.containsKey(filter)) {
          unpinnedItems.addAll(unpinnedByType[filter] ?? []);
        }
      }
    }

    // COMBINE
    allItems.addAll(pinnedItems);

    // [SORTING LOGIC]
    if (_sortOrder == "Random") {
      unpinnedItems.shuffle();
    } else if (_sortOrder == "DateModified") {
      unpinnedItems.sort((a, b) => _getItemDate(b, useCreated: false)
          .compareTo(_getItemDate(a, useCreated: false)));
    } else if (_sortOrder == "DateCreated") {
      unpinnedItems.sort((a, b) => _getItemDate(b, useCreated: true)
          .compareTo(_getItemDate(a, useCreated: true)));
    }

    // [PRESERVE SESSION ORDER]
    // Keeps items in stable positions while editing or checking checkboxes on screen.
    // Re-sorts when re-entering screen or changing filter/sort options.
    if (_isSearching && _searchController.text.isNotEmpty) {
      _sessionOrder.clear();
    } else if (_sessionOrder.isEmpty) {
      _sessionOrder = unpinnedItems.map(_getItemId).toList();
    } else {
      final currentItemMap = <String, dynamic>{};
      final newItems = <dynamic>[];

      for (var item in unpinnedItems) {
        final id = _getItemId(item);
        if (_sessionOrder.contains(id)) {
          currentItemMap[id] = item;
        } else {
          newItems.add(item);
        }
      }

      final List<dynamic> orderedUnpinned = [];
      final List<String> updatedSessionOrder = [];

      // Add any newly created items at the top
      for (var newItem in newItems) {
        final id = _getItemId(newItem);
        orderedUnpinned.add(newItem);
        updatedSessionOrder.add(id);
      }

      // Add existing items in session order
      for (var id in _sessionOrder) {
        if (currentItemMap.containsKey(id)) {
          orderedUnpinned.add(currentItemMap[id]);
          updatedSessionOrder.add(id);
        }
      }

      _sessionOrder = updatedSessionOrder;
      unpinnedItems = orderedUnpinned;
    }

    allItems.addAll(unpinnedItems);

    return LifeAppScaffold(
      title: _isMultiSelect
          ? "${_selectedIds.length} SELECTED"
          : (isFolderView ? currentFolder.toUpperCase() : "THINGS"),
      onOpenDrawer: () => widget.parentScaffoldKey.currentState?.openDrawer(),
      actions: [
        if (_isMultiSelect)
          IconButton(
              icon: const Icon(CupertinoIcons.clear_circled,
                  color: Colors.redAccent),
              onPressed: _exitMultiSelect)
        else ...[
          // VISIBILITY FILTER / CUSTOMIZER

          IconButton(
            icon: Icon(
                _isSearching ? CupertinoIcons.clear : CupertinoIcons.search,
                color: textColor),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: Icon(
                _isGrid
                    ? CupertinoIcons.list_bullet
                    : CupertinoIcons.square_grid_2x2,
                color: textColor),
            onPressed: () {
              setState(() => _isGrid = !_isGrid);
              Provider.of<UserProvider>(context, listen: false).setGrid(_isGrid);
            },
          ),
        ]
      ],
      floatingActionButton: _isMultiSelect
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 110),
              child: FloatingActionButton(
                onPressed: () => _showQuickAddMenu(context),
                backgroundColor: isDark ? Colors.white : Colors.black,
                elevation: 0,
                shape: const CircleBorder(),
                child: Icon(CupertinoIcons.add,
                    color: isDark ? Colors.black : Colors.white, size: 28),
              ),
            ),
      bottomSheet: _isMultiSelect
          ? (() {
              // [LOGIC] Check if merge is possible (at least 2 notes selected)
              final selectedNotesCount = _selectedIds
                  .where((id) => notesProvider.notes.any((n) => n.id == id))
                  .length;
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
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Notes Merged!")));
                          }),

                    // PIN BUTTON (Optional, but useful)
                    IconButton(
                        icon: Icon(CupertinoIcons.pin, color: textColor),
                        onPressed: () {
                          for (var id in _selectedIds) {
                            _togglePin(context, id);
                          }
                          _exitMultiSelect();
                        }),

                    // MOVE BUTTON
                    IconButton(
                        tooltip: "Move to Folder",
                        icon: Icon(CupertinoIcons.folder_badge_plus,
                            color: textColor),
                        onPressed: () {
                          _showFolderSelectionDialog(context);
                        }),

                    // DELETE BUTTON
                    IconButton(
                        icon: Icon(CupertinoIcons.trash, color: textColor),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: theme.cardColor,
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20))),
                            builder: (ctx) {
                              final isDark =
                                  theme.brightness == Brightness.dark;
                              return Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(25, 20, 25, 40),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                            color: theme.dividerColor,
                                            borderRadius:
                                                BorderRadius.circular(2))),
                                    const SizedBox(height: 25),
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.redAccent.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(CupertinoIcons.trash,
                                          color: Colors.redAccent, size: 24),
                                    ),
                                    const SizedBox(height: 15),
                                    Text(
                                        "Delete ${_selectedIds.length} item${_selectedIds.length > 1 ? 's' : ''}?",
                                        style: TextStyle(
                                            color: textColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text("This action cannot be undone.",
                                        style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 14)),
                                    const SizedBox(height: 25),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: CupertinoButton(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            color: isDark
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.black
                                                    .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: Text("Cancel",
                                                style: TextStyle(
                                                    color: textColor,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            onPressed: () => Navigator.pop(ctx),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: CupertinoButton(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            color: Colors.redAccent,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: const Text("Delete",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            onPressed: () {
                                              for (var id in _selectedIds) {
                                                notesProvider.deleteNotes(id);
                                                tasksProvider.deleteTask(id);
                                                eventsProvider.removeEvent(id);
                                                moneyProvider
                                                    .removeTransactionById(id);
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
                        }),

                    // CLOSE BUTTON
                    Container(width: 1, height: 30, color: theme.dividerColor),
                    IconButton(
                        icon: Icon(CupertinoIcons.xmark,
                            color: secondaryTextColor),
                        onPressed: _exitMultiSelect),
                  ],
                ),
              );
            }())
          : null,
      child: Stack(
        children: [
          // 1. CONTENT LAYER
          Positioned.fill(
            child: allItems.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(CupertinoIcons.square_grid_2x2,
                            size: 48,
                            color: secondaryTextColor.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text("Your dashboard is empty.",
                            style: TextStyle(
                                color: secondaryTextColor, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text("Add items or enable apps in Settings.",
                            style: TextStyle(
                                color: secondaryTextColor.withOpacity(0.7),
                                fontSize: 13)),
                      ]))
                : _isGrid
                    ? Builder(
                        builder: (ctx) {
                          final media = MediaQuery.of(ctx);
                          final isLandscape = media.orientation == Orientation.landscape;
                          final gridCount = isLandscape ? (media.size.width > 900 ? 4 : 3) : 2;
                          return SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(15, 80, 15, isLandscape ? 120 : 240),
                            child: StaggeredGrid.count(
                              crossAxisCount: gridCount,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              children: allItems.map((item) {
                                return StaggeredGridTile.fit(
                                  crossAxisCellCount: 1,
                                  child: _buildSelectableItem(context, item),
                                );
                              }).toList(),
                            ),
                          );
                        },
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
              top: 0,
              left: 0,
              right: 0,
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 5),
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
                                      prefixIcon: Icon(CupertinoIcons.search,
                                          color: secondaryTextColor, size: 20),
                                      hintStyle:
                                          TextStyle(color: secondaryTextColor),
                                      contentPadding:
                                          const EdgeInsets.only(top: 12)),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                     children: [

                                       ...(() {
                                         // Extract hashtags from notes
                                         final notesProv = Provider.of<NotesProvider>(context, listen: false);
                                         final Set<String> extractedTags = {};
                                         for (var note in notesProv.notes) {
                                           final matches = RegExp(r'#\w+').allMatches("${note.title} ${note.content}");
                                           for (var m in matches) {
                                             extractedTags.add(m.group(0)!);
                                           }
                                         }

                                         List<String> allFilters = [
                                           "All",
                                           "Notes",
                                           "Tasks",
                                           "Money",
                                           "Events",
                                           ...extractedTags.take(4),
                                         ];

                                         if (_activeFilters.contains('All')) {
                                           return allFilters
                                               .map((f) => _filterChip(f))
                                               .toList();
                                         } else {
                                           List<String> orderedData = [];
                                           for (var f in _activeFilters) {
                                             if (allFilters.contains(f))
                                               orderedData.add(f);
                                           }
                                           for (var f in allFilters) {
                                             if (!orderedData.contains(f))
                                               orderedData.add(f);
                                           }
                                           return orderedData
                                               .map((f) => _filterChip(f))
                                               .toList();
                                         }
                                       }()),

                                      // [SORT ORDER BUTTON]
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                            color: secondaryTextColor
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(Icons.more_horiz,
                                              size: 18, color: textColor),
                                          onPressed: () {
                                            showModalBottomSheet(
                                                context: context,
                                                backgroundColor:
                                                    theme.cardColor,
                                                shape:
                                                    const RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                                top: Radius
                                                                    .circular(
                                                                        20))),
                                                builder: (ctx) {
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            20),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                            width: 40,
                                                            height: 4,
                                                            decoration: BoxDecoration(
                                                                color: theme
                                                                    .dividerColor,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            2))),
                                                        const SizedBox(
                                                            height: 20),
                                                        Text("DISPLAY OPTIONS",
                                                            style: TextStyle(
                                                                color:
                                                                    textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                letterSpacing:
                                                                    1.5,
                                                                fontSize: 12)),
                                                        const SizedBox(
                                                            height: 20),

                                                        // VIEW MODE
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                                  GestureDetector(
                                                                onTap: () {
                                                                  setState(() =>
                                                                      _isGrid =
                                                                          true);
                                                                  Provider.of<UserProvider>(context, listen: false).setGrid(true);
                                                                  Navigator.pop(
                                                                      ctx);
                                                                },
                                                                child:
                                                                    Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12),
                                                                  decoration: BoxDecoration(
                                                                      color: _isGrid
                                                                          ? textColor
                                                                          : Colors
                                                                              .transparent,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              12),
                                                                      border: Border.all(
                                                                          color:
                                                                              theme.dividerColor)),
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Icon(
                                                                          CupertinoIcons
                                                                              .square_grid_2x2,
                                                                          size:
                                                                              16,
                                                                          color: _isGrid
                                                                              ? theme.scaffoldBackgroundColor
                                                                              : textColor),
                                                                      const SizedBox(
                                                                          width:
                                                                              8),
                                                                      Text(
                                                                          "Grid",
                                                                          style: TextStyle(
                                                                              color: _isGrid ? theme.scaffoldBackgroundColor : textColor,
                                                                              fontWeight: FontWeight.bold))
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 10),
                                                            Expanded(
                                                              child:
                                                                  GestureDetector(
                                                                onTap: () {
                                                                  setState(() =>
                                                                      _isGrid =
                                                                          false);
                                                                  Provider.of<UserProvider>(context, listen: false).setGrid(false);
                                                                  Navigator.pop(
                                                                      ctx);
                                                                },
                                                                child:
                                                                    Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12),
                                                                  decoration: BoxDecoration(
                                                                      color: !_isGrid
                                                                          ? textColor
                                                                          : Colors
                                                                              .transparent,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              12),
                                                                      border: Border.all(
                                                                          color:
                                                                              theme.dividerColor)),
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Icon(
                                                                          CupertinoIcons
                                                                              .list_bullet,
                                                                          size:
                                                                              16,
                                                                          color: !_isGrid
                                                                              ? theme.scaffoldBackgroundColor
                                                                              : textColor),
                                                                      const SizedBox(
                                                                          width:
                                                                              8),
                                                                      Text(
                                                                          "List",
                                                                          style: TextStyle(
                                                                              color: !_isGrid ? theme.scaffoldBackgroundColor : textColor,
                                                                              fontWeight: FontWeight.bold))
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        const SizedBox(
                                                            height: 25),
                                                        Align(
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            child: Text(
                                                                "SORT BY",
                                                                style: TextStyle(
                                                                    color:
                                                                        secondaryTextColor,
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold))),
                                                        const SizedBox(
                                                            height: 10),

                                                        // Orderly
                                                        ListTile(
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          leading: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              decoration: BoxDecoration(
                                                                  color: _sortOrder ==
                                                                          "Orderly"
                                                                      ? textColor
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : Colors
                                                                          .transparent,
                                                                  shape: BoxShape
                                                                      .circle),
                                                              child: Icon(
                                                                  CupertinoIcons
                                                                      .folder,
                                                                  size: 18,
                                                                  color: _sortOrder ==
                                                                          "Orderly"
                                                                      ? textColor
                                                                      : secondaryTextColor)),
                                                          title: Text(
                                                              "Category (Orderly)",
                                                              style: TextStyle(
                                                                  color:
                                                                      textColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      14)),
                                                          trailing: _sortOrder ==
                                                                  "Orderly"
                                                              ? Icon(
                                                                  CupertinoIcons
                                                                      .check_mark,
                                                                  color:
                                                                      textColor,
                                                                  size: 18)
                                                              : null,
                                                          onTap: () {
                                                            setState(() =>
                                                                _sortOrder =
                                                                    "Orderly");
                                                            Navigator.pop(ctx);
                                                          },
                                                        ),

                                                        // Date Modified
                                                        ListTile(
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          leading: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              decoration: BoxDecoration(
                                                                  color: _sortOrder ==
                                                                          "DateModified"
                                                                      ? textColor
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : Colors
                                                                          .transparent,
                                                                  shape: BoxShape
                                                                      .circle),
                                                              child: Icon(
                                                                  CupertinoIcons
                                                                      .time,
                                                                  size: 18,
                                                                  color: _sortOrder ==
                                                                          "DateModified"
                                                                      ? textColor
                                                                      : secondaryTextColor)),
                                                          title: Text(
                                                              "Date Modified",
                                                              style: TextStyle(
                                                                  color:
                                                                      textColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      14)),
                                                          trailing: _sortOrder ==
                                                                  "DateModified"
                                                              ? Icon(
                                                                  CupertinoIcons
                                                                      .check_mark,
                                                                  color:
                                                                      textColor,
                                                                  size: 18)
                                                              : null,
                                                          onTap: () {
                                                            setState(() =>
                                                                _sortOrder =
                                                                    "DateModified");
                                                            Navigator.pop(ctx);
                                                          },
                                                        ),

                                                        // Date Created
                                                        ListTile(
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          leading: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              decoration: BoxDecoration(
                                                                  color: _sortOrder ==
                                                                          "DateCreated"
                                                                      ? textColor
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : Colors
                                                                          .transparent,
                                                                  shape: BoxShape
                                                                      .circle),
                                                              child: Icon(
                                                                  CupertinoIcons
                                                                      .calendar_today,
                                                                  size: 18,
                                                                  color: _sortOrder ==
                                                                          "DateCreated"
                                                                      ? textColor
                                                                      : secondaryTextColor)),
                                                          title: Text(
                                                              "Date Created",
                                                              style: TextStyle(
                                                                  color:
                                                                      textColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      14)),
                                                          trailing: _sortOrder ==
                                                                  "DateCreated"
                                                              ? Icon(
                                                                  CupertinoIcons
                                                                      .check_mark,
                                                                  color:
                                                                      textColor,
                                                                  size: 18)
                                                              : null,
                                                          onTap: () {
                                                            setState(() =>
                                                                _sortOrder =
                                                                    "DateCreated");
                                                            Navigator.pop(ctx);
                                                          },
                                                        ),

                                                        // Shuffle
                                                        ListTile(
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          leading: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              decoration: BoxDecoration(
                                                                  color: _sortOrder ==
                                                                          "Random"
                                                                      ? textColor
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : Colors
                                                                          .transparent,
                                                                  shape: BoxShape
                                                                      .circle),
                                                              child: Icon(
                                                                  CupertinoIcons
                                                                      .shuffle,
                                                                  size: 18,
                                                                  color: _sortOrder ==
                                                                          "Random"
                                                                      ? textColor
                                                                      : secondaryTextColor)),
                                                          title: Text(
                                                              "Mix (Random)",
                                                              style: TextStyle(
                                                                  color:
                                                                      textColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize:
                                                                      14)),
                                                          trailing: _sortOrder ==
                                                                  "Random"
                                                              ? Icon(
                                                                  CupertinoIcons
                                                                      .check_mark,
                                                                  color:
                                                                      textColor,
                                                                  size: 18)
                                                              : null,
                                                          onTap: () {
                                                            setState(() =>
                                                                _sortOrder =
                                                                    "Random");
                                                            Navigator.pop(ctx);
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                });
                                          },
                                        ),
                                      ),
                                    ],
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

  DateTime _getItemDate(dynamic item, {bool useCreated = false}) {
    if (item is Note) {
      return useCreated ? item.createdAt : item.updatedAt;
    } else if (item is Task) {
      return item.createdAt;
    } else if (item is Event) {
      return item.date; // Events sorted by their occurrence date usually
    } else if (item is Map && item.containsKey('date')) {
      // Money Transaction
      return DateTime.tryParse(item['addedDate'] ?? item['date']) ??
          DateTime.now();
    }
    return DateTime.now();
  }

  // --- ITEM RENDERING ---
  Widget _buildSelectableItem(BuildContext context, dynamic item) {
    String? id;
    if (item is Note) {
      id = item.id;
    } else if (item is Task)
      id = item.id;
    else if (item is Event)
      id = item.id;
    else if (item is Map && item.containsKey('id'))
      id = item['id'];
    else if (item is String)
      id = item;

    final bool isSelected = id != null && _selectedIds.contains(id);

    final child = GestureDetector(
      onTap: () {
        if (_isMultiSelect && id != null) {
          _toggleSelection(id);
        } else {
          // SAFE NAVIGATION
          if (item is Note) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => NoteEditorScreen(note: item))).then((_) {
              if (mounted) setState(() => _sessionOrder.clear());
            });
          } else if (item is Event) {
            _showEventEditor(context, item);
          } else if (item is Map && item.containsKey('amount')) {
            _showTransactionEditor(context, Map<String, dynamic>.from(item));
          } else if (item == 'EXPENSE_WIDGET') {
            Provider.of<UserProvider>(context, listen: false)
                .changeView('wallet');
          } else if (item == 'SAVINGS_GOAL_WIDGET') {
            _showQuickSavingsDialog(context);
          }
        }
      },
      onLongPress: () {
        if (_isMultiSelect) {
          if (id != null) _toggleSelection(id);
          return;
        }
        if (item is Note) {
          _showNoteWidgetOptions(context, item);
        } else {
          if (id != null) {
            setState(() {
              _isMultiSelect = true;
              _selectedIds.add(id!);
            });
          }
        }
      },
      child: AnimatedScale(
        scale: isSelected ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isMultiSelect,
              child: SizedBox(
                width: double.infinity,
                child: _buildGridItem(context, item),
              ),
            ),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Provider.of<UserProvider>(context).accentColor,
                        width: 4),
                  ),
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.all(10),
                  child: const Icon(CupertinoIcons.check_mark_circled_solid,
                      color: Colors.white),
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
          child: const Icon(CupertinoIcons.checkmark_alt,
              color: Colors.white, size: 28),
        ),
        onDismissed: (_) {
          Provider.of<TasksProvider>(context, listen: false).toggleTask(id!);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text("Task Completed"),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 1500),
            action: SnackBarAction(
                label: "UNDO",
                textColor: Colors.white,
                onPressed: () {
                  Provider.of<TasksProvider>(context, listen: false)
                      .toggleTask(id!);
                }),
          ));
        },
        child: child,
      );
    }

    return child;
  }

  Widget _buildGridItem(BuildContext context, dynamic item) {
    if (item == 'EXPENSE_WIDGET') return const ExpenseSummaryWidget();
    if (item == 'EXPENSES_CHART_WIDGET') return ExpensesChartWidget(isCompact: _isGrid);
    if (item == 'TASK_PRIORITY_WIDGET') return const TaskPriorityWidget();
    if (item == 'SAVINGS_GOAL_WIDGET') return const SavingsGoalWidget();
    if (item == 'SLEEP_ENERGY_WIDGET') return const SleepEnergyWidget();
    if (item is Note) return WidgetFactory.build(context, item);
    if (item is Task) return _buildTaskCard(item);
    if (item is Event)
      return item.isDayCounter
          ? DayCounterWidget(event: item)
          : EventTicker(event: item);
    if (item is Map) return _buildMoneyCard(Map<String, dynamic>.from(item));
    return const SizedBox();
  }

  Widget _buildTaskCard(Task task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    Color cardColor = isDark ? theme.cardColor : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: task.priority == 3
                ? Colors.redAccent.withOpacity(0.5)
                : (task.priority == 2
                    ? Colors.orangeAccent.withOpacity(0.5)
                    : (isDark ? Colors.white12 : Colors.black.withOpacity(0.08))),
            width: 1.0),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            if (!task.isDone) {
              _recentlyCompletedIds.add(task.id);
            } else {
              _recentlyCompletedIds.remove(task.id);
            }
          });
          Provider.of<TasksProvider>(context, listen: false)
              .toggleTask(task.id);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.isDone
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        border: Border.all(
                            color: task.isDone
                                ? (isDark ? Colors.white : Colors.black)
                                : (task.priority == 3
                                    ? Colors.redAccent
                                    : (task.priority == 2
                                        ? Colors.orangeAccent
                                        : secondaryTextColor)),
                            width: 1.5),
                      ),
                      child: task.isDone
                          ? Icon(Icons.check,
                              size: 14,
                              color: isDark ? Colors.black : Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "TO-DO",
                      style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2),
                    ),
                  ],
                ),
                if (task.priority > 1)
                  Icon(CupertinoIcons.exclamationmark_circle_fill,
                      size: 15,
                      color: task.priority == 3
                          ? Colors.redAccent
                          : Colors.orangeAccent),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.title,
              style: TextStyle(
                color: textColor.withOpacity(task.isDone ? 0.4 : 1.0),
                fontWeight: FontWeight.w600,
                fontSize: 14,
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
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final Color accentColor = isExp ? Colors.redAccent : Colors.greenAccent;
    final Color cardBg = isDark ? theme.cardColor : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isDark
                ? accentColor.withOpacity(0.25)
                : accentColor.withOpacity(0.3),
            width: 1.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    isExp
                        ? CupertinoIcons.arrow_down_right
                        : CupertinoIcons.arrow_up_right,
                    color: accentColor,
                    size: 14),
              ),
              Text(
                isExp ? "EXPENSE" : "INCOME",
                style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tx['title'],
            style: TextStyle(
                color: secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            "${isExp ? '-' : '+'}${AppCurrency.getSymbol(tx['currency']?.toString() ?? Provider.of<MoneyProvider>(context, listen: false).currentCurrency)}${(tx['amount'] as double).abs().toStringAsFixed(2)}",
            style: TextStyle(
                color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
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
    setState(() {
      _isMultiSelect = false;
      _selectedIds.clear();
    });
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
          border: Border.all(
              color: isSelected ? Colors.transparent : theme.dividerColor),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected
                    ? theme.scaffoldBackgroundColor
                    : textColor.withOpacity(0.7),
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }

  // --- POPUPS ---

  void _showNoteWidgetOptions(BuildContext context, Note note) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(
                note.isExpanded ? CupertinoIcons.fullscreen_exit : CupertinoIcons.fullscreen,
                color: textColor,
              ),
              title: Text(note.isExpanded ? "Collapse Note Widget" : "Expand Note Widget", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                notesProvider.toggleNoteExpansion(note.id);
              },
            ),
            ListTile(
              leading: Icon(
                note.isPinned ? CupertinoIcons.pin_slash_fill : CupertinoIcons.pin_fill,
                color: textColor,
              ),
              title: Text(note.isPinned ? "Unpin Note" : "Pin Note", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                notesProvider.togglePin(note.id);
              },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.checkmark_circle, color: textColor),
              title: Text("Select (Multiselect)", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _isMultiSelect = true;
                  _selectedIds.add(note.id);
                });
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
              title: const Text("Delete Note", style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                notesProvider.deleteNotes(note.id);
                MinimalistToast.showUndo(
                  context,
                  title: note.title.isNotEmpty ? note.title : "Note",
                  onUndo: () => notesProvider.restoreNote(note),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor =
              theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05);

          Future<void> pickTime(bool isStart) async {
            final picked = await showTimePicker(
                context: context,
                initialTime: isStart ? startTime : endTime,
                builder: (context, child) => Theme(data: theme, child: child!));
            if (picked != null)
              setSheetState(() {
                if (isStart) {
                  startTime = picked;
                } else {
                  endTime = picked;
                }
              });
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                top: 20,
                left: 25,
                right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Edit Event",
                          style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: const Icon(CupertinoIcons.trash,
                              color: Colors.redAccent),
                          onPressed: () {
                            Provider.of<EventsProvider>(context, listen: false)
                                .removeEvent(existingEvent.id);
                            Navigator.pop(ctx);
                            MinimalistToast.showUndo(
                              context,
                              title: existingEvent.title.isNotEmpty ? existingEvent.title : "Event",
                              onUndo: () => Provider.of<EventsProvider>(context, listen: false)
                                  .restoreEvent(existingEvent),
                            );
                          })
                    ]),
                const SizedBox(height: 25),
                CupertinoTextField(
                    controller: titleCtrl,
                    placeholder: "Title",
                    placeholderStyle: TextStyle(color: secondaryTextColor),
                    style: TextStyle(color: textColor),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16)),
                const SizedBox(height: 15),
                CupertinoTextField(
                    controller: locCtrl,
                    placeholder: "Location",
                    placeholderStyle: TextStyle(color: secondaryTextColor),
                    style: TextStyle(color: textColor),
                    prefix: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Icon(Icons.location_on_outlined,
                            color: secondaryTextColor, size: 18)),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16)),
                const SizedBox(height: 15),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("All-day",
                              style: TextStyle(color: textColor, fontSize: 16)),
                          Switch(
                              value: isAllDay,
                              activeThumbColor: textColor,
                              onChanged: (val) =>
                                  setSheetState(() => isAllDay = val)),
                        ])),
                if (!isAllDay) ...[
                  const SizedBox(height: 15),
                  Row(children: [
                    Expanded(
                        child: _buildTimeInput(context, "Start",
                            startTime.format(context), () => pickTime(true))),
                    const SizedBox(width: 15),
                    Expanded(
                        child: _buildTimeInput(context, "End",
                            endTime.format(context), () => pickTime(false))),
                  ]),
                ],
                const SizedBox(height: 15),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(CupertinoIcons.sparkles,
                          color:
                              isDayCounter ? Colors.amber : secondaryTextColor,
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text("Special Day Counter",
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                            Text("Show on dashboard",
                                style: TextStyle(
                                    color: secondaryTextColor, fontSize: 11))
                          ])),
                      Switch(
                          value: isDayCounter,
                          activeThumbColor: Colors.amber,
                          onChanged: (val) =>
                              setSheetState(() => isDayCounter = val)),
                    ])),
                const SizedBox(height: 30),
                SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                        color: textColor,
                        borderRadius: BorderRadius.circular(15),
                        child: Text("Update Event",
                            style: TextStyle(
                                color: theme.scaffoldBackgroundColor,
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          DateTime startDt = DateTime(selectedDate.year,
                              selectedDate.month, selectedDate.day);
                          DateTime endDt = startDt;
                          if (!isAllDay) {
                            startDt = startDt.add(Duration(
                                hours: startTime.hour,
                                minutes: startTime.minute));
                            endDt = endDt.add(Duration(
                                hours: endTime.hour, minutes: endTime.minute));
                            if (endDt.isBefore(startDt))
                              endDt = endDt.add(const Duration(days: 1));
                          }
                          Provider.of<EventsProvider>(context, listen: false)
                              .editEvent(Event(
                                  id: existingEvent.id,
                                  title: titleCtrl.text,
                                  location: locCtrl.text,
                                  date: startDt,
                                  endTime: endDt,
                                  isAllDay: isAllDay,
                                  isDayCounter: isDayCounter,
                                  color: selectedColor));
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
    final amountCtrl =
        TextEditingController(text: (tx['amount'] as double).abs().toString());
    String selectedCat = tx['category'] ?? 'General';
    bool isExpense = (tx['amount'] as double) < 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final moneyProvider = Provider.of<MoneyProvider>(context);
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor =
              theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05);

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                top: 25,
                left: 25,
                right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Edit Transaction",
                          style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: const Icon(CupertinoIcons.trash,
                              color: Colors.redAccent),
                          onPressed: () {
                            if (tx['id'] != null) {
                              final deletedTx = Map<String, dynamic>.from(tx);
                              Provider.of<MoneyProvider>(context, listen: false)
                                  .removeTransactionById(tx['id']);
                              Navigator.pop(ctx);
                              MinimalistToast.showUndo(
                                context,
                                title: tx['title']?.toString().isNotEmpty == true
                                    ? tx['title'].toString()
                                    : "Expense",
                                onUndo: () => Provider.of<MoneyProvider>(context, listen: false)
                                    .restoreTransaction(deletedTx),
                              );
                            } else {
                              Navigator.pop(ctx);
                            }
                          })
                    ]),
                const SizedBox(height: 20),
                Container(
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Expanded(
                          child: GestureDetector(
                              onTap: () =>
                                  setSheetState(() => isExpense = true),
                              child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                      color: isExpense
                                          ? textColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text("Expense",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: isExpense
                                              ? theme.scaffoldBackgroundColor
                                              : secondaryTextColor,
                                          fontWeight: FontWeight.bold))))),
                      Expanded(
                          child: GestureDetector(
                              onTap: () =>
                                  setSheetState(() => isExpense = false),
                              child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                      color: !isExpense
                                          ? textColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text("Income",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: !isExpense
                                              ? theme.scaffoldBackgroundColor
                                              : secondaryTextColor,
                                          fontWeight: FontWeight.bold))))),
                    ])),
                const SizedBox(height: 25),
                CupertinoTextField(
                    controller: titleCtrl,
                    placeholder: "Title",
                    placeholderStyle: TextStyle(color: secondaryTextColor),
                    style: TextStyle(color: textColor),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16)),
                const SizedBox(height: 15),
                CupertinoTextField(
                    controller: amountCtrl,
                    placeholder: "0.00",
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    placeholderStyle: TextStyle(color: secondaryTextColor),
                    style: TextStyle(color: textColor),
                    prefix: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Icon(CupertinoIcons.money_dollar,
                            color: secondaryTextColor, size: 18)),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16)),
                const SizedBox(height: 25),
                if (isExpense)
                  SizedBox(
                      height: 40,
                      child:
                          ListView(scrollDirection: Axis.horizontal, children: [
                        ...moneyProvider.categories.map((cat) {
                          final isSelected = selectedCat == cat;
                          return GestureDetector(
                              onTap: () =>
                                  setSheetState(() => selectedCat = cat),
                              child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                      color: isSelected ? textColor : inputBg,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(cat,
                                      style: TextStyle(
                                          color: isSelected
                                              ? theme.scaffoldBackgroundColor
                                              : secondaryTextColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))));
                        }),
                      ])),
                const SizedBox(height: 30),
                SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                        color: textColor,
                        borderRadius: BorderRadius.circular(15),
                        child: Text("Update",
                            style: TextStyle(
                                color: theme.scaffoldBackgroundColor,
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          double val = double.tryParse(amountCtrl.text) ?? 0.0;
                          if (isExpense) {
                            val = -val.abs();
                          } else {
                            val = val.abs();
                          }
                          if (tx['id'] != null)
                            Provider.of<MoneyProvider>(context, listen: false)
                                .editTransaction(tx['id'], titleCtrl.text, val,
                                    isExpense ? selectedCat : 'Income');
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
        final bottomInset = MediaQuery.maybeOf(ctx)?.viewInsets.bottom ?? 0.0;

        return Padding(
          padding: EdgeInsets.only(
              bottom: bottomInset + 20,
              top: 20,
              left: 20,
              right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("NEW TASK",
                  style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: titleCtrl,
                      placeholder: "What needs to be done?",
                      placeholderStyle: const TextStyle(color: Colors.grey),
                      style: TextStyle(color: textColor),
                      decoration: const BoxDecoration(color: Colors.transparent),
                      autofocus: true,
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          Provider.of<TasksProvider>(ctx, listen: false)
                              .addTask(Task(
                                  id: const Uuid().v4(),
                                  title: val.trim(),
                                  isDone: false,
                                  createdAt: DateTime.now()));
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.arrow_up_circle_fill,
                        color: textColor, size: 30),
                    onPressed: () {
                      if (titleCtrl.text.trim().isNotEmpty) {
                        Provider.of<TasksProvider>(ctx, listen: false)
                            .addTask(Task(
                                id: const Uuid().v4(),
                                title: titleCtrl.text.trim(),
                                isDone: false,
                                createdAt: DateTime.now()));
                        Navigator.pop(ctx);
                      }
                    },
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeInput(
      BuildContext context, String label, String value, VoidCallback onTap) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: inputBg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  void _showMoveInDialog(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final String currentFolder = notesProvider.selectedFolder;
    // Get widgets NOT in current folder
    final availableWidgets =
        notesProvider.notes.where((n) => n.folder != currentFolder).toList();
    final Set<String> selectedForMove = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

          return Container(
            height: 500,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text("MOVE WIDGETS HERE",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Text("Select widgets to move to '$currentFolder'",
                    style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 12)),
                const SizedBox(height: 20),
                Expanded(
                  child: availableWidgets.isEmpty
                      ? Center(
                          child: Text("No other widgets found.",
                              style: TextStyle(color: theme.disabledColor)))
                      : ListView.builder(
                          itemCount: availableWidgets.length,
                          itemBuilder: (ctx, i) {
                            final w = availableWidgets[i];
                            final isSelected = selectedForMove.contains(w.id);
                            return GestureDetector(
                              onTap: () => setSheetState(() {
                                if (isSelected) {
                                  selectedForMove.remove(w.id);
                                } else {
                                  selectedForMove.add(w.id);
                                }
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Provider.of<UserProvider>(context)
                                          .accentColor
                                          .withOpacity(0.1)
                                      : theme.dividerColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                      color: isSelected
                                          ? Provider.of<UserProvider>(context)
                                              .accentColor
                                          : Colors.transparent),
                                ),
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.cube_box,
                                        color: Color(w.backgroundColor ??
                                            Colors.grey.value)),
                                    const SizedBox(width: 15),
                                    Expanded(
                                        child: Text(
                                            w.title.isNotEmpty
                                                ? w.title
                                                : "Widget",
                                            style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold))),
                                    if (isSelected)
                                      Icon(
                                          CupertinoIcons
                                              .check_mark_circled_solid,
                                          color:
                                              Provider.of<UserProvider>(context)
                                                  .accentColor)
                                  ],
                                ),
                              ),
                            );
                          }),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: Provider.of<UserProvider>(context).accentColor,
                    borderRadius: BorderRadius.circular(15),
                    onPressed: selectedForMove.isEmpty
                        ? null
                        : () {
                            notesProvider.batchMoveNotes(
                                selectedForMove.toList(), currentFolder);
                            Navigator.pop(ctx);
                            Navigator.pop(context); // Close Quick Add too
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    "Moved ${selectedForMove.length} widgets to $currentFolder")));
                          },
                    child: const Text("Move Selected",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _createWidgetNote(
      BuildContext context, String title, String type, Color color,
      {String content = ""}) {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final String currentFolder =
        provider.selectedFolder == 'All' ? 'General' : provider.selectedFolder;
    final newWidget = Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: currentFolder,
      widgetType: type,
      backgroundColor: color.value,
    );
    provider.addNote(newWidget);
  }

  void _createChecklistWidget(BuildContext context) {
    final titleCtrl = TextEditingController(text: "Checklist");
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("New Checklist Widget",
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: "e.g. Grocery List, Daily Routine",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text("Cancel", style: TextStyle(color: theme.disabledColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: textColor,
              foregroundColor: theme.scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final title = titleCtrl.text.trim().isNotEmpty
                  ? titleCtrl.text.trim()
                  : "Checklist";
              Navigator.pop(dlgCtx);
              _createWidgetNote(
                context,
                title,
                "checklist",
                textColor,
                content: "- [ ] First item\n- [ ] Second item",
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Created checklist '$title'")),
              );
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _createCounterWidget(BuildContext context) {
    final titleCtrl = TextEditingController(text: "Daily Counter");
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("New Counter Widget",
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: "e.g. Water, Habits, Reps",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text("Cancel", style: TextStyle(color: theme.disabledColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: textColor,
              foregroundColor: theme.scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final title = titleCtrl.text.trim().isNotEmpty
                  ? titleCtrl.text.trim()
                  : "Counter";
              Navigator.pop(dlgCtx);
              _createWidgetNote(
                context,
                title,
                "monitor",
                textColor,
                content: "0",
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Created counter '$title'")),
              );
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _createCountdownWidget(BuildContext context) {
    final titleCtrl = TextEditingController(text: "Upcoming Event");
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("New Countdown Widget",
              style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: "e.g. Trip, Launch, Birthday",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Target Date",
                    style: TextStyle(color: textColor, fontSize: 14)),
                subtitle: Text(
                    "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                    style: TextStyle(color: theme.disabledColor)),
                trailing: const Icon(CupertinoIcons.calendar),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setDlgState(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text("Cancel", style: TextStyle(color: theme.disabledColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: theme.scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final title = titleCtrl.text.trim().isNotEmpty
                    ? titleCtrl.text.trim()
                    : "Event";
                final dateStr = selectedDate.toIso8601String().split('T')[0];
                Navigator.pop(dlgCtx);
                _createWidgetNote(
                  context,
                  title,
                  "countdown",
                  textColor,
                  content: "[[date:$dateStr]]\nTarget date countdown",
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Created countdown '$title'")),
                );
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  void _createQuoteWidget(BuildContext context) {
    final quoteCtrl =
        TextEditingController(text: "Simplicity is the ultimate sophistication.");
    final authorCtrl = TextEditingController(text: "Leonardo da Vinci");
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("New Quote Widget",
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quoteCtrl,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Quote text...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: authorCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Author",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text("Cancel", style: TextStyle(color: theme.disabledColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: textColor,
              foregroundColor: theme.scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final q = quoteCtrl.text.trim();
              final a = authorCtrl.text.trim();
              final text = a.isNotEmpty ? "\"$q\"\n- $a" : "\"$q\"";
              Navigator.pop(dlgCtx);
              _createWidgetNote(
                context,
                "Quote",
                "quote",
                textColor,
                content: text,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Created quote widget")),
              );
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isEnabled,
    required Color textColor,
    required Color dimmedColor,
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEnabled
                  ? textColor.withOpacity(0.3)
                  : (isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEnabled
                      ? textColor.withOpacity(0.12)
                      : (isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04)),
                ),
                child: Icon(icon,
                    size: 18, color: isEnabled ? textColor : dimmedColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: dimmedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: isEnabled,
                activeColor: textColor,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateWidgetTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color textColor,
    required Color dimmedColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark
                    ? Colors.white12
                    : Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
                child: Icon(icon, size: 18, color: textColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: dimmedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.add_circled_solid,
                  size: 20, color: textColor),
            ],
          ),
        ),
      ),
    );
  }

  void _showWidgetCatalog(BuildContext context) {
    IOSWidgetGallerySheet.show(context, isGrid: _isGrid);
  }

  void _showQuickSavingsDialog(BuildContext context) {
    final moneyProv = Provider.of<MoneyProvider>(context, listen: false);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);

    final goals = moneyProv.savingsGoals;
    String? selectedGoalId = goals.isNotEmpty ? goals.first['id'] : null;
    final amountCtrl = TextEditingController(text: "50");
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: "500");
    bool isCreatingNew = goals.isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: (MediaQuery.maybeOf(ctx)?.viewInsets.bottom ?? 0.0) + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCreatingNew ? "NEW SAVINGS GOAL" : "ADD SAVINGS",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (goals.isNotEmpty)
                      GestureDetector(
                        onTap: () => setDialogState(() => isCreatingNew = !isCreatingNew),
                        child: Text(
                          isCreatingNew ? "Select Existing" : "+ New Goal",
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (!isCreatingNew && goals.isNotEmpty) ...[
                  Text("Goal", style: TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGoalId,
                        isExpanded: true,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
                        items: goals.map((g) {
                          final double cur = (g['currentAmount'] as num?)?.toDouble() ?? 0.0;
                          final double tgt = (g['targetAmount'] as num?)?.toDouble() ?? 0.0;
                          return DropdownMenuItem<String>(
                            value: g['id'],
                            child: Text("${g['title']} (${moneyProv.currentCurrencySymbol}${cur.toInt()}/${moneyProv.currentCurrencySymbol}${tgt.toInt()})"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedGoalId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text("Deposit Amount", style: TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixText: "${moneyProv.currentCurrencySymbol} ",
                        prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  Text("Goal Title", style: TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: titleCtrl,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "e.g. New Laptop, Vacation, Emergency",
                        hintStyle: TextStyle(color: secondaryColor.withOpacity(0.6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text("Target Amount", style: TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: targetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixText: "${moneyProv.currentCurrencySymbol} ",
                        prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textColor,
                      foregroundColor: theme.scaffoldBackgroundColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (!isCreatingNew && selectedGoalId != null) {
                        final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amt > 0) {
                          moneyProv.addGoalDeposit(selectedGoalId!, amt);
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Deposited ${moneyProv.currentCurrencySymbol}${amt.toStringAsFixed(0)} towards savings!"),
                            backgroundColor: Colors.green,
                          ));
                        }
                      } else {
                        final title = titleCtrl.text.trim();
                        final target = double.tryParse(targetCtrl.text.trim()) ?? 0.0;
                        if (title.isNotEmpty && target > 0) {
                          moneyProv.addSavingsGoal(title, target, DateTime.now().add(const Duration(days: 90)));
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Created savings goal: '$title'"),
                            backgroundColor: Colors.green,
                          ));
                        }
                      }
                    },
                    child: Text(
                      isCreatingNew ? "Create Goal" : "Save Funds",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQuickAddMenu(BuildContext context) {
    IOSWidgetGallerySheet.show(
      context,
      isGrid: _isGrid,
      onOpenNote: (folder) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(
              initialFolder: folder != 'All' ? folder : null,
            ),
          ),
        );
      },
      onOpenTaskCreator: () => _showTaskCreator(context),
      onOpenSavings: () => _showQuickSavingsDialog(context),
      onOpenEventCreator: () => _showEventEditor(
        context,
        Event(
          id: const Uuid().v4(),
          title: "",
          date: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 1)),
          location: "",
          isAllDay: false,
          isDayCounter: false,
          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
        ),
      ),
    );
  }

  void _showFolderSelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final notesProvider =
            Provider.of<NotesProvider>(context, listen: false);
        final folders = notesProvider.folders;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          height: 300,
          child: Column(
            children: [
              Text("Move to Folder",
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    if (folder == 'All')
                      return const SizedBox.shrink(); // Skip 'All'
                    return ListTile(
                      leading: const Icon(CupertinoIcons.folder),
                      title: Text(folder),
                      onTap: () {
                        notesProvider.batchMoveNotes(
                            _selectedIds.toList(), folder);
                        Navigator.pop(ctx);
                        _exitMultiSelect();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Moved to $folder")));
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
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setState) {
            final provider = Provider.of<NotesProvider>(context);
            final enabled = provider.getWidgetsForFolder(folder);
            final theme = Theme.of(context);
            final textColor = theme.textTheme.bodyLarge?.color;

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text("CUSTOMIZE '$folder'",
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 12)),
                  const SizedBox(height: 10),
                  Text("Select widgets to display in this folder.",
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 12)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _folderWidgetOption(
                            context,
                            "Tasks",
                            CupertinoIcons.check_mark_circled,
                            Colors.greenAccent,
                            enabled.contains('Tasks'),
                            () => provider.toggleFolderWidget(folder, 'Tasks')),
                        _folderWidgetOption(
                            context,
                            "Events",
                            CupertinoIcons.calendar,
                            Colors.orangeAccent,
                            enabled.contains('Events'),
                            () =>
                                provider.toggleFolderWidget(folder, 'Events')),
                        _folderWidgetOption(
                            context,
                            "Money",
                            CupertinoIcons.money_dollar,
                            Colors.redAccent,
                            enabled.contains('Money'),
                            () => provider.toggleFolderWidget(folder, 'Money')),
                      ],
                    ),
                  )
                ],
              ),
            );
          });
        });
  }

  Widget _folderWidgetOption(BuildContext context, String label, IconData icon,
      Color color, bool isEnabled, VoidCallback onTap) {
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20)),
      title: Text(label,
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold)),
      trailing: Switch(
        value: isEnabled,
        activeThumbColor: color,
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
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          final userProvider = Provider.of<UserProvider>(context);
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

          final labels = {
            'Brain': 'Notes', // OLD KEY, NEW LABEL
            'Focus': 'Tasks', // OLD KEY, NEW LABEL
            'Wallet': 'Wallet & Money',
            'Events': 'Calendar Events',
          };

          return Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 25),
                Text("DASHBOARD WIDGETS",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 20),
                ...userProvider.appVisibility.keys.map((key) {
                  if (!labels.containsKey(key)) return const SizedBox();
                  final isVisible = userProvider.appVisibility[key] ?? true;
                  return SwitchListTile(
                    title: Text(labels[key] ?? key,
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.bold)),
                    value: isVisible,
                    activeThumbColor: userProvider.accentColor,
                    onChanged: (val) => userProvider.toggleAppVisibility(key),
                  );
                }),
              ],
            ),
          );
        });
  }
}
