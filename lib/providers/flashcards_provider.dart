import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/flashcard_model.dart';
import '../services/ai_service.dart';
import '../data/japanese_flashcards.dart'; // Optional: for sample data

class FlashcardsProvider extends ChangeNotifier {
  final List<FlashcardDeck> _decks = [];

  List<FlashcardDeck> get decks => _decks;

  FlashcardsProvider() {
    _loadSampleData();
  }

  void _loadSampleData() {
    // Add Japanese Sample
    final japCards = japaneseStarterDeck.map((raw) => Flashcard(
      question: raw['q']!,
      answer: raw['a']!,
    )).toList();

    _decks.add(FlashcardDeck(
      id: const Uuid().v4(),
      title: 'Japanese N5',
      category: 'Language',
      colorValue: 0xFFFF5252, // Red
      cards: japCards,
    ));

    // Add Tech Sample
    _decks.add(FlashcardDeck(
      id: const Uuid().v4(),
      title: 'Computer Science',
      category: 'Tech',
      colorValue: 0xFF7C4DFF, // Purple
      cards: [
        Flashcard(question: 'CPU', answer: 'Central Processing Unit'),
        Flashcard(question: 'RAM', answer: 'Random Access Memory'),
      ],
    ));
  }

  // --- DECK MANAGEMENT ---

  void createDeck(String title, String category, Color color) {
    _decks.add(FlashcardDeck(
      id: const Uuid().v4(),
      title: title,
      category: category,
      colorValue: color.value,
      cards: [],
    ));
    notifyListeners();
  }

  void updateDeck(String id, String title, String category, Color color) {
    final index = _decks.indexWhere((d) => d.id == id);
    if (index != -1) {
      _decks[index].title = title;
      _decks[index].category = category;
      _decks[index].colorValue = color.value;
      notifyListeners();
    }
  }

  void deleteDeck(String id) {
    _decks.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  // --- CARD MANAGEMENT ---

  void addCard(String deckId, String q, String a) {
    final deck = _decks.firstWhere((d) => d.id == deckId);
    deck.cards.add(Flashcard(question: q, answer: a));
    notifyListeners();
  }

  void editCard(String deckId, String cardId, String q, String a) {
    final deck = _decks.firstWhere((d) => d.id == deckId);
    final card = deck.cards.firstWhere((c) => c.id == cardId);
    card.question = q;
    card.answer = a;
    notifyListeners();
  }

  void deleteCard(String deckId, String cardId) {
    final deck = _decks.firstWhere((d) => d.id == deckId);
    deck.cards.removeWhere((c) => c.id == cardId);
    notifyListeners();
  }

  void updateCardMastery(String deckId, String cardId, bool known) {
    final deck = _decks.firstWhere((d) => d.id == deckId);
    final card = deck.cards.firstWhere((c) => c.id == cardId);
    card.masteryLevel = known ? 2 : 0; // Simple mastery logic
    notifyListeners();
  }

  // --- AI GENERATION ---
  Future<void> generateDeckWithAi(String topic) async {
    final rawCards = await AiService().generateFlashcards(topic);
    if (rawCards.isEmpty) return;

    final newCards = rawCards.map((r) => Flashcard(question: r['q']!, answer: r['a']!)).toList();
    
    _decks.add(FlashcardDeck(
      id: const Uuid().v4(),
      title: topic,
      category: "AI Generated",
      colorValue: 0xFF00E676, // Green
      cards: newCards,
    ));
    notifyListeners();
  }
}