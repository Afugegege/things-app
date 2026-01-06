import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../services/storage_service.dart';
import '../../services/ai_service.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../widgets/glass_container.dart';
import '../../models/chat_model.dart'; 

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  bool _isSleeping = false;
  DateTime? _sleepStart;
  List<Map<String, dynamic>> _sleepHistory = [];
  List<Map<String, dynamic>> _healthLogs = [];
  String _aiHealthTip = "Tap below to generate a health plan.";
  bool _isLoadingAi = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final data = StorageService.loadHealthData();
    if (data.containsKey('isSleeping')) _isSleeping = data['isSleeping'];
    if (data.containsKey('sleepStart') && data['sleepStart'] != null) {
      _sleepStart = DateTime.parse(data['sleepStart']);
    }
    if (data.containsKey('history')) {
      _sleepHistory = List<Map<String, dynamic>>.from(data['history']);
    }
    if (data.containsKey('logs')) {
      _healthLogs = List<Map<String, dynamic>>.from(data['logs']);
    }
    if (data.containsKey('lastTip')) _aiHealthTip = data['lastTip'];
    setState(() {});
  }

  void _saveData() {
    StorageService.saveHealthData({
      'isSleeping': _isSleeping,
      'sleepStart': _sleepStart?.toIso8601String(),
      'history': _sleepHistory,
      'logs': _healthLogs,
      'lastTip': _aiHealthTip,
    });
  }

  void _toggleSleep() {
    setState(() {
      if (_isSleeping) {
        final end = DateTime.now();
        if (_sleepStart != null) {
          final duration = end.difference(_sleepStart!);
          _sleepHistory.insert(0, {
            'start': _sleepStart!.toIso8601String(),
            'end': end.toIso8601String(),
            'hours': duration.inHours,
            'minutes': duration.inMinutes % 60,
          });
        }
        _isSleeping = false;
        _sleepStart = null;
      } else {
        _isSleeping = true;
        _sleepStart = DateTime.now();
      }
    });
    _saveData();
  }

  void _showLogSheet() {
    double mood = 5.0;
    List<String> selectedTags = [];
    final List<String> tags = ["Headache", "Tired", "Anxious", "Energetic", "Sore", "Focus", "Nauseous"];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(25),
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Log How You Feel", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text("Mood (1-10)", style: TextStyle(color: Colors.white54)),
                  Slider(
                    value: mood,
                    min: 1, max: 10, divisions: 9,
                    label: mood.round().toString(),
                    activeColor: _getMoodColor(mood),
                    onChanged: (val) => setSheetState(() => mood = val),
                  ),
                  Center(child: Text(_getMoodLabel(mood), style: TextStyle(color: _getMoodColor(mood), fontWeight: FontWeight.bold))),
                  const SizedBox(height: 20),
                  const Text("Physical & Mental Tags", style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: tags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return ChoiceChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          setSheetState(() {
                            if (selected) selectedTags.add(tag);
                            else selectedTags.remove(tag);
                          });
                        },
                        selectedColor: Colors.blueAccent,
                        backgroundColor: Colors.white10,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                      );
                    }).toList(),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _addHealthLog(mood, selectedTags);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                      child: const Text("Save Log"),
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

  void _addHealthLog(double mood, List<String> tags) {
    setState(() {
      _healthLogs.insert(0, {
        'date': DateTime.now().toIso8601String(),
        'mood': mood,
        'tags': tags,
      });
    });
    _saveData();
  }

  Color _getMoodColor(double val) {
    if (val < 4) return Colors.redAccent;
    if (val < 7) return Colors.amber;
    return Colors.greenAccent;
  }

  String _getMoodLabel(double val) {
    if (val < 4) return "Struggling 😞";
    if (val < 7) return "Okay 😐";
    return "Great 🚀";
  }

  Future<void> _getAiPlan() async {
    setState(() => _isLoadingAi = true);
    
    String contextData = "Recent Logs:\n";
    for (var log in _healthLogs.take(5)) {
      contextData += "- Mood: ${log['mood']}, Tags: ${(log['tags'] as List).join(', ')}\n";
    }

    final prompt = """
    Based on my recent health logs:
    $contextData
    Create a specific daily plan.
    Include:
    1. A workout or activity suggestion.
    2. A nutrition tip.
    3. A mental wellness tip.
    """;

    try {
      final response = await AiService().sendMessage(
        history: [ChatMessage(id: 'temp', text: prompt, isUser: true, timestamp: DateTime.now())],
        userMemories: [],
      );
      setState(() => _aiHealthTip = response);
      _saveData();
    } catch (e) {
      setState(() => _aiHealthTip = "Could not connect to AI. Try again.");
    } finally {
      setState(() => _isLoadingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LifeAppScaffold(
      title: "PULSE",
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
          onPressed: _showLogSheet,
        )
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: _toggleSleep,
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSleeping 
                      ? [const Color(0xFF0f0c29), const Color(0xFF302b63)] 
                      : [const Color(0xFFFF512F), const Color(0xFFDD2476)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: _isSleeping ? Colors.blue.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3), 
                    blurRadius: 20, 
                    spreadRadius: 2
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isSleeping ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  Text(
                    _isSleeping ? "SLEEPING..." : "AWAKE",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  if (_isSleeping && _sleepStart != null)
                     Text(
                       "Since ${_sleepStart!.hour.toString().padLeft(2,'0')}:${_sleepStart!.minute.toString().padLeft(2,'0')}",
                       style: const TextStyle(color: Colors.white70),
                     )
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          if (_healthLogs.isNotEmpty) ...[
            const Text("RECENT CHECK-INS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _healthLogs.length,
                itemBuilder: (ctx, i) {
                  final log = _healthLogs[i];
                  final date = DateTime.parse(log['date']);
                  final mood = log['mood'] as double;
                  return GlassContainer(
                    width: 120,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_getMoodLabel(mood).split(' ')[1], style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 5),
                        Text("${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2,'0')}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        const SizedBox(height: 5),
                        Text("Mood: ${mood.toInt()}", style: TextStyle(color: _getMoodColor(mood), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("AI HEALTH COACH", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const Icon(CupertinoIcons.sparkles, color: Colors.amber, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          GlassContainer(
            padding: const EdgeInsets.all(20),
            opacity: 0.1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingAi)
                   const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.white)))
                else
                   Text(_aiHealthTip, style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 14)),
                
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _getAiPlan,
                    icon: const Icon(Icons.fitness_center),
                    label: const Text("Generate Health Plan"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, 
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}