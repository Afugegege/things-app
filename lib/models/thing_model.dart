import 'dart:convert';

enum ThingType { note, task, transaction, memory, idea }

class Thing {
  final String id;
  final ThingType type;
  final String title;
  final String content; // Stores text content, transcripts, or descriptions
  
  // Universal Fields
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final bool isPinned;

  // Specific Fields (Nullable)
  final double? amount;         // For Transactions
  final bool isDone;            // For Tasks
  final int priority;           // For Tasks (1-3)
  final String? mediaPath;      // For Photos/Audio
  final String? location;       // "Tokyo, Japan"
  final Map<String, dynamic> metaData; // Flexible storage for styles, sticker emojis, etc.

  Thing({
    required this.id,
    required this.type,
    this.title = '',
    this.content = '',
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.isPinned = false,
    this.amount,
    this.isDone = false,
    this.priority = 0,
    this.mediaPath,
    this.location,
    this.metaData = const {},
  });

  // CopyWith for immutability
  Thing copyWith({
    String? id,
    ThingType? type,
    String? title,
    String? content,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isPinned,
    double? amount,
    bool? isDone,
    int? priority,
    String? mediaPath,
    String? location,
    Map<String, dynamic>? metaData,
  }) {
    return Thing(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: this.createdAt, // CreatedAt should generally not change
      updatedAt: updatedAt ?? DateTime.now(),
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      amount: amount ?? this.amount,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
      mediaPath: mediaPath ?? this.mediaPath,
      location: location ?? this.location,
      metaData: metaData ?? this.metaData,
    );
  }

  // Serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString().split('.').last, // Store as string 'note', 'task'
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'tags': tags,
    'isPinned': isPinned,
    'amount': amount,
    'isDone': isDone,
    'priority': priority,
    'mediaPath': mediaPath,
    'location': location,
    'metaData': metaData,
  };

  factory Thing.fromJson(Map<String, dynamic> json) {
    return Thing(
      id: json['id'],
      type: ThingType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'], 
        orElse: () => ThingType.note
      ),
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      tags: List<String>.from(json['tags'] ?? []),
      isPinned: json['isPinned'] ?? false,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      isDone: json['isDone'] ?? false,
      priority: json['priority'] ?? 0,
      mediaPath: json['mediaPath'],
      location: json['location'],
      metaData: Map<String, dynamic>.from(json['metaData'] ?? {}),
    );
  }
}