import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../providers/tasks_provider.dart';
import '../providers/events_provider.dart';
import '../providers/money_provider.dart';
import '../providers/notes_provider.dart';

class AiBriefingSheet extends StatefulWidget {
  const AiBriefingSheet({super.key});

  @override
  State<AiBriefingSheet> createState() => _AiBriefingSheetState();
}

class _AiBriefingSheetState extends State<AiBriefingSheet> {
  bool _isLoading = true;
  String _briefingText = "";

  @override
  void initState() {
    super.initState();
    _fetchBriefing();
  }

  Future<void> _fetchBriefing() async {
    final tasksProv = Provider.of<TasksProvider>(context, listen: false);
    final eventsProv = Provider.of<EventsProvider>(context, listen: false);
    final moneyProv = Provider.of<MoneyProvider>(context, listen: false);
    final notesProv = Provider.of<NotesProvider>(context, listen: false);

    final pendingTasks = tasksProv.tasks.where((t) => !t.isDone).map((t) => t.title).toList();
    final todayEvents = eventsProv.events.map((e) => e.title).toList();

    double monthSpend = 0.0;
    for (var tx in moneyProv.transactions) {
      final double amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt < 0) monthSpend += amt.abs();
    }

    final aiService = AiService();
    final text = await aiService.generateMorningBriefing(
      tasks: pendingTasks.take(5).toList(),
      events: todayEvents.take(3).toList(),
      trips: const [],
      monthSpend: monthSpend,
      currencyCode: moneyProv.currentCurrency,
      currencySymbol: moneyProv.currentCurrencySymbol,
    );

    if (mounted) {
      setState(() {
        _briefingText = text;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SHEET HANDLE
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // TITLE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.sun_max_fill, color: Colors.amberAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "Morning AI Briefing",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // BRIEFING CONTENT
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.amberAccent),
                        SizedBox(height: 16),
                        Text(
                          "Synthesizing your daily briefing with AI...",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _briefingText,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                        ),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(CupertinoIcons.checkmark_alt, color: Colors.white),
              label: const Text("Let's Conquer Today!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
