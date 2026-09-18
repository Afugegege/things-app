import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/storage_service.dart';

class SleepEnergyWidget extends StatefulWidget {
  const SleepEnergyWidget({super.key});

  @override
  State<SleepEnergyWidget> createState() => _SleepEnergyWidgetState();
}

class _SleepEnergyWidgetState extends State<SleepEnergyWidget> {
  double _sleepHours = 7.5;
  int _energyLevel = 4; // 1 to 5

  @override
  void initState() {
    super.initState();
    final logs = StorageService.loadSleepEnergyLogs();
    if (logs.isNotEmpty) {
      _sleepHours = (logs.last['sleepHours'] as num?)?.toDouble() ?? 7.5;
      _energyLevel = (logs.last['energyLevel'] as num?)?.toInt() ?? 4;
    }
  }

  void _saveLog() {
    final logs = StorageService.loadSleepEnergyLogs();
    logs.add({
      'date': DateTime.now().toIso8601String(),
      'sleepHours': _sleepHours,
      'energyLevel': _energyLevel,
    });
    StorageService.saveSleepEnergyLogs(logs);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sleep & Energy Logged")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final dimmedColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white60 : Colors.black54);
    final bgColor = isDark ? theme.cardColor : Colors.white;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: isDark
            ? Border.all(color: Colors.white12, width: 1.0)
            : Border.all(color: Colors.black.withOpacity(0.08), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER BADGE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.moon_stars_fill, size: 14, color: textColor),
                    const SizedBox(width: 5),
                    Text(
                      "SLEEP & ENERGY",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _saveLog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "LOG",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // SLEEP HOURS CONTROL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "Sleep: ${_sleepHours.toStringAsFixed(1)} hrs",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(CupertinoIcons.minus_circle, size: 20, color: textColor),
                    onPressed: () {
                      if (_sleepHours > 1) setState(() => _sleepHours -= 0.5);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(CupertinoIcons.plus_circle, size: 20, color: textColor),
                    onPressed: () {
                      if (_sleepHours < 16) setState(() => _sleepHours += 0.5);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ENERGY LEVEL CONTROL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Energy:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dimmedColor),
              ),
              Row(
                children: List.generate(5, (index) {
                  final lvl = index + 1;
                  final isSel = lvl <= _energyLevel;
                  return GestureDetector(
                    onTap: () => setState(() => _energyLevel = lvl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        CupertinoIcons.bolt_fill,
                        size: 16,
                        color: isSel ? textColor : (isDark ? Colors.white24 : Colors.black12),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
