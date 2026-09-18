import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../providers/tasks_provider.dart';
import '../../providers/notes_provider.dart';
import '../../models/task_model.dart';
import '../../models/note_model.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../services/notification_service.dart';
import '../notes/note_editor_screen.dart';
import '../../widgets/common/minimalist_toast.dart';

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({super.key});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  final TextEditingController _brainDumpController = TextEditingController();
  int _selectedInputPriority =
      0; // 0=None, 1=Orange, 2=Red, 3=Gold, 4=Green, 5=Blue, 6=Purple
  bool _showColorPopup = false;
  int?
      _activePriorityFilter; // null = ALL, or 0..6 for specific color priority filter

  Color _getPriorityAccentColor(int priority, bool isDark) {
    switch (priority) {
      case 1:
        return const Color(0xFFFF9800); // Orange
      case 2:
        return const Color(0xFFEF5350); // Red
      case 3:
        return const Color(0xFFFFD54F); // Gold/Yellow
      case 4:
        return const Color(0xFF66BB6A); // Green
      case 5:
        return const Color(0xFF42A5F5); // Blue
      case 6:
        return const Color(0xFFAB47BC); // Purple
      default:
        return isDark ? Colors.white70 : Colors.black45;
    }
  }

  String _getPriorityName(int priority) {
    switch (priority) {
      case 1:
        return "Orange";
      case 2:
        return "Red";
      case 3:
        return "Gold";
      case 4:
        return "Green";
      case 5:
        return "Blue";
      case 6:
        return "Purple";
      default:
        return "Default";
    }
  }

  void _handleBrainDump(String text, TasksProvider provider) {
    if (text.trim().isEmpty) return;
    final List<String> taskTitles = text.split(',');
    for (var title in taskTitles) {
      if (title.trim().isNotEmpty) {
        provider.addTask(Task(
          id: const Uuid().v4(),
          title: title.trim(),
          isDone: false,
          createdAt: DateTime.now(),
          priority: _selectedInputPriority,
        ));
      }
    }
    _brainDumpController.clear();
    setState(() {
      _showColorPopup = false;
    });
  }

  Widget _buildInsColorPopup(BuildContext context, bool isDark) {
    final priorityColors = [
      {
        'priority': 0,
        'color': isDark ? Colors.grey[700]! : Colors.grey[400]!,
        'label': 'None'
      },
      {'priority': 1, 'color': const Color(0xFFFF9800), 'label': 'Orange'},
      {'priority': 2, 'color': const Color(0xFFEF5350), 'label': 'Red'},
      {'priority': 3, 'color': const Color(0xFFFFD54F), 'label': 'Gold'},
      {'priority': 4, 'color': const Color(0xFF66BB6A), 'label': 'Green'},
      {'priority': 5, 'color': const Color(0xFF42A5F5), 'label': 'Blue'},
      {'priority': 6, 'color': const Color(0xFFAB47BC), 'label': 'Purple'},
    ];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _showColorPopup ? 1.0 : 0.0,
      curve: Curves.easeOut,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: _showColorPopup ? 1.0 : 0.85,
        curve: Curves.easeOutBack,
        child: IgnorePointer(
          ignoring: !_showColorPopup,
          child: GlassContainer(
            height: 56,
            borderRadius: 28,
            blur: 25,
            opacity: isDark ? 0.22 : 0.18,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: priorityColors.map((item) {
                final prio = item['priority'] as int;
                final color = item['color'] as Color;
                final isSelected = _selectedInputPriority == prio;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedInputPriority = prio;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: isSelected ? 34 : 26,
                    height: isSelected ? 34 : 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: isSelected ? 2.5 : 0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(isSelected ? 0.6 : 0.2),
                          blurRadius: isSelected ? 12 : 4,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                      ],
                    ),
                    child: isSelected
                        ? Center(
                            child: Icon(
                              prio == 0 ? Icons.close : Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityFilterBar(BuildContext context, List<Task> allTasks,
      bool isDark, Color textColor, Color secondaryTextColor) {
    final filterItems = [
      {'priority': null, 'label': 'ALL', 'color': textColor},
      {'priority': 0, 'label': 'Neutral', 'color': secondaryTextColor},
      {'priority': 1, 'label': 'Orange', 'color': const Color(0xFFFF9800)},
      {'priority': 2, 'label': 'Red', 'color': const Color(0xFFEF5350)},
      {'priority': 3, 'label': 'Gold', 'color': const Color(0xFFFFD54F)},
      {'priority': 4, 'label': 'Green', 'color': const Color(0xFF66BB6A)},
      {'priority': 5, 'label': 'Blue', 'color': const Color(0xFF42A5F5)},
      {'priority': 6, 'label': 'Purple', 'color': const Color(0xFFAB47BC)},
    ];

    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filterItems.length,
        itemBuilder: (ctx, index) {
          final item = filterItems[index];
          final prio = item['priority'] as int?;
          final color = item['color'] as Color;
          final label = item['label'] as String;
          final isSelected = _activePriorityFilter == prio;

          final count = prio == null
              ? allTasks.where((t) => !t.isDone).length
              : allTasks.where((t) => t.priority == prio && !t.isDone).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activePriorityFilter = prio;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected
                      ? color.withOpacity(0.2)
                      : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05)),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (prio != null)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? textColor : secondaryTextColor,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.8)
                              : secondaryTextColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "$count",
                          style: TextStyle(
                            color: isSelected ? Colors.white : textColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksProvider = Provider.of<TasksProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final tasks = tasksProvider.tasks;
    final filteredTasks = _activePriorityFilter == null
        ? tasks
        : tasks.where((t) => t.priority == _activePriorityFilter).toList();

    final activeTasks = filteredTasks.where((t) => !t.isDone).toList();
    final doneTasks = filteredTasks.where((t) => t.isDone).toList();

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final inputBottom = (isLandscape ? 60.0 : 110.0) + bottomInset;
    final popupBottom = inputBottom + 68.0;

    return LifeAppScaffold(
      title: "TASKS",
      child: GestureDetector(
        onTap: () {
          if (_showColorPopup) {
            setState(() {
              _showColorPopup = false;
            });
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  _buildPriorityFilterBar(
                      context, tasks, isDark, textColor, secondaryTextColor),
                  Expanded(
                    child: activeTasks.isEmpty && doneTasks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.checkmark_seal,
                                    size: 48,
                                    color: secondaryTextColor.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  _activePriorityFilter == null
                                      ? "No tasks yet"
                                      : "No tasks for this color priority",
                                  style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        : ReorderableListView(
                            buildDefaultDragHandles: false,
                            padding: EdgeInsets.fromLTRB(20, 10, 20,
                                (isLandscape ? 120.0 : 160.0) + bottomInset),
                            onReorder: (oldIndex, newIndex) =>
                                tasksProvider.reorderTasks(oldIndex, newIndex),
                            children: [
                              for (int i = 0; i < activeTasks.length; i++)
                                _buildModernTaskCard(
                                    context,
                                    activeTasks[i],
                                    tasksProvider,
                                    i,
                                    ValueKey("${activeTasks[i].id}_active")),
                              if (doneTasks.isNotEmpty)
                                Padding(
                                  key: const ValueKey('divider'),
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 30, 10, 10),
                                  child: Row(
                                    children: [
                                      Text("COMPLETED",
                                          style: TextStyle(
                                              color: secondaryTextColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Container(
                                              height: 1,
                                              color: theme.dividerColor)),
                                    ],
                                  ),
                                ),
                              for (int i = 0; i < doneTasks.length; i++)
                                _buildModernTaskCard(
                                    context,
                                    doneTasks[i],
                                    tasksProvider,
                                    i + activeTasks.length,
                                    ValueKey("${doneTasks[i].id}_done")),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            // Instagram-Style Minimalist Color Option Popup
            Positioned(
              bottom: popupBottom,
              left: 20,
              right: 20,
              child: _buildInsColorPopup(context, isDark),
            ),
            // Floating Input Container with Color Option Picker Button
            Positioned(
              bottom: inputBottom,
              left: 20,
              right: 20,
              child: GlassContainer(
                height: 60,
                borderRadius: 30,
                blur: 20,
                opacity: isDark ? 0.15 : 0.12,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ins Style Color Option Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showColorPopup = !_showColorPopup;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(left: 6, right: 6),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getPriorityAccentColor(
                                  _selectedInputPriority, isDark)
                              .withOpacity(0.15),
                          border: Border.all(
                            color: _selectedInputPriority == 0
                                ? secondaryTextColor.withOpacity(0.3)
                                : _getPriorityAccentColor(
                                    _selectedInputPriority, isDark),
                            width: _selectedInputPriority == 0 ? 1.5 : 2.5,
                          ),
                          boxShadow: _selectedInputPriority != 0
                              ? [
                                  BoxShadow(
                                    color: _getPriorityAccentColor(
                                            _selectedInputPriority, isDark)
                                        .withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: _selectedInputPriority == 0
                              ? Icon(
                                  Icons.palette,
                                  size: 18,
                                  color: secondaryTextColor,
                                )
                              : Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getPriorityAccentColor(
                                        _selectedInputPriority, isDark),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _brainDumpController,
                        style: TextStyle(color: textColor),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: _selectedInputPriority == 0
                              ? "New task..."
                              : "New task (${_getPriorityName(_selectedInputPriority)} priority)...",
                          hintStyle: TextStyle(
                            color: _selectedInputPriority == 0
                                ? secondaryTextColor
                                : _getPriorityAccentColor(
                                        _selectedInputPriority, isDark)
                                    .withOpacity(0.7),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          isDense: true,
                        ),
                        onSubmitted: (value) =>
                            _handleBrainDump(value, tasksProvider),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: _selectedInputPriority == 0
                            ? textColor
                            : _getPriorityAccentColor(
                                _selectedInputPriority, isDark),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_upward,
                            color: theme.scaffoldBackgroundColor),
                        onPressed: () => _handleBrainDump(
                            _brainDumpController.text, tasksProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTaskCard(BuildContext context, Task task,
      TasksProvider provider, int index, Key key) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    Color cardColor;
    Color contentColor = textColor;
    Color iconColor = secondaryTextColor;

    if (isDark) {
      cardColor = theme.cardColor;
      contentColor = Colors.white;

      switch (task.priority) {
        case 1:
          iconColor = const Color(0xFFFF9800);
          break; // Orange
        case 2:
          iconColor = const Color(0xFFEF5350);
          break; // Red
        case 3:
          iconColor = const Color(0xFFFFD54F);
          break; // Amber
        case 4:
          iconColor = const Color(0xFF66BB6A);
          break; // Green
        case 5:
          iconColor = const Color(0xFF42A5F5);
          break; // Blue
        case 6:
          iconColor = const Color(0xFFAB47BC);
          break; // Purple
        default:
          iconColor = secondaryTextColor;
      }
    } else {
      switch (task.priority) {
        case 1:
          cardColor = const Color(0xFFFFE0B2);
          break; // Orange 100
        case 2:
          cardColor = const Color(0xFFFFCDD2);
          break; // Red 100
        case 3:
          cardColor = const Color(0xFFFFF9C4);
          break; // Yellow 100
        case 4:
          cardColor = const Color(0xFFC8E6C9);
          break; // Green 100
        case 5:
          cardColor = const Color(0xFFBBDEFB);
          break; // Blue 100
        case 6:
          cardColor = const Color(0xFFE1BEE7);
          break; // Purple 100
        default:
          cardColor = Colors.black.withOpacity(0.08);
      }
    }

    if (task.isDone) {
      cardColor = isDark
          ? Colors.white.withOpacity(0.02)
          : Colors.black.withOpacity(0.02);
      contentColor = secondaryTextColor;
      iconColor = secondaryTextColor.withOpacity(0.5);
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Slidable(
          key: Key(task.id),
          // A right swipe on an active task is the quick-complete gesture.
          // Keep completed tasks from being accidentally reactivated by a swipe;
          // their checkbox remains available for that action.
          startActionPane: task.isDone
              ? null
              : ActionPane(
                  motion: const StretchMotion(),
                  extentRatio: 0.35,
                  dismissible: DismissiblePane(
                    dismissThreshold: 0.2,
                    onDismissed: () => provider.toggleTask(task.id),
                  ),
                  children: [
                    CustomSlidableAction(
                      onPressed: (_) => provider.toggleTask(task.id),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.check, size: 28),
                    ),
                  ],
                ),
          endActionPane: task.isDone
              ? null
              : ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.85,
                  children: [
                    _buildSeamlessAction(
                        icon: CupertinoIcons.pencil,
                        bgColor: cardColor,
                        iconColor: iconColor,
                        onTap: () => _showEditDialog(context, task, provider)),
                    _buildSeamlessAction(
                        icon: CupertinoIcons.time,
                        bgColor: cardColor,
                        iconColor: iconColor,
                        onTap: () => _showGlassTimePicker(context, task)),
                    _buildSeamlessAction(
                        icon: CupertinoIcons.paintbrush,
                        bgColor: cardColor,
                        iconColor: iconColor,
                        onTap: () => _showColorPicker(context, task, provider)),
                    _buildSeamlessAction(
                        icon: CupertinoIcons.doc_text,
                        bgColor: cardColor,
                        iconColor: iconColor,
                        onTap: () =>
                            _showNoteAttachmentPicker(context, task, provider)),
                    _buildSeamlessAction(
                        icon: CupertinoIcons.trash,
                        bgColor: cardColor,
                        iconColor: Colors.redAccent,
                        onTap: () {
                          provider.deleteTask(task.id);
                          MinimalistToast.showUndo(
                            context,
                            title: task.title.isNotEmpty ? task.title : "Task",
                            onUndo: () => provider.restoreTask(task),
                          );
                        }),
                  ],
                ),
          child: Container(
            color: cardColor,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.only(left: 16, right: 10, top: 4, bottom: 4),
              leading: GestureDetector(
                onTap: () => provider.toggleTask(task.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isDone
                        ? contentColor.withOpacity(0.2)
                        : Colors.transparent,
                    border: Border.all(
                        color: task.isDone ? Colors.transparent : iconColor,
                        width: 2),
                  ),
                  child: task.isDone
                      ? Icon(Icons.check, size: 14, color: contentColor)
                      : null,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: contentColor,
                      decoration:
                          task.isDone ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  if (task.note != null && task.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.paperclip,
                              size: 12, color: iconColor),
                          const SizedBox(width: 4),
                          Text("Note Attached",
                              style: TextStyle(
                                  color: iconColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                ],
              ),
              trailing: ReorderableDragStartListener(
                index: index,
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle, color: iconColor, size: 22),
                ),
              ),
              onTap: () {
                if (task.note != null && task.note!.isNotEmpty) {
                  _showActionChoiceDialog(context, task, provider);
                } else {
                  _showEditDialog(context, task, provider);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeamlessAction(
      {required IconData icon,
      required Color bgColor,
      required Color iconColor,
      required VoidCallback onTap}) {
    final toolColor = Color.alphaBlend(Colors.black.withOpacity(0.05), bgColor);
    return CustomSlidableAction(
      onPressed: (_) => onTap(),
      backgroundColor: toolColor,
      foregroundColor: iconColor,
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.zero,
      child: Icon(icon, size: 22),
    );
  }

  void _showEditDialog(
      BuildContext context, Task task, TasksProvider provider) {
    final titleCtrl = TextEditingController(text: task.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
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
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Edit Task",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                if (task.note != null && task.note!.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      provider.updateTask(task.copyWith(note: ""));
                      Navigator.pop(ctx);
                      _showEditDialog(
                          context, task.copyWith(note: ""), provider);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Row(children: [
                        Icon(CupertinoIcons.trash,
                            size: 14, color: Colors.redAccent),
                        SizedBox(width: 5),
                        Text("Remove Note",
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold))
                      ]),
                    ),
                  )
              ]),
              const SizedBox(height: 25),
              CupertinoTextField(
                controller: titleCtrl,
                placeholder: "Task title",
                placeholderStyle: TextStyle(color: secondaryTextColor),
                style: TextStyle(color: textColor),
                decoration: BoxDecoration(
                    color: inputBg, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(16),
              ),
              if (task.note != null && task.note!.isNotEmpty) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: inputBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.doc_text, color: textColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text("Attached: ${task.note}",
                              style: TextStyle(color: textColor, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: inputBg,
                      borderRadius: BorderRadius.circular(15),
                      child: Icon(CupertinoIcons.doc_text, color: textColor),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showNoteAttachmentPicker(context, task, provider);
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 3,
                    child: CupertinoButton(
                      color: textColor,
                      borderRadius: BorderRadius.circular(15),
                      child: Text("Save",
                          style: TextStyle(
                              color: theme.scaffoldBackgroundColor,
                              fontWeight: FontWeight.bold)),
                      onPressed: () {
                        provider
                            .updateTask(task.copyWith(title: titleCtrl.text));
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  void _showColorPicker(
      BuildContext context, Task task, TasksProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(30),
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
              Text("PRIORITY COLOR",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _colorDot(
                      ctx,
                      0,
                      isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      task,
                      provider),
                  _colorDot(
                      ctx,
                      1,
                      isDark
                          ? const Color(0xFF983301)
                          : const Color(0xFFFFF3E0),
                      task,
                      provider),
                  _colorDot(
                      ctx,
                      2,
                      isDark
                          ? const Color(0xFF8a1c1c)
                          : const Color(0xFFFFEBEE),
                      task,
                      provider),
                  _colorDot(
                      ctx,
                      3,
                      isDark
                          ? const Color(0xFF997b19)
                          : const Color(0xFFFFFDE7),
                      task,
                      provider),
                  _colorDot(
                      ctx,
                      4,
                      isDark
                          ? const Color(0xFF206126)
                          : const Color(0xFFE8F5E9),
                      task,
                      provider),
                  _colorDot(
                      ctx,
                      5,
                      isDark
                          ? const Color(0xFF1a3b80)
                          : const Color(0xFFE3F2FD),
                      task,
                      provider),
                  _colorDot(
                      ctx,
                      6,
                      isDark
                          ? const Color(0xFF5e1a80)
                          : const Color(0xFFF3E5F5),
                      task,
                      provider),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _colorDot(BuildContext ctx, int priority, Color color, Task task,
      TasksProvider provider) {
    final bool isSelected = task.priority == priority;
    final textColor = Theme.of(ctx).textTheme.bodyLarge?.color ?? Colors.black;
    return GestureDetector(
      onTap: () {
        provider.updateTask(task.copyWith(priority: priority));
        Navigator.pop(ctx);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
                color: isSelected ? textColor : Colors.grey.withOpacity(0.3),
                width: isSelected ? 3 : 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
            ]),
        child: isSelected
            ? Center(child: Icon(Icons.check, size: 20, color: textColor))
            : null,
      ),
    );
  }

  void _showNoteAttachmentPicker(
      BuildContext context, Task task, TasksProvider taskProvider) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor =
            theme.textTheme.bodyMedium?.color ?? Colors.grey;

        return Container(
          height: 500,
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 25),
              Text("ATTACH NOTE",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  final newNote = Note(
                      id: const Uuid().v4(),
                      title: "Note: ${task.title}",
                      content: "",
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now());
                  notesProvider.addNote(newNote);
                  taskProvider.updateTask(task.copyWith(note: newNote.title));
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NoteEditorScreen(note: newNote)));
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: textColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.add, color: textColor, size: 20),
                      const SizedBox(width: 10),
                      Text("Create New Note",
                          style: TextStyle(
                              color: textColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: notesProvider.notes.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: theme.dividerColor),
                  itemBuilder: (context, i) {
                    final note = notesProvider.notes[i];
                    return ListTile(
                      title: Text(note.title,
                          style: TextStyle(
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w600)),
                      leading: Icon(CupertinoIcons.doc_text,
                          color: secondaryTextColor, size: 20),
                      onTap: () {
                        taskProvider
                            .updateTask(task.copyWith(note: note.title));
                        Navigator.pop(ctx);
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

  void _showGlassTimePicker(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

        return Container(
          height: 350,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("Cancel",
                        style: TextStyle(color: textColor.withOpacity(0.5)))),
                Text("REMINDER",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("Done",
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.bold))),
              ]),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(brightness: theme.brightness),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    onDateTimeChanged: (DateTime newTime) {
                      final now = DateTime.now();
                      final scheduleTime = DateTime(now.year, now.month,
                          now.day, newTime.hour, newTime.minute);
                      if (scheduleTime.isAfter(now)) {
                        NotificationService.scheduleNotification(
                            id: task.hashCode,
                            title: "Reminder: ${task.title}",
                            body: "It's time!",
                            scheduledTime: scheduleTime);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showActionChoiceDialog(
      BuildContext context, Task task, TasksProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color;

        return Container(
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
              Text(task.title.toUpperCase(),
                  style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 25),
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: textColor!.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(CupertinoIcons.doc_text,
                        color: textColor, size: 20)),
                title: Text("Open Attached Note",
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAttachedNote(context, task.note!);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(CupertinoIcons.pencil,
                        color: textColor, size: 20)),
                title: Text("Edit Task Details",
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDialog(context, task, provider);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAttachedNote(BuildContext context, String noteTitle) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    try {
      final note = notesProvider.notes.firstWhere((n) => n.title == noteTitle);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Note not found (it might have been deleted)")));
    }
  }
}
