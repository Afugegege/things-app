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

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({super.key});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  final TextEditingController _brainDumpController = TextEditingController();

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
          priority: 0, 
        ));
      }
    }
    _brainDumpController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tasksProvider = Provider.of<TasksProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final tasks = tasksProvider.tasks; 
    
    final activeTasks = tasks.where((t) => !t.isDone).toList();
    final doneTasks = tasks.where((t) => t.isDone).toList();
    
    return LifeAppScaffold(
      title: "TASKS",
      child: Stack(
        children: [
          Positioned.fill(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 200),
              onReorder: (oldIndex, newIndex) => tasksProvider.reorderTasks(oldIndex, newIndex),
              children: [
                for (int i = 0; i < activeTasks.length; i++)
                  _buildModernTaskCard(context, activeTasks[i], tasksProvider, i, ValueKey("${activeTasks[i].id}_active")),

                if (doneTasks.isNotEmpty)
                  Padding(
                    key: const ValueKey('divider'),
                    padding: const EdgeInsets.fromLTRB(10, 30, 10, 10),
                    child: Row(
                      children: [
                        Text("COMPLETED", style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(width: 10),
                        Expanded(child: Container(height: 1, color: theme.dividerColor)),
                      ],
                    ),
                  ),

                for (int i = 0; i < doneTasks.length; i++)
                  _buildModernTaskCard(context, doneTasks[i], tasksProvider, i + activeTasks.length, ValueKey("${doneTasks[i].id}_done")),
              ],
            ),
          ),

          Positioned(
            bottom: 125, 
            left: 20,
            right: 20,
            child: GlassContainer(
              height: 60,
              borderRadius: 30,
              blur: 20,
              opacity: isDark ? 0.15 : 0.05, 
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brainDumpController,
                      style: TextStyle(color: textColor),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: "New task...",
                        hintStyle: TextStyle(color: secondaryTextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        isDense: true,
                      ),
                      onSubmitted: (value) => _handleBrainDump(value, tasksProvider),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(color: textColor, shape: BoxShape.circle), 
                    child: IconButton(
                      icon: Icon(Icons.arrow_upward, color: theme.scaffoldBackgroundColor),
                      onPressed: () => _handleBrainDump(_brainDumpController.text, tasksProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTaskCard(BuildContext context, Task task, TasksProvider provider, int index, Key key) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    Color cardColor;
    Color contentColor = textColor;
    Color iconColor = secondaryTextColor;

    if (isDark) {
      switch (task.priority) {
        case 1: cardColor = const Color(0xFF983301); contentColor = Colors.white; break; 
        case 2: cardColor = const Color(0xFF8a1c1c); contentColor = Colors.white; break; 
        case 3: cardColor = const Color(0xFF997b19); contentColor = Colors.white; break; 
        case 4: cardColor = const Color(0xFF206126); contentColor = Colors.white; break; 
        case 5: cardColor = const Color(0xFF1a3b80); contentColor = Colors.white; break; 
        case 6: cardColor = const Color(0xFF5e1a80); contentColor = Colors.white; break; 
        default: cardColor = Colors.white.withOpacity(0.05); 
      }
    } else {
      switch (task.priority) {
        case 1: cardColor = const Color(0xFFFFF3E0); break; 
        case 2: cardColor = const Color(0xFFFFEBEE); break; 
        case 3: cardColor = const Color(0xFFFFFDE7); break; 
        case 4: cardColor = const Color(0xFFE8F5E9); break; 
        case 5: cardColor = const Color(0xFFE3F2FD); break; 
        case 6: cardColor = const Color(0xFFF3E5F5); break; 
        default: cardColor = Colors.black.withOpacity(0.05); 
      }
    }

    if (task.isDone) {
      cardColor = isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02);
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
          startActionPane: ActionPane(
            motion: const StretchMotion(),
            dismissible: DismissiblePane(onDismissed: () {
              provider.toggleTask(task.id);
            }),
            extentRatio: 0.35, // how much swipe is needed
            children: [
              CustomSlidableAction(
                onPressed: (_) {
                  // fallback if user taps
                  provider.toggleTask(task.id);
                },
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                child: const Icon(Icons.check, size: 28),
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.85, 
            children: [
              _buildSeamlessAction(icon: CupertinoIcons.pencil, bgColor: cardColor, iconColor: iconColor, onTap: () => _showEditDialog(context, task, provider)),
              _buildSeamlessAction(icon: CupertinoIcons.time, bgColor: cardColor, iconColor: iconColor, onTap: () => _showGlassTimePicker(context, task)),
              _buildSeamlessAction(icon: CupertinoIcons.paintbrush, bgColor: cardColor, iconColor: iconColor, onTap: () => _showColorPicker(context, task, provider)),
              _buildSeamlessAction(icon: CupertinoIcons.doc_text, bgColor: cardColor, iconColor: iconColor, onTap: () => _showNoteAttachmentPicker(context, task, provider)),
              _buildSeamlessAction(icon: CupertinoIcons.trash, bgColor: cardColor, iconColor: Colors.redAccent, onTap: () => provider.deleteTask(task.id)),
            ],
          ),
          child: Container(
            color: cardColor, 
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 16, right: 10, top: 4, bottom: 4),
              leading: GestureDetector(
                onTap: () => provider.toggleTask(task.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isDone ? contentColor.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(color: task.isDone ? Colors.transparent : iconColor, width: 2),
                  ),
                  child: task.isDone ? Icon(Icons.check, size: 14, color: contentColor) : null,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: contentColor,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  if (task.note != null && task.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.paperclip, size: 12, color: iconColor),
                          const SizedBox(width: 4),
                          Text("Note Attached", style: TextStyle(color: iconColor, fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget _buildSeamlessAction({required IconData icon, required Color bgColor, required Color iconColor, required VoidCallback onTap}) {
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

  void _showEditDialog(BuildContext context, Task task, TasksProvider provider) {
    final titleCtrl = TextEditingController(text: task.title);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
        final isDark = theme.brightness == Brightness.dark;
        final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 40, top: 20, left: 25, right: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Text("Edit Task", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                 if (task.note != null && task.note!.isNotEmpty)
                   GestureDetector(
                     onTap: () {
                       provider.updateTask(task.copyWith(note: ""));
                       Navigator.pop(ctx);
                       _showEditDialog(context, task.copyWith(note: ""), provider);
                     },
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                       decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                       child: Row(children: [
                         const Icon(CupertinoIcons.trash, size: 14, color: Colors.redAccent),
                         const SizedBox(width: 5),
                         const Text("Remove Note", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))
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
                decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(16),
              ),
              
              if (task.note != null && task.note!.isNotEmpty) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.doc_text, color: textColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text("Attached: ${task.note}", style: TextStyle(color: textColor, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                      child: Text("Save", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        provider.updateTask(task.copyWith(title: titleCtrl.text));
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

  void _showColorPicker(BuildContext context, Task task, TasksProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 25),
              Text("PRIORITY COLOR", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _colorDot(ctx, 0, isDark ? const Color(0xFF1C1C1E) : Colors.white, task, provider),
                  _colorDot(ctx, 1, isDark ? const Color(0xFF983301) : const Color(0xFFFFF3E0), task, provider),
                  _colorDot(ctx, 2, isDark ? const Color(0xFF8a1c1c) : const Color(0xFFFFEBEE), task, provider),
                  _colorDot(ctx, 3, isDark ? const Color(0xFF997b19) : const Color(0xFFFFFDE7), task, provider),
                  _colorDot(ctx, 4, isDark ? const Color(0xFF206126) : const Color(0xFFE8F5E9), task, provider),
                  _colorDot(ctx, 5, isDark ? const Color(0xFF1a3b80) : const Color(0xFFE3F2FD), task, provider),
                  _colorDot(ctx, 6, isDark ? const Color(0xFF5e1a80) : const Color(0xFFF3E5F5), task, provider),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
    
  Widget _colorDot(BuildContext ctx, int priority, Color color, Task task, TasksProvider provider) {
    final bool isSelected = task.priority == priority;
    return GestureDetector(
      onTap: () {
        provider.updateTask(task.copyWith(priority: priority));
        Navigator.pop(ctx);
      },
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color, 
          shape: BoxShape.circle, 
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey.withOpacity(0.3), width: isSelected ? 3 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]
        ),
        child: isSelected ? const Center(child: Icon(Icons.check, size: 20, color: Colors.blueAccent)) : null,
      ),
    );
  }

  void _showNoteAttachmentPicker(BuildContext context, Task task, TasksProvider taskProvider) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

        return Container(
          height: 500,
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 25),
              Text("ATTACH NOTE", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 20),
              
              GestureDetector(
                onTap: () {
                   Navigator.pop(ctx);
                   final newNote = Note(id: const Uuid().v4(), title: "Note: ${task.title}", content: "", createdAt: DateTime.now(), updatedAt: DateTime.now());
                   notesProvider.addNote(newNote); 
                   taskProvider.updateTask(task.copyWith(note: newNote.title));
                   Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: newNote)));
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.add, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 10),
                      Text("Create New Note", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: notesProvider.notes.length,
                  separatorBuilder: (_, __) => Divider(color: theme.dividerColor),
                  itemBuilder: (context, i) {
                    final note = notesProvider.notes[i];
                    return ListTile(
                      title: Text(note.title, style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w600)),
                      leading: Icon(CupertinoIcons.doc_text, color: secondaryTextColor, size: 20),
                      onTap: () {
                        taskProvider.updateTask(task.copyWith(note: note.title));
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

        return Container(
          height: 350,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: textColor.withOpacity(0.5)))),
                  Text("REMINDER", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Done", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                ]
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(brightness: theme.brightness),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    onDateTimeChanged: (DateTime newTime) {
                        final now = DateTime.now();
                        final scheduleTime = DateTime(now.year, now.month, now.day, newTime.hour, newTime.minute);
                        if (scheduleTime.isAfter(now)) {
                          NotificationService.scheduleNotification(id: task.hashCode, title: "Reminder: ${task.title}", body: "It's time!", scheduledTime: scheduleTime);
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

  void _showActionChoiceDialog(BuildContext context, Task task, TasksProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color;
        
        return Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 25),
              Text(task.title.toUpperCase(), style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 25),
              
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(CupertinoIcons.doc_text, color: Colors.blueAccent, size: 20)),
                title: Text("Open Attached Note", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAttachedNote(context, task.note!);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(CupertinoIcons.pencil, color: textColor, size: 20)),
                title: Text("Edit Task Details", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
      Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Note not found (it might have been deleted)")));
    }
  }
}