class Task {
  final String id;
  final String title;
  final bool isDone;
  final DateTime createdAt;
  final int priority; // 1=Low, 2=Medium, 3=High
  final String? note;
  final bool isPinned;

  Task({
    required this.id,
    required this.title,
    required this.isDone,
    required this.createdAt,
    this.priority = 1,
    this.note,
    this.isPinned = false,
  });

  Task copyWith({
    String? id,
    String? title,
    bool? isDone,
    DateTime? createdAt,
    int? priority,
    String? note,
    bool? isPinned,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      note: note ?? this.note,
      isPinned: isPinned ?? this.isPinned,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isDone': isDone,
    'createdAt': createdAt.toIso8601String(),
    'priority': priority,
    'note': note,
    'isPinned': isPinned,
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      isDone: json['isDone'],
      createdAt: DateTime.parse(json['createdAt']),
      priority: json['priority'] ?? 1,
      note: json['note'],
      isPinned: json['isPinned'] ?? false,
    );
  }
}