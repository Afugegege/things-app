import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/storage_service.dart';
import '../../services/ai_service.dart';
import '../../utils/json_cleaner.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../widgets/glass_container.dart';
import '../../models/chat_model.dart';
import '../chat/chat_screen.dart'; 

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // DATA STATES
  bool _isSleeping = false;
  DateTime? _sleepStart;
  
  // Body & Nutrition
  List<Map<String, dynamic>> _weightLogs = [];
  List<Map<String, dynamic>> _foodLogs = [];
  double _heightCm = 175.0; // [UPDATED] Height Record
  double _targetWeight = 70.0;
  String _weightGoal = "Maintain"; 
  int _waterGlasses = 0;
  String _lastWaterDate = "";

  // Cycle & Symptoms
  List<Map<String, dynamic>> _cycleLogs = [];
  List<Map<String, dynamic>> _symptomLogs = [];
  
  // Mind Data
  List<Map<String, dynamic>> _moodLogs = [];
  List<String> _gratitudeJournal = [];

  // AI
  String _aiHealthTip = "Tap 'Generate Plan' to get personalized advice.";
  bool _isLoadingAi = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); 
    _loadData();
    _checkDailyReset();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final data = StorageService.loadHealthData();
    if (data.containsKey('isSleeping')) _isSleeping = data['isSleeping'];
    if (data.containsKey('sleepStart') && data['sleepStart'] != null) _sleepStart = DateTime.parse(data['sleepStart']);
    
    if (data.containsKey('weightLogs')) _weightLogs = List<Map<String, dynamic>>.from(data['weightLogs']);
    if (data.containsKey('foodLogs')) _foodLogs = List<Map<String, dynamic>>.from(data['foodLogs']);
    if (data.containsKey('height')) _heightCm = data['height'] ?? 175.0;
    if (data.containsKey('targetWeight')) _targetWeight = data['targetWeight'] ?? 70.0;
    if (data.containsKey('weightGoal')) _weightGoal = data['weightGoal'] ?? "Maintain";

    if (data.containsKey('waterGlasses')) _waterGlasses = data['waterGlasses'] ?? 0;
    if (data.containsKey('lastWaterDate')) _lastWaterDate = data['lastWaterDate'] ?? "";

    if (data.containsKey('logs')) _moodLogs = List<Map<String, dynamic>>.from(data['logs']);
    if (data.containsKey('cycleLogs')) _cycleLogs = List<Map<String, dynamic>>.from(data['cycleLogs']);
    if (data.containsKey('symptomLogs')) _symptomLogs = List<Map<String, dynamic>>.from(data['symptomLogs']);
    if (data.containsKey('gratitude')) _gratitudeJournal = List<String>.from(data['gratitude']);
    if (data.containsKey('lastTip')) _aiHealthTip = data['lastTip'];
    
    _weightLogs.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    
    setState(() {});
  }

  void _saveData() {
    StorageService.saveHealthData({
      'isSleeping': _isSleeping,
      'sleepStart': _sleepStart?.toIso8601String(),
      'weightLogs': _weightLogs,
      'foodLogs': _foodLogs,
      'height': _heightCm,
      'targetWeight': _targetWeight,
      'weightGoal': _weightGoal,
      'waterGlasses': _waterGlasses,
      'lastWaterDate': _lastWaterDate,
      'logs': _moodLogs,
      'cycleLogs': _cycleLogs,
      'symptomLogs': _symptomLogs,
      'gratitude': _gratitudeJournal,
      'lastTip': _aiHealthTip,
    });
  }

  void _checkDailyReset() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_lastWaterDate != today) {
      setState(() {
        _waterGlasses = 0;
        _lastWaterDate = today;
      });
      _saveData();
    }
  }

  // --- ACTIONS ---

  void _toggleSleep() {
    setState(() {
      if (_isSleeping) {
        _isSleeping = false;
        _sleepStart = null;
      } else {
        _isSleeping = true;
        _sleepStart = DateTime.now();
      }
    });
    _saveData();
  }

  void _addWater() {
    setState(() => _waterGlasses++);
    _saveData();
  }

  // [FIX] Added missing _addWeightEntry method
  void _addWeightEntry(double weight) {
    setState(() {
      _weightLogs.add({
        'date': DateTime.now().toIso8601String(),
        'weight': weight,
      });
      // Keep sorted
      _weightLogs.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    });
    _saveData();
  }

  // [UPDATED] Food Log with Portion Control
  Future<void> _logFoodWithAi(String description) async {
    setState(() => _isLoadingAi = true);
    final prompt = "Analyze this food and return ONLY a JSON object: {\"action\": \"log_food\", \"name\": \"item name\", \"calories\": 0, \"protein\": 0, \"carbs\": 0, \"fat\": 0}. Food: $description";
    
    try {
      final response = await AiService().sendMessage(
        history: [ChatMessage(id: 'temp', text: prompt, isUser: true, timestamp: DateTime.now())],
        userMemories: [],
        mode: 'Nutritionist', 
      );
      
      final cleaned = JsonCleaner.clean(response);
      final data = jsonDecode(cleaned);
      
      if (data['action'] == 'log_food') {
        if (mounted) {
          _showFoodConfirmDialog(data); // [FIX] Show confirmation dialog
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI failed to analyze food.")));
    } finally {
      setState(() => _isLoadingAi = false);
    }
  }

  void _addSymptom(String symptom, int severity) {
    setState(() {
      _symptomLogs.insert(0, {
        'date': DateTime.now().toIso8601String(),
        'symptom': symptom,
        'severity': severity,
      });
    });
    _saveData();
  }

  void _addPeriodStart() {
    setState(() {
      _cycleLogs.insert(0, {
        'date': DateTime.now().toIso8601String(),
        'type': 'start',
      });
    });
    _saveData();
  }

  // [UPDATED] Clear AI Report
  void _clearAiPlan() {
    setState(() => _aiHealthTip = "Tap 'Generate Plan' to get personalized advice.");
    _saveData();
  }

  Future<void> _getAiPlan() async {
    setState(() => _isLoadingAi = true);
    
    final currentWeight = _weightLogs.isNotEmpty ? _weightLogs.last['weight'] : "Unknown";
    final recentFood = _foodLogs.take(3).map((f) => "${f['name']} (${f['calories']}kcal)").join(", ");
    final recentSymptoms = _symptomLogs.take(3).map((s) => s['symptom']).join(", ");
    
    final prompt = """
    My Profile:
    - Goal: $_weightGoal (Target: $_targetWeight kg)
    - Current Weight: $currentWeight kg
    - Height: $_heightCm cm
    - Recent Food: $recentFood
    - Recent Symptoms: $recentSymptoms
    - Sleep Status: ${_isSleeping ? 'Currently Sleeping' : 'Awake'}
    
    Create a holistic health report for today:
    1. Analysis of my recent nutrition & weight trend.
    2. Suggestion to alleviate any symptoms.
    3. A specific workout/recovery plan.
    """;

    try {
      final response = await AiService().sendMessage(
        history: [ChatMessage(id: 'temp', text: prompt, isUser: true, timestamp: DateTime.now())],
        userMemories: [],
        mode: 'Health (Pulse)', 
      );
      setState(() => _aiHealthTip = response);
      _saveData();
    } catch (e) {
      setState(() => _aiHealthTip = "Connection error.");
    } finally {
      setState(() => _isLoadingAi = false);
    }
  }

  // --- UI HELPERS ---

  double _calculateBMI() {
    if (_weightLogs.isEmpty || _heightCm == 0) return 0.0;
    double weight = _weightLogs.last['weight'];
    double heightM = _heightCm / 100;
    return weight / (heightM * heightM);
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return LifeAppScaffold(
      title: "PULSE",
      actions: [
        IconButton(
          icon: const Icon(CupertinoIcons.settings),
          color: textColor,
          onPressed: _showSettingsDialog,
        )
      ],
      child: Column(
        children: [
          Container(
            color: theme.scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.primaryColor,
              labelColor: textColor,
              unselectedLabelColor: secondaryColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              tabs: const [
                Tab(text: "OVERVIEW"),
                Tab(text: "NUTRITION"),
                Tab(text: "BODY"),
                Tab(text: "MIND"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(context),
                _buildNutritionTab(context),
                _buildBodyTab(context),
                _buildMindTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TABS ---

  Widget _buildOverviewTab(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      // [FIX] Added bottom padding so nav bar doesn't block content
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
      children: [
        // AI COACH HEADER
        GlassContainer(
          padding: const EdgeInsets.all(20),
          opacity: isDark ? 0.1 : 0.05,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(CupertinoIcons.sparkles, color: Colors.amber, size: 18),
                    SizedBox(width: 10),
                    Text("HEALTH OS INTELLIGENCE", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                  // [FIX] Clear Button
                  GestureDetector(
                    onTap: _clearAiPlan,
                    child: Icon(CupertinoIcons.trash, color: Colors.redAccent.withOpacity(0.5), size: 16),
                  )
                ],
              ),
              const SizedBox(height: 15),
              if (_isLoadingAi)
                 Center(child: CircularProgressIndicator(color: textColor))
              else
                 Text(_aiHealthTip, style: TextStyle(color: textColor, height: 1.5, fontSize: 14)),
              
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _getAiPlan,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("Generate Report"),
                ),
              )
            ],
          ),
        ),
        
        const SizedBox(height: 20),

        // QUICK METRICS GRID
        Row(
          children: [
            Expanded(child: _buildMetricTile("Hydration", "$_waterGlasses cups", CupertinoIcons.drop_fill, Colors.blueAccent, _addWater)),
            const SizedBox(width: 15),
            Expanded(child: _buildMetricTile("Sleep", _isSleeping ? "ON" : "OFF", CupertinoIcons.moon_fill, Colors.purpleAccent, _toggleSleep)),
          ],
        ),
        
        const SizedBox(height: 30),
        _buildSymptomChecker(context),
      ],
    );
  }

  Widget _buildNutritionTab(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final secondaryColor = theme.textTheme.bodyMedium?.color;

    int totalCals = 0;
    int totalProtein = 0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    for (var log in _foodLogs) {
      if (log['date'].startsWith(today)) {
        totalCals += (log['calories'] as int);
        totalProtein += (log['protein'] as int);
      }
    }

    return ListView(
      // [FIX] Added bottom padding
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
      children: [
        // CALORIE COUNTER
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CALORIES TODAY", style: TextStyle(color: theme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 5),
                  Text("$totalCals kcal", style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text("$totalProtein g Protein", style: TextStyle(color: secondaryColor, fontSize: 12)),
                ],
              ),
              FloatingActionButton(
                mini: true,
                backgroundColor: theme.primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
                onPressed: _showFoodLogDialog,
              )
            ],
          ),
        ),

        const SizedBox(height: 25),
        Text("FOOD DIARY", style: TextStyle(color: secondaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        
        if (_foodLogs.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("No meals logged yet.", style: TextStyle(color: secondaryColor))))
        else
          ..._foodLogs.take(10).map((log) {
            final date = DateTime.parse(log['date']);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.restaurant, color: Colors.orange, size: 18),
              ),
              title: Text(log['name'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text("${DateFormat.Hm().format(date)} • ${log['calories']} kcal • P: ${log['protein']}g", style: TextStyle(color: secondaryColor, fontSize: 12)),
            );
          }),
      ],
    );
  }

  Widget _buildBodyTab(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final secondaryColor = theme.textTheme.bodyMedium?.color;
    
    final currentWeight = _weightLogs.isNotEmpty ? _weightLogs.last['weight'] : 0.0;
    final bmi = _calculateBMI();
    
    List<FlSpot> spots = [];
    if (_weightLogs.isNotEmpty) {
      for (int i = 0; i < _weightLogs.length; i++) {
        spots.add(FlSpot(i.toDouble(), _weightLogs[i]['weight']));
      }
    }

    return ListView(
      // [FIX] Added bottom padding
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
      children: [
        // METRICS ROW
        Row(
          children: [
            Expanded(
              child: _buildMetricTile("WEIGHT", "$currentWeight kg", Icons.scale, Colors.blueAccent, _showWeightDialog),
            ),
            const SizedBox(width: 15),
            // [FIX] Height Dialog Trigger
            Expanded(
              child: _buildMetricTile("HEIGHT", "${_heightCm.toInt()} cm", Icons.height, Colors.teal, _showHeightDialog), 
            ),
          ],
        ),
        const SizedBox(height: 15),
        
        // BMI CARD
        GlassContainer(
          padding: const EdgeInsets.all(15),
          opacity: 0.05,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("BMI SCORE", style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 10)),
              Text(bmi.toStringAsFixed(1), style: TextStyle(color: _getBmiColor(bmi), fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // WEIGHT CHART
        Text("WEIGHT TREND", style: TextStyle(color: secondaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 15),
        SizedBox(
          height: 200,
          child: _weightLogs.length < 2 
            ? Center(child: Text("Log more data to see trend.", style: TextStyle(color: secondaryColor)))
            : LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: theme.primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: theme.primaryColor.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
        ),

        const SizedBox(height: 30),

        // CYCLE TRACKER
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.pinkAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CYCLE TRACKER", style: TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 5),
                  Text(_cycleLogs.isNotEmpty ? "Last: ${DateFormat('MMM d').format(DateTime.parse(_cycleLogs.first['date']))}" : "Not Logged", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
                onPressed: _addPeriodStart,
                child: const Text("Log Period"),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMindTab(BuildContext context) {
    return ListView(
      // [FIX] Added bottom padding
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.spa, color: Colors.purpleAccent, size: 30),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Talk to Counselor", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Mental health support & guidance", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildMetricTile(String title, String value, IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 100,
        opacity: 0.05,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                Icon(icon, size: 16, color: color),
              ],
            ),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomChecker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SYMPTOM CHECKER", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: ["Headache", "Nausea", "Fatigue", "Cramps", "Anxiety"].map((s) {
            return ActionChip(
              label: Text(s),
              onPressed: () => _addSymptom(s, 5), 
              backgroundColor: Theme.of(context).cardColor,
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- DIALOGS ---

  void _showFoodLogDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Log Meal"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g., Oatmeal and coffee"),
        ),
        actions: [
          TextButton(
            child: const Text("Analyze with AI"),
            onPressed: () {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) _logFoodWithAi(controller.text);
            },
          )
        ],
      ),
    );
  }

  // [FIX] Food Confirmation & Portion Control Dialog
  void _showFoodConfirmDialog(Map<String, dynamic> data) {
    double portion = 1.0;
    
    // Mutable copies
    String name = data['name'];
    int calories = data['calories'];
    int protein = data['protein'];
    int carbs = data['carbs'];
    int fat = data['fat'];

    final nameCtrl = TextEditingController(text: name);
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          final adjustedCals = (calories * portion).round();
          final adjustedPro = (protein * portion).round();
          final adjustedCarbs = (carbs * portion).round();
          final adjustedFat = (fat * portion).round();

          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: const Text("Review Meal"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Food Name")),
                  const SizedBox(height: 15),
                  Text("Portion Size: ${portion}x", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: portion,
                    min: 0.25, max: 3.0, divisions: 11,
                    label: "$portion x",
                    onChanged: (val) => setDialogState(() => portion = val),
                  ),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Calories"), Text("$adjustedCals kcal", style: const TextStyle(fontWeight: FontWeight.bold))]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Protein"), Text("${adjustedPro}g")]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Carbs"), Text("${adjustedCarbs}g")]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Fat"), Text("${adjustedFat}g")]),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              TextButton(
                child: const Text("Save Log"),
                onPressed: () {
                  setState(() {
                    _foodLogs.insert(0, {
                      'date': DateTime.now().toIso8601String(),
                      'name': nameCtrl.text,
                      'calories': adjustedCals,
                      'protein': adjustedPro,
                      'carbs': adjustedCarbs,
                      'fat': adjustedFat,
                    });
                  });
                  _saveData();
                  Navigator.pop(ctx);
                },
              )
            ],
          );
        });
      },
    );
  }

  void _showSettingsDialog() {
    final heightCtrl = TextEditingController(text: _heightCm.toString());
    final targetCtrl = TextEditingController(text: _targetWeight.toString());
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Body Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: heightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Height (cm)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Target Weight (kg)"),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: _weightGoal,
              isExpanded: true,
              items: ["Lose", "Maintain", "Gain"].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _weightGoal = val);
              },
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _heightCm = double.tryParse(heightCtrl.text) ?? _heightCm;
                _targetWeight = double.tryParse(targetCtrl.text) ?? _targetWeight;
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _showWeightDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Log Weight"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: "kg", suffixText: "kg"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) _addWeightEntry(val);
              Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }

  // [FIX] New Height Dialog
  void _showHeightDialog() {
    final controller = TextEditingController(text: _heightCm.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Update Height"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: "cm", suffixText: "cm"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) {
                setState(() => _heightCm = val);
                _saveData();
              }
              Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blueAccent;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
}