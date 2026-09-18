import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../providers/notes_provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/note_model.dart';
import '../../models/event_model.dart';

import 'expense_widget.dart';
import 'expenses_chart_widget.dart';
import 'task_priority_widget.dart';
import 'day_counter_widget.dart';
import 'sleep_energy_widget.dart';
import 'savings_goal_widget.dart';
import '../common/minimalist_toast.dart';

class IOSWidgetGallerySheet extends StatefulWidget {
  final String currentFolder;
  final bool isFolderView;
  final bool? isGrid;
  final Function(String folder)? onOpenNote;
  final VoidCallback? onOpenTaskCreator;
  final VoidCallback? onOpenSavings;
  final VoidCallback? onOpenEventCreator;

  const IOSWidgetGallerySheet({
    super.key,
    required this.currentFolder,
    required this.isFolderView,
    this.isGrid,
    this.onOpenNote,
    this.onOpenTaskCreator,
    this.onOpenSavings,
    this.onOpenEventCreator,
  });

  static void show(
    BuildContext context, {
    bool? isGrid,
    Function(String folder)? onOpenNote,
    VoidCallback? onOpenTaskCreator,
    VoidCallback? onOpenSavings,
    VoidCallback? onOpenEventCreator,
  }) {
    final notesProv = Provider.of<NotesProvider>(context, listen: false);
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final currentFolder = notesProv.selectedFolder;
    final isFolderView = currentFolder != 'All';
    final effectiveIsGrid = isGrid ?? userProv.isGrid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IOSWidgetGallerySheet(
        currentFolder: currentFolder,
        isFolderView: isFolderView,
        isGrid: effectiveIsGrid,
        onOpenNote: onOpenNote,
        onOpenTaskCreator: onOpenTaskCreator,
        onOpenSavings: onOpenSavings,
        onOpenEventCreator: onOpenEventCreator,
      ),
    );
  }

  @override
  State<IOSWidgetGallerySheet> createState() => _IOSWidgetGallerySheetState();
}

