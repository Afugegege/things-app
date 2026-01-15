import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class FlashcardDeck {
  final String id;
  String title;
  String category;
  int colorValue;
  List<Flashcard> cards;

  FlashcardDeck({
    required this.id,
    required this.title,
    required this.category,
    required this.colorValue,
    this.cards = const [],
  });

  // Helpers
  int get total => cards.length;
  int get mastered => cards.where((c) => c.masteryLevel > 0).length;
  double get progress => total == 0 ? 0.0 : mastered / total;
  Color get color => Color(colorValue);
}

class Flashcard {
  final String id;
  String question;
  String answer;
  int masteryLevel; // 0 = New, 1 = Learning, 2 = Mastered

  Flashcard({
    String? id,
    required this.question,
    required this.answer,
    this.masteryLevel = 0,
  }) : id = id ?? const Uuid().v4();
}