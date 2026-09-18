import 'package:flutter/material.dart';

class AiTemplate {
  final String id;
  final String title;
  final String category;
  final String description;
  final String icon;
  final Color color;
  final String defaultPrompt;
  final String widgetType;

  const AiTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.color,
    required this.defaultPrompt,
    required this.widgetType,
  });
}

class AiTemplateService {
  static const List<AiTemplate> templates = [
    // 1. FITNESS
    AiTemplate(
      id: 'workout_plan',
      title: 'Fitness & Workout Routine',
      category: 'Health',
      description: 'Targeted workout routine, exercise checklist, and recovery',
      icon: 'heart',
      color: Color(0xFF4CAF50),
      widgetType: 'checklist',
      defaultPrompt: '''
Generate a structured Fitness & Workout Routine note.
Include:
- Workout Name & Target Muscle Group
- Warm-Up Exercises (5 mins)
- Main Exercises Checklist (- [ ] Exercise name: 3 sets x 12 reps)
- Cool-down & Stretching Routine
- Hydration & Recovery Tips
''',
    ),

    // 6. PROJECT
    AiTemplate(
      id: 'project_breakdown',
      title: 'Project & Goal Roadmap',
      category: 'Productivity',
      description: 'Break down big goals into actionable milestones and tasks',
      icon: 'target',
      color: Color(0xFF3F51B5),
      widgetType: 'checklist',
      defaultPrompt: '''
Generate a Project & Goal Roadmap note.
Include:
- Project Goal & High-level Objective
- Target Completion Date & Scope
- Key Milestones & Actionable Task Checklist (- [ ] Milestone/Task)
- Key Resources & Links Required
- Potential Risks & Solution Strategy
''',
    ),

    // 7. BUDGET
    AiTemplate(
      id: 'budget_planner',
      title: 'Monthly Budget & Savings',
      category: 'Finance',
      description: 'Track income targets, category spending limits, and savings',
      icon: 'money',
      color: Color(0xFF009688),
      widgetType: 'checklist',
      defaultPrompt: '''
Generate a Monthly Budget & Savings Plan note.
Include:
- Budget Month & Total Income Goal
- Fixed Expenses Checklist (- [ ] Rent, Utilities, Subscriptions)
- Variable Spending Limits (- [ ] Groceries, Dining, Leisure)
- Savings & Investment Target
- Financial Tip for the Month
''',
    ),
  ];
}
