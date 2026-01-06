import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; 

import '../../providers/tasks_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/notes_provider.dart';
import '../../models/task_model.dart';
import '../../models/note_model.dart';
import '../../widgets/glass_container.dart'; 
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
    final userProvider = Provider.of<UserProvider>(context);
    final tasks = tasksProvider.tasks; 
    
    // LOGIC: Done tasks automatically move to the bottom
    final activeTasks = tasks.where((t) => !t.isDone).toList();
    final doneTasks = tasks.where((t) => t.isDone).toList();
    
    final bool onFire = userProvider.currentStreak > 2;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        title: onFire 
          ? const Row(children: [
              Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text("Streak Active 🔥", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ])
          : const Text("Tasks", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // 1. THE TASK LIST
          Positioned.fill(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 200),
              onReorder: (oldIndex, newIndex) => tasksProvider.reorderTasks(oldIndex, newIndex),
              children: [
                // ACTIVE TASKS
                for (int i = 0; i < activeTasks.length; i++)
                  _buildModernTaskCard(context, activeTasks[i], tasksProvider, i, Key(activeTasks[i].id)),

                // DONE DIVIDER
                if (doneTasks.isNotEmpty)
                  Padding(
                    key: const ValueKey('divider'),
                    padding: const EdgeInsets.fromLTRB(10, 30, 10, 10),
                    child: Row(
                      children: [
                        const Text("COMPLETED", style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(width: 10),
                        Expanded(child: Container(height: 1, color: Colors.white10)),
                      ],
                    ),
                  ),

                // DONE TASKS
                for (int i = 0; i < doneTasks.length; i++)
                  _buildModernTaskCard(context, doneTasks[i], tasksProvider, i + activeTasks.length, Key(doneTasks[i].id)),
              ],
            ),
          ),

          // 2. THE INPUT BAR
          Positioned(
            bottom: 110, 
            left: 20,
            right: 20,
            child: GlassContainer(
              height: 60,
              borderRadius: 30,
              blur: 20,
              opacity: 0.15,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brainDumpController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "New task...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (value) => _handleBrainDump(value, tasksProvider),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.black),
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
    // 1. DARKER COLOR PALETTE
    Color cardColor;
    Color textColor = Colors.white; 
    Color iconColor = Colors.white70;

    switch (task.priority) {
      case 1: cardColor = const Color(0xFF983301); break; // Dark Orange
      case 2: cardColor = const Color(0xFF8a1c1c); break; // Dark Red
      case 3: cardColor = const Color(0xFF997b19); break; // Dark Yellow
      case 4: cardColor = const Color(0xFF206126); break; // Dark Green
      case 5: cardColor = const Color(0xFF1a3b80); break; // Dark Blue
      case 6: cardColor = const Color(0xFF5e1a80); break; // Dark Purple
      default: cardColor = const Color(0xFF1C1C1E); // Matte Black
    }

    if (task.isDone) {
      cardColor = const Color(0xFF121212); 
      textColor = Colors.white24;
      iconColor = Colors.white10;
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Slidable(
          key: Key(task.id),
          
          // LEFT: DONE (Matches Task Color)
          startActionPane: ActionPane(
            motion: const StretchMotion(), 
            dismissible: DismissiblePane(onDismissed: () => provider.toggleTask(task.id)),
            children: [
              CustomSlidableAction(
                onPressed: (context) => provider.toggleTask(task.id),
                backgroundColor: cardColor, // Seamless
                foregroundColor: Colors.white,
                child: const Icon(Icons.check, size: 28),
              ),
            ],
          ),

          // RIGHT: TOOLS (Seamless Block - No Gaps)
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.85, 
            children: [
              // Edit
              _buildSeamlessAction(
                icon: CupertinoIcons.pencil, 
                bgColor: cardColor, 
                iconColor: iconColor,
                onTap: () => _showEditDialog(context, task, provider)
              ),
              // Timer
              _buildSeamlessAction(
                icon: CupertinoIcons.timer, 
                bgColor: cardColor, 
                iconColor: iconColor,
                onTap: () => _showGlassTimePicker(context, task)
              ),
              // Color
              _buildSeamlessAction(
                icon: CupertinoIcons.paintbrush, 
                bgColor: cardColor, 
                iconColor: iconColor,
                onTap: () => _showColorPicker(context, task, provider)
              ),
              // Note
              _buildSeamlessAction(
                icon: CupertinoIcons.doc_text, 
                bgColor: cardColor, 
                iconColor: iconColor,
                onTap: () => _showNoteAttachmentPicker(context, task, provider)
              ),
              // Delete 
              _buildSeamlessAction(
                icon: CupertinoIcons.trash, 
                bgColor: task.priority == 2 ? Colors.black : cardColor, // Fix visibility on Red bars
                iconColor: Colors.redAccent, 
                onTap: () => provider.deleteTask(task.id)
              ),
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
                    color: task.isDone ? Colors.white24 : Colors.transparent,
                    border: Border.all(color: task.isDone ? Colors.transparent : iconColor.withOpacity(0.5), width: 2),
                  ),
                  child: task.isDone ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
                ),
              ),
              
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: textColor,
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
                          Icon(CupertinoIcons.paperclip, size: 12, color: iconColor.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text("Note Attached", style: TextStyle(color: iconColor.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.bold)),
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
                  child: Icon(Icons.drag_handle, color: iconColor.withOpacity(0.5), size: 22),
                ),
              ),
              
              // CLICK ACTION
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

  // --- SEAMLESS BUTTON (NO GAPS) ---
  Widget _buildSeamlessAction({
    required IconData icon, 
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap, 
  }) {
    // Darken tool background slightly to distinguish it, but keep it seamless
    final toolColor = HSLColor.fromColor(bgColor).withLightness((HSLColor.fromColor(bgColor).lightness - 0.05).clamp(0.0, 1.0)).toColor();

    return CustomSlidableAction(
      onPressed: (_) => onTap(),
      backgroundColor: toolColor, 
      foregroundColor: iconColor,
      borderRadius: BorderRadius.zero, // CRITICAL: REMOVES GAPS
      padding: EdgeInsets.zero, 
      child: Icon(icon, size: 22),
    );
  }

  // --- CHOICE DIALOG ---
  void _showActionChoiceDialog(BuildContext context, Task task, TasksProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(task.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(CupertinoIcons.doc_text, color: Colors.blueAccent),
              title: const Text("Open Attached Note", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _openAttachedNote(context, task.note!);
              },
            ),
            Container(height: 1, color: Colors.white10),
            ListTile(
              leading: const Icon(CupertinoIcons.pencil, color: Colors.white),
              title: const Text("Edit Task", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(context, task, provider);
              },
            ),
          ],
        ),
      ),
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

  // --- EDIT DIALOG ---
  void _showEditDialog(BuildContext context, Task task, TasksProvider provider) {
    TextEditingController titleCtrl = TextEditingController(text: task.title);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Edit Task", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(hintText: "Task title...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
              ),
              const Divider(color: Colors.white12),
              
              if (task.note != null && task.note!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.doc_text, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(task.note!, style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          provider.updateTask(task.copyWith(note: "")); 
                          Navigator.pop(ctx);
                          _showEditDialog(context, task.copyWith(note: ""), provider);
                        },
                        child: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38, size: 18),
                      )
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showNoteAttachmentPicker(context, task, provider);
                    },
                    icon: const Icon(CupertinoIcons.add, size: 16),
                    label: const Text("Attach Note"),
                    style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      provider.updateTask(task.copyWith(title: titleCtrl.text));
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    child: const Text("Save"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- COLOR PICKER (Darker) ---
  void _showColorPicker(BuildContext context, Task task, TasksProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Task Color", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _colorDot(ctx, 0, const Color(0xFF1C1C1E), task, provider),
                _colorDot(ctx, 1, const Color(0xFF983301), task, provider),
                _colorDot(ctx, 2, const Color(0xFF8a1c1c), task, provider),
                _colorDot(ctx, 3, const Color(0xFF997b19), task, provider),
                _colorDot(ctx, 4, const Color(0xFF206126), task, provider),
                _colorDot(ctx, 5, const Color(0xFF1a3b80), task, provider),
                _colorDot(ctx, 6, const Color(0xFF5e1a80), task, provider),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.white : Colors.white12, width: isSelected ? 3 : 1)),
        child: isSelected ? const Center(child: Icon(Icons.check, size: 20, color: Colors.white)) : null,
      ),
    );
  }

  // --- HELPERS ---
  void _showNoteAttachmentPicker(BuildContext context, Task task, TasksProvider taskProvider) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: 500,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            const Text("Attach Note", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 20)),
              title: const Text("Create New Note", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                final newNote = Note(id: const Uuid().v4(), title: "Note: ${task.title}", content: "", createdAt: DateTime.now(), updatedAt: DateTime.now());
                notesProvider.addNote(newNote); 
                taskProvider.updateTask(task.copyWith(note: newNote.title));
                Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: newNote)));
              },
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                itemCount: notesProvider.notes.length,
                itemBuilder: (context, i) {
                  final note = notesProvider.notes[i];
                  return ListTile(
                    title: Text(note.title, style: const TextStyle(color: Colors.white70)),
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
      ),
    );
  }

  void _showGlassTimePicker(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 350,
        decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Set Reminder", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ]),
            ),
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 22))),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  backgroundColor: Colors.transparent,
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
      ),
    );
  }
}