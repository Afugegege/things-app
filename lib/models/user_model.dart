class User {
  final String id;
  final String name;
  final String email;
  final String? avatarPath;
  final List<String> aiMemory;
  final Map<String, dynamic> preferences;
  final bool isPro;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarPath': avatarPath,
    'aiMemory': aiMemory,
    'preferences': preferences,
    'isPro': isPro,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarPath: json['avatarPath'],
      aiMemory: List<String>.from(json['aiMemory'] ?? []),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      isPro: json['isPro'] ?? false,
    );
  }

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarPath,
    required this.aiMemory,
    required this.preferences,
    this.isPro = false,
  });

  // FIX: This method was missing!
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarPath,
    List<String>? aiMemory,
    Map<String, dynamic>? preferences,
    bool? isPro,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarPath: avatarPath ?? this.avatarPath,
      aiMemory: aiMemory ?? this.aiMemory,
      preferences: preferences ?? this.preferences,
      isPro: isPro ?? this.isPro,
    );
  }
}