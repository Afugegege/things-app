import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../widgets/glass_container.dart';

class FlashCardScreen extends StatefulWidget {
  const FlashCardScreen({super.key});

  @override
  State<FlashCardScreen> createState() => _FlashCardScreenState();
}

class _FlashCardScreenState extends State<FlashCardScreen> {
  // Dummy Data
  List<Map<String, String>> cards = [
    {'q': 'What is the capital of France?', 'a': 'Paris'},
    {'q': 'What is Flutter?', 'a': 'UI Toolkit by Google'},
    {'q': 'What is 12 x 12?', 'a': '144'},
    {'q': 'Who painted the Mona Lisa?', 'a': 'Da Vinci'},
  ];

  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Flashcards", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: cards.isEmpty
            ? const Text("All caught up!", style: TextStyle(color: Colors.white54))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // CARD STACK
                  Draggable(
                    feedback: _buildCard(cards[0], isTop: true, opacity: 0.8),
                    childWhenDragging: cards.length > 1 
                        ? _buildCard(cards[1], isTop: false) 
                        : Container(), // Empty if no next card
                    onDragEnd: (details) {
                      // If dragged far enough, remove card
                      if (details.offset.distance > 100) {
                        setState(() {
                          cards.removeAt(0);
                          _showAnswer = false;
                        });
                      }
                    },
                    child: GestureDetector(
                      onTap: () => setState(() => _showAnswer = !_showAnswer),
                      child: _buildCard(cards[0], isTop: true),
                    ),
                  ),
                  
                  const SizedBox(height: 50),
                  const Text("Tap to Flip • Drag to Dismiss", style: TextStyle(color: Colors.white38)),
                ],
              ),
      ),
    );
  }

  Widget _buildCard(Map<String, String> card, {required bool isTop, double opacity = 1.0}) {
    return Material(
      color: Colors.transparent,
      child: Transform.rotate(
        angle: isTop ? 0 : 0.05, // Slight tilt for background card
        child: Container(
          width: 300,
          height: 450,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: isTop 
                ? (_showAnswer ? const Color(0xFFD6E4FF) : const Color(0xFFFDE8B5)) // Blue if Answer, Yellow if Question
                : Colors.white10,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isTop ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)] : [],
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: opacity,
            child: Text(
              isTop 
                  ? (_showAnswer ? card['a']! : card['q']!)
                  : "Next Card...",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isTop ? Colors.black87 : Colors.white38,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}