import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/flashcards_provider.dart';
import '../../providers/user_provider.dart';

class FlashcardHomeWidget extends StatelessWidget {
  const FlashcardHomeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<FlashcardsProvider>(context);
    final decks = provider.decks;

    // Show stats for the first deck or general stats
    final totalDecks = decks.length;
    int totalCards = 0;
    int mastered = 0;

    for (var d in decks) {
      totalCards += d.cards.length;
      mastered += d.cards.where((c) => c.masteryLevel > 1).length;
    }

    final progress = totalCards == 0 ? 0.0 : mastered / totalCards;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(CupertinoIcons.book, color: Colors.purpleAccent, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$totalDecks Decks",
                  style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Study Progress",
            style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "${(progress * 100).toInt()}%",
                style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            "$mastered / $totalCards Cards Mastered",
            style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
