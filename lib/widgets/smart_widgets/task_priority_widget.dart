import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/task_model.dart';

class TaskPriorityWidget extends StatelessWidget {
  const TaskPriorityWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white60 : Colors.black54);
    final bgColor = isDark ? theme.cardColor : Colors.white;

    return Consumer<TasksProvider>(
      builder: (context, tasksProv, child) {
        final pendingTasks = tasksProv.tasks.where((t) => !t.isDone).toList();
        final completedToday = tasksProv.tasks.where((t) => t.isDone).length;

        final urgentCount = pendingTasks.where((t) => t.priority >= 3).length;
        final mediumCount = pendingTasks.where((t) => t.priority == 2).length;
        final lowCount = pendingTasks.where((t) => t.priority <= 1).length;

        final total = pendingTasks.length;
        final urgentPct = total > 0 ? urgentCount / total : 0.0;
        final mediumPct = total > 0 ? mediumCount / total : 0.0;
        final lowPct = total > 0 ? lowCount / total : 0.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Provider.of<UserProvider>(context, listen: false).changeView('focus');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.checkmark_seal_fill, color: textColor, size: 14),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "TASKS MATRIX",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: dimmedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$total PENDING",
                      style: TextStyle(
                        color: dimmedColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "$total",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "to do today",
                      style: TextStyle(color: dimmedColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Color-Coded Priority Distribution Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        if (urgentPct > 0)
                          Expanded(
                            flex: (urgentPct * 100).toInt().clamp(1, 100),
                            child: Container(color: isDark ? Colors.white : Colors.black),
                          ),
                        if (mediumPct > 0)
                          Expanded(
                            flex: (mediumPct * 100).toInt().clamp(1, 100),
                            child: Container(color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        if (lowPct > 0)
                          Expanded(
                            flex: (lowPct * 100).toInt().clamp(1, 100),
                            child: Container(color: isDark ? Colors.white24 : Colors.black26),
                          ),
                        if (total == 0)
                          Expanded(
                            child: Container(color: isDark ? Colors.white10 : Colors.black12),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Priority Legend Counts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPriorityTag("Urgent", urgentCount, isDark ? Colors.white : Colors.black, textColor, dimmedColor),
                    _buildPriorityTag("Medium", mediumCount, isDark ? Colors.white60 : Colors.black54, textColor, dimmedColor),
                    _buildPriorityTag("Low", lowCount, isDark ? Colors.white24 : Colors.black26, textColor, dimmedColor),
                  ],
                ),
                if (pendingTasks.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  ...pendingTasks.take(2).map((t) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => tasksProv.toggleTask(t.id),
                            child: Icon(
                              CupertinoIcons.circle,
                              size: 16,
                              color: dimmedColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriorityTag(String label, int count, Color color, Color textColor, Color dimmedColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          "$label $count",
          style: TextStyle(color: dimmedColor, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