class _IOSWidgetGallerySheetState extends State<IOSWidgetGallerySheet> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isWidgetsExpanded = false;
  late bool _isGrid;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Finance',
    'Tasks',
    'Timeline',
    'Lifestyle',
  ];

  @override
  void initState() {
    super.initState();
    _isGrid = widget.isGrid ?? Provider.of<UserProvider>(context, listen: false).isGrid;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildQuickActionBtn({
    required String label,
    required IconData icon,
    required Color textColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(icon, color: textColor, size: 20),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white60 : Colors.black54);
    final sheetBg = isDark ? const Color(0xFF161618) : const Color(0xFFF2F2F7);

    return Consumer5<NotesProvider, UserProvider, MoneyProvider, TasksProvider, EventsProvider>(
      builder: (context, notesProv, userProv, moneyProv, tasksProv, eventsProv, _) {
        final enabledWidgets = notesProv.getWidgetsForFolder(widget.currentFolder);
        final visibility = userProv.appVisibility;

        bool isWidgetActive(String key) {
          if (widget.isFolderView) {
            return enabledWidgets.contains(key);
          }
          if (key == 'Money') return visibility['Wallet'] == true && enabledWidgets.contains(key);
          if (key == 'Tasks') return visibility['Focus'] == true && enabledWidgets.contains(key);
          if (key == 'Events') return visibility['Events'] == true && enabledWidgets.contains(key);
          if (key == 'SAVINGS_GOAL_WIDGET') return enabledWidgets.contains(key) || visibility['SavingsGoal'] == true;
          if (key == 'SLEEP_ENERGY_WIDGET') return enabledWidgets.contains(key) || visibility['SleepEnergy'] == true;
          if (key == 'EXPENSES_CHART_WIDGET') return enabledWidgets.contains(key);
          if (key == 'TASK_PRIORITY_WIDGET') return enabledWidgets.contains(key);
          return enabledWidgets.contains(key);
        }

        void toggleWidget(String key, [String? title]) {
          final wasActive = isWidgetActive(key);
          notesProv.toggleFolderWidget(widget.currentFolder, key);
          if (!widget.isFolderView) {
            if (key == 'Money') {
              userProv.toggleAppVisibility('Wallet');
            } else if (key == 'Tasks') {
              userProv.toggleAppVisibility('Focus');
            } else if (key == 'Events') {
              userProv.toggleAppVisibility('Events');
            } else if (key == 'SAVINGS_GOAL_WIDGET') {
              userProv.toggleAppVisibility('SavingsGoal');
            } else if (key == 'SLEEP_ENERGY_WIDGET') {
              userProv.toggleAppVisibility('SleepEnergy');
            }
          }
          final isNowActive = !wasActive;
          final displayTitle = title ?? "Widget";
          MinimalistToast.show(
            context,
            message: isNowActive
                ? "Added $displayTitle to Dashboard"
                : "Removed $displayTitle from Dashboard",
            icon: isNowActive
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.minus_circle,
          );
          setState(() {});
        }

        final screenHeight = MediaQuery.of(context).size.height;
        const collapsedHeight = 285.0;
        final expandedHeight = screenHeight * 0.88;
        final currentHeight = _isWidgetsExpanded ? expandedHeight : collapsedHeight;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          height: currentHeight,
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP HANDLE WITH DRAG GESTURE
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (details) {
                      final vel = details.primaryVelocity ?? 0;
                      if (vel < -150 && !_isWidgetsExpanded) {
                        setState(() => _isWidgetsExpanded = true);
                      } else if (vel > 150) {
                        if (_isWidgetsExpanded) {
                          setState(() => _isWidgetsExpanded = false);
                        } else {
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isFolderView ? "Add to ${widget.currentFolder}" : "Quick Add",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.xmark, size: 14, color: textColor.withValues(alpha: 0.7)),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. QUICK ACTION BUTTONS (Note, Task, Savings, Event)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickActionBtn(
                        label: "Note",
                        icon: CupertinoIcons.doc_text,
                        textColor: textColor,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpenNote?.call(widget.currentFolder);
                        },
                      ),
                      _buildQuickActionBtn(
                        label: "Task",
                        icon: CupertinoIcons.check_mark_circled,
                        textColor: textColor,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpenTaskCreator?.call();
                        },
                      ),
                      _buildQuickActionBtn(
                        label: "Savings",
                        icon: CupertinoIcons.archivebox,
                        textColor: textColor,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpenSavings?.call();
                        },
                      ),
                      _buildQuickActionBtn(
                        label: "Event",
                        icon: CupertinoIcons.calendar,
                        textColor: textColor,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onOpenEventCreator?.call();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 3. AI COMMAND & SEARCH BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.search, size: 15, color: dimmedColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search widgets or ask AI...",
                              hintStyle: TextStyle(
                                color: dimmedColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                            style: TextStyle(color: textColor, fontSize: 13),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                                if (_searchQuery.isNotEmpty) {
                                  _isWidgetsExpanded = true;
                                }
                              });
                            },
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                final chatProv = Provider.of<ChatProvider>(context, listen: false);
                                chatProv.sendMessage(
                                  message: val.trim(),
                                  userMemories: userProv.user.aiMemory,
                                  mode: 'Assistant',
                                );
                                Navigator.pop(context);
                                userProv.changeView('ai');
                              }
                            },
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_searchController.text.trim().isNotEmpty) {
                              final chatProv = Provider.of<ChatProvider>(context, listen: false);
                              chatProv.sendMessage(
                                message: _searchController.text.trim(),
                                userMemories: userProv.user.aiMemory,
                                mode: 'Assistant',
                              );
                              Navigator.pop(context);
                              userProv.changeView('ai');
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              CupertinoIcons.arrow_up_circle_fill,
                              size: 20,
                              color: textColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 4. COLLAPSED VIEW: SLEEK SMART WIDGETS ENTRY CARD
                if (!_isWidgetsExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _isWidgetsExpanded = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.square_grid_2x2,
                                size: 15, color: textColor.withValues(alpha: 0.7)),
                            const SizedBox(width: 10),
                            Text(
                              "Smart Widgets",
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "Browse",
                              style: TextStyle(
                                color: dimmedColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(CupertinoIcons.chevron_up, size: 11, color: dimmedColor),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 5. EXPANDED VIEW: SMART WIDGETS GALLERY WITH CATEGORIES AND LIVE PREVIEWS
                if (_isWidgetsExpanded)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxHeight < 120) {
                          return const SizedBox();
                        }
                        return ClipRect(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row with Grid/List toggle and Collapse button
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _isGrid ? CupertinoIcons.square_grid_2x2 : CupertinoIcons.list_bullet,
                                          size: 14,
                                          color: dimmedColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "SMART WIDGETS",
                                          style: TextStyle(
                                            color: dimmedColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        // View mode toggle pill (reflects and switches Grid / List view)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            setState(() => _isGrid = !_isGrid);
                                            userProv.setGrid(_isGrid);
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _isGrid ? CupertinoIcons.square_grid_2x2 : CupertinoIcons.list_bullet,
                                                  size: 12,
                                                  color: dimmedColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _isGrid ? "Grid" : "List",
                                                  style: TextStyle(
                                                    color: dimmedColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => setState(() => _isWidgetsExpanded = false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Collapse",
                                                  style: TextStyle(
                                                    color: dimmedColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Icon(CupertinoIcons.chevron_compact_down, size: 13, color: dimmedColor),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 10),
                        // Category chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() => _selectedCategory = cat),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark ? Colors.white : Colors.black)
                                          : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        color: isSelected
                                            ? (isDark ? Colors.black : Colors.white)
                                            : textColor,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Scrollable widgets list / grid
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragEnd: (details) {
                              final vel = details.primaryVelocity ?? 0;
                              if (vel > 150) {
                                setState(() => _isWidgetsExpanded = false);
                              }
                            },
                            child: _isGrid
                                ? SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                                    child: StaggeredGrid.count(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      children: _buildFilteredWidgetCards(
                                        context,
                                        isGrid: true,
                                        notesProv: notesProv,
                                        userProv: userProv,
                                        moneyProv: moneyProv,
                                        tasksProv: tasksProv,
                                        eventsProv: eventsProv,
                                        isDark: isDark,
                                        textColor: textColor,
                                        dimmedColor: dimmedColor,
                                        isWidgetActive: isWidgetActive,
                                        toggleWidget: toggleWidget,
                                      ).map((card) {
                                        return StaggeredGridTile.fit(
                                          crossAxisCellCount: 1,
                                          child: card,
                                        );
                                      }).toList(),
                                    ),
                                  )
                                : ListView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                                    children: _buildFilteredWidgetCards(
                                      context,
                                      isGrid: false,
                                      notesProv: notesProv,
                                      userProv: userProv,
                                      moneyProv: moneyProv,
                                      tasksProv: tasksProv,
                                      eventsProv: eventsProv,
                                      isDark: isDark,
                                      textColor: textColor,
                                      dimmedColor: dimmedColor,
                                      isWidgetActive: isWidgetActive,
                                      toggleWidget: toggleWidget,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildFilteredWidgetCards(
    BuildContext context, {
    required bool isGrid,
    required NotesProvider notesProv,
    required UserProvider userProv,
    required MoneyProvider moneyProv,
    required TasksProvider tasksProv,
    required EventsProvider eventsProv,
    required bool isDark,
    required Color textColor,
    required Color dimmedColor,
    required bool Function(String) isWidgetActive,
    required void Function(String key, [String? title]) toggleWidget,
  }) {
    final List<Widget> list = [];

    // Helper: matches search and category
    bool shouldShow(String title, String category) {
      final matchesCategory = _selectedCategory == 'All' || _selectedCategory == category;
      final matchesSearch = _searchQuery.isEmpty ||
          title.toLowerCase().contains(_searchQuery) ||
          category.toLowerCase().contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }

    // 1. EXPENSES CHART (Finance)
    if (shouldShow("Expenses Chart", "Finance")) {
      list.add(_buildIOSWidgetCard(
        title: "Expenses Chart",
        category: "Finance",
        icon: CupertinoIcons.chart_bar_alt_fill,
        previewWidget: ExpensesChartWidget(isCompact: isGrid),
        isAdded: isWidgetActive('EXPENSES_CHART_WIDGET'),
        onAdd: () => toggleWidget('EXPENSES_CHART_WIDGET', "Expenses Chart"),
        textColor: textColor,
        dimmedColor: dimmedColor,
        isDark: isDark,
        isGrid: isGrid,
      ));
    }

    // 2. TASK PRIORITY MATRIX (Tasks)
    if (shouldShow("Tasks Priority Matrix", "Tasks")) {
      list.add(_buildIOSWidgetCard(
        title: "Tasks Priority Matrix",
        category: "Tasks",
        icon: CupertinoIcons.checkmark_seal_fill,
        previewWidget: const TaskPriorityWidget(),
        isAdded: isWidgetActive('TASK_PRIORITY_WIDGET'),
        onAdd: () => toggleWidget('TASK_PRIORITY_WIDGET', "Tasks Priority Matrix"),
        textColor: textColor,
        dimmedColor: dimmedColor,
        isDark: isDark,
        isGrid: isGrid,
      ));
    }

    // 3. DAY COUNTER WIDGET (Timeline)
    if (shouldShow("Day Counter", "Timeline")) {
      final hasDayCounters = eventsProv.events.any((e) => e.isDayCounter) ||
          notesProv.notes.any((n) => n.widgetType == 'day_counter');
      final sampleEvent = eventsProv.events.isNotEmpty
          ? eventsProv.events.first
          : Event(
              id: 'demo',
              title: "Next Milestone",
              date: DateTime.now().add(const Duration(days: 14)),
              endTime: DateTime.now().add(const Duration(days: 14, hours: 2)),
              isDayCounter: true,
            );

      list.add(_buildIOSWidgetCard(
        title: "Day Counter",
        category: "Timeline",
        icon: CupertinoIcons.hourglass,
        previewWidget: DayCounterWidget(event: sampleEvent),
        isAdded: isWidgetActive('Events'),
        onAdd: () {
          if (!hasDayCounters) {
            _showAddDayCounterDialog(context, notesProv);
          } else {
            toggleWidget('Events', "Day Counter");
          }
        },
        onCustomAction: () => _showAddDayCounterDialog(context, notesProv),
        customActionLabel: "+ New Counter",
        textColor: textColor,
        dimmedColor: dimmedColor,
        isDark: isDark,
        isGrid: isGrid,
      ));
    }

    // 4. SPENDING SUMMARY (Finance)
    if (shouldShow("Spending Summary", "Finance")) {
      list.add(_buildIOSWidgetCard(
        title: "Spending Summary",
        category: "Finance",
        icon: CupertinoIcons.money_dollar,
        previewWidget: const ExpenseSummaryWidget(),
        isAdded: isWidgetActive('Money'),
        onAdd: () => toggleWidget('Money', "Spending Summary"),
        textColor: textColor,
        dimmedColor: dimmedColor,
        isDark: isDark,
        isGrid: isGrid,
      ));
    }

    // 5. SLEEP & ENERGY READINESS (Lifestyle)
    if (shouldShow("Sleep & Energy", "Lifestyle")) {
      list.add(_buildIOSWidgetCard(
        title: "Sleep & Energy",
        category: "Lifestyle",
        icon: CupertinoIcons.moon_stars_fill,
        previewWidget: const SleepEnergyWidget(),
        isAdded: isWidgetActive('SLEEP_ENERGY_WIDGET'),
        onAdd: () => toggleWidget('SLEEP_ENERGY_WIDGET', "Sleep & Energy"),
        textColor: textColor,
        dimmedColor: dimmedColor,
        isDark: isDark,
        isGrid: isGrid,
      ));
    }

    // 6. SAVINGS GOAL (Finance)
    if (shouldShow("Savings Goal", "Finance")) {
      list.add(_buildIOSWidgetCard(
        title: "Savings Goal",
        category: "Finance",
        icon: CupertinoIcons.archivebox,
        previewWidget: const SavingsGoalWidget(),
        isAdded: isWidgetActive('SAVINGS_GOAL_WIDGET'),
        onAdd: () => toggleWidget('SAVINGS_GOAL_WIDGET', "Savings Goal"),
        textColor: textColor,
        dimmedColor: dimmedColor,
        isDark: isDark,
        isGrid: isGrid,
      ));
    }

    // 7. FOCUS TIMER (Tasks)
    if (shouldShow("Focus Timer", "Tasks")) {
      final timerNote = Note(
        id: 'timer_demo',
        title: "Focus Block",
        content: "25m",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        widgetType: 'timer',
      );

      final Widget pomodoroPreview = isGrid
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222224) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: textColor, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        "25:00",
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Deep Work",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "25m Pomodoro",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: dimmedColor, fontSize: 10),
                  ),
                ],
              ),
            )
          : Container(
              height: 140,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222224) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: textColor, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        "25:00",
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Deep Work Block", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text("Boost focus & productivity", style: TextStyle(color: dimmedColor, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            );

      list.add(_buildIOSWidgetCard(
        title: "Focus Pomodoro",
        category: "Tasks",
        icon: CupertinoIcons.timer,
        previewWidget: pomodoroPreview,
        isAdded: isWidgetActive('timer_demo'),
        onAdd: () {
          notesProv.addNote(timerNote);
          toggleWidget(timerNote.id, "Focus Timer");
        },
        textColor: textColor,
        dimmedColor: dimmedColor,
        isDark: isDark,
        isGrid: isGrid,
      ));
    }

    return list;
  }

  Widget _buildIOSWidgetCard({
    required String title,
    required String category,
    required IconData icon,
    required Widget previewWidget,
    required bool isAdded,
    required VoidCallback onAdd,
    VoidCallback? onCustomAction,
    String? customActionLabel,
    required Color textColor,
    required Color dimmedColor,
    required bool isDark,
    required bool isGrid,
  }) {
    if (isGrid) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Compact for Grid)
            Row(
              children: [
                Icon(icon, size: 13, color: textColor),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAdd,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAdded
                          ? (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06))
                          : (isDark ? Colors.white : Colors.black),
                      borderRadius: BorderRadius.circular(12),
                      border: isAdded
                          ? Border.all(color: isDark ? Colors.white24 : Colors.black12)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAdded ? CupertinoIcons.checkmark : CupertinoIcons.add,
                          size: 11,
                          color: isAdded ? textColor : (isDark ? Colors.black : Colors.white),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isAdded ? "Added" : "Add",
                          style: TextStyle(
                            color: isAdded ? textColor : (isDark ? Colors.black : Colors.white),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (onCustomAction != null && customActionLabel != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCustomAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    customActionLabel,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Interactive Preview Frame (Fitted in Grid cell)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: IgnorePointer(
                ignoring: true,
                child: previewWidget,
              ),
            ),
          ],
        ),
      );
    }

    // List mode (wide)
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (onCustomAction != null && customActionLabel != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onCustomAction,
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          customActionLabel,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAdd,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAdded
                            ? (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06))
                            : (isDark ? Colors.white : Colors.black),
                        borderRadius: BorderRadius.circular(20),
                        border: isAdded
                            ? Border.all(color: isDark ? Colors.white24 : Colors.black12)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAdded ? CupertinoIcons.checkmark : CupertinoIcons.add,
                            size: 13,
                            color: isAdded ? textColor : (isDark ? Colors.black : Colors.white),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAdded ? "Added" : "Add Widget",
                            style: TextStyle(
                              color: isAdded ? textColor : (isDark ? Colors.black : Colors.white),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Interactive Preview Frame
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: IgnorePointer(
              ignoring: true, // Preview only in gallery
              child: previewWidget,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDayCounterDialog(BuildContext context, NotesProvider notesProv) {
    final titleCtrl = TextEditingController(text: "Special Day");
    DateTime pickedDate = DateTime.now().add(const Duration(days: 30));
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "New Day Counter",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(hintText: "Title (e.g. Vacation, Streak, Goal)"),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(CupertinoIcons.calendar),
                title: Text(
                  DateFormat('MMMM d, yyyy').format(pickedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final res = await showDatePicker(
                      context: context,
                      initialDate: pickedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (res != null) {
                      setDialogState(() => pickedDate = res);
                    }
                  },
                  child: const Text("Change Date"),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: theme.cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final title = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : "Day Counter";
                final newNote = Note(
                  id: const Uuid().v4(),
                  title: title,
                  content: DateFormat('yyyy-MM-dd').format(pickedDate),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  folder: widget.currentFolder != 'All' ? widget.currentFolder : 'General',
                  widgetType: 'day_counter',
                );
                notesProv.addNote(newNote);
                notesProv.toggleFolderWidget(widget.currentFolder, newNote.id);
                Navigator.pop(dialogCtx);
                MinimalistToast.show(
                  context,
                  message: "Added Day Counter '$title' to Dashboard",
                  icon: CupertinoIcons.checkmark_circle_fill,
                );
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }
}
