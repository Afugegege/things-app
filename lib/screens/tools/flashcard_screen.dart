import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../providers/flashcards_provider.dart';
import '../../models/flashcard_model.dart';
import '../../services/ai_service.dart';
import '../../providers/user_provider.dart';
import 'ai_deck_review_screen.dart';

class FlashCardScreen extends StatefulWidget {
  const FlashCardScreen({super.key});

  @override
  State<FlashCardScreen> createState() => _FlashCardScreenState();
}

class _FlashCardScreenState extends State<FlashCardScreen> {
  FlashcardDeck? _activeDeck; // If set, we are in Details View
  bool _isStudying = false;   // If true, we are in Study Mode

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FlashcardsProvider>(context);
    final decks = provider.decks;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine Title & Actions based on state
    String title = "LIBRARY";
    List<Widget>? actions;
    Widget? fab;

    if (_isStudying) {
      title = "STUDY MODE";
    } else if (_activeDeck != null) {
      title = _activeDeck!.title.toUpperCase();
      actions = [
        IconButton(
          icon: Icon(CupertinoIcons.ellipsis_circle, color: theme.textTheme.bodyLarge?.color), 
          onPressed: () => _showDeckOptions(context, _activeDeck!),
        ),
      ];
    } else {
      actions = [
        IconButton(
          icon: Icon(CupertinoIcons.add, color: theme.textTheme.bodyLarge?.color), 
          onPressed: () => _showCreateDeckDialog(context, null)
        ),
      ];
    }

    // [UPDATED] Use LifeAppScaffold
    return LifeAppScaffold(
      title: title,
      useDrawer: _activeDeck == null && !_isStudying, // Only show drawer at root
      actions: actions,
      onBack: (_activeDeck != null || _isStudying) ? () {
        setState(() {
          if (_isStudying) {
            _isStudying = false;
          } else {
            _activeDeck = null;
          }
        });
      } : null,
      // Custom back button logic for navigation within the screen
      child: _isStudying
          ? _StudyView(deck: _activeDeck!, onExit: () => setState(() => _isStudying = false))
          : _activeDeck == null
              ? _DeckGridView(decks: decks, onOpen: (d) => setState(() => _activeDeck = d))
              : _DeckDetailView(deck: _activeDeck!),
    );
  }

  // --- DIALOGS (Themed) ---

  void _showCreateDeckDialog(BuildContext context, FlashcardDeck? existing) {
    final accentColor = Provider.of<UserProvider>(context, listen: false).accentColor;
    final titleCtrl = TextEditingController(text: existing?.title);
    final catCtrl = TextEditingController(text: existing?.category);
    Color selectedColor = existing?.color ?? accentColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40, top: 20, left: 25, right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(existing == null ? "NEW DECK" : "EDIT DECK", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 25),
                
                CupertinoTextField(
                  controller: titleCtrl,
                  placeholder: "Deck Title",
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 15),
                CupertinoTextField(
                  controller: catCtrl,
                  placeholder: "Category (e.g. Science)",
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                
                const SizedBox(height: 25),
                Text("COLOR LABEL", style: TextStyle(color: secondaryTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [accentColor, Colors.blueAccent, Colors.redAccent, Colors.greenAccent, Colors.orangeAccent, Colors.purpleAccent].map((c) => 
                    GestureDetector(
                      onTap: () => setModalState(() => selectedColor = c),
                      child: Container(
                        width: 45, height: 45,
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.2), 
                          shape: BoxShape.circle, 
                          border: Border.all(color: selectedColor == c ? c : Colors.transparent, width: 2)
                        ),
                        child: Center(child: Container(width: 20, height: 20, decoration: BoxDecoration(color: c, shape: BoxShape.circle))),
                      ),
                    )
                  ).toList(),
                ),

                const SizedBox(height: 30),
                Row(
                  children: [
                    if (existing == null) ...[
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: inputBg,
                          borderRadius: BorderRadius.circular(15),
                          child: Icon(CupertinoIcons.sparkles, color: textColor),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAiDialog(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                    ],
                    Expanded(
                      flex: 3,
                      child: CupertinoButton(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(15),
                        child: Text(existing == null ? "Create" : "Save", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          if (titleCtrl.text.isNotEmpty) {
                            if (existing == null) {
                              Provider.of<FlashcardsProvider>(context, listen: false).createDeck(titleCtrl.text, catCtrl.text, selectedColor);
                            } else {
                              Provider.of<FlashcardsProvider>(context, listen: false).updateDeck(existing.id, titleCtrl.text, catCtrl.text, selectedColor);
                            }
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAiDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
        final isDark = theme.brightness == Brightness.dark;
        final inputBg = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("AI CREATOR ✨", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
          content: CupertinoTextField(
            controller: ctrl,
            placeholder: "Enter topic (e.g. Spanish Basics)",
            placeholderStyle: TextStyle(color: secondaryTextColor),
            style: TextStyle(color: textColor),
            decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: secondaryTextColor))),
            TextButton(
              child: Text("Generate", style: TextStyle(color: Provider.of<UserProvider>(context).accentColor, fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (ctrl.text.isEmpty) return;
                Navigator.pop(ctx);
                
                // Show loading
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("AI is generating flashcards..."), duration: Duration(seconds: 2))
                );

                // Generate cards
                final rawCards = await AiService().generateFlashcards(ctrl.text);
                
                if (!context.mounted) return;
                if (rawCards.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Generation failed. Try again."))
                  );
                  return;
                }

                // Convert to Flashcard objects
                final cards = rawCards.map((r) => Flashcard(
                  question: r['q']!,
                  answer: r['a']!,
                )).toList();

                // Navigate to review screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiDeckReviewScreen(
                      topic: ctrl.text,
                      initialCards: cards,
                    )
                  ),
                );
              },
            )
          ],
        );
      },
    );
  }

  void _showDeckOptions(BuildContext context, FlashcardDeck deck) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(CupertinoIcons.pencil, color: Provider.of<UserProvider>(context).accentColor),
              title: Text("Edit Deck Info", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(ctx); _showCreateDeckDialog(context, deck); },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
              title: const Text("Delete Deck", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                Provider.of<FlashcardsProvider>(context, listen: false).deleteDeck(deck.id);
                setState(() => _activeDeck = null);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- SUB-WIDGETS ---

class _DeckGridView extends StatelessWidget {
  final List<FlashcardDeck> decks;
  final Function(FlashcardDeck) onOpen;
  const _DeckGridView({required this.decks, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (decks.isEmpty) return Center(child: Text("No decks yet. Tap + to create.", style: TextStyle(color: secondaryTextColor)));
    
    return MasonryGridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      itemCount: decks.length,
      itemBuilder: (context, index) {
        final deck = decks[index];
        return GestureDetector(
          onTap: () => onOpen(deck),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: deck.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(deck.category.toUpperCase(), style: TextStyle(color: deck.color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    Icon(CupertinoIcons.right_chevron, size: 12, color: secondaryTextColor),
                  ],
                ),
                const SizedBox(height: 15),
                Text(deck.title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text("${deck.cards.length} Cards", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                const SizedBox(height: 15),
                LinearProgressIndicator(value: deck.progress, backgroundColor: deck.color.withOpacity(0.1), color: deck.color, minHeight: 4, borderRadius: BorderRadius.circular(2)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeckDetailView extends StatelessWidget {
  final FlashcardDeck deck;
  const _DeckDetailView({required this.deck});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FlashcardsProvider>(context, listen: false);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: 60), // Space for custom back button
        
        // DECK HEADER
        Container(
          padding: const EdgeInsets.all(25),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [deck.color.withOpacity(0.2), deck.color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: deck.color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("MASTERY", style: TextStyle(color: deck.color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 5),
                    Text("${(deck.progress * 100).toInt()}%", style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: deck.progress, color: deck.color, backgroundColor: Colors.black12, minHeight: 6)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              CupertinoButton(
                color: deck.color,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                borderRadius: BorderRadius.circular(15),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.play_fill, color: Colors.white, size: 16),
                    SizedBox(width: 5),
                    Text("Study", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                onPressed: () {
                  if (deck.cards.isNotEmpty) {
                    context.findAncestorStateOfType<_FlashCardScreenState>()!.setState(() => 
                      context.findAncestorStateOfType<_FlashCardScreenState>()!._isStudying = true
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add cards first!")));
                  }
                },
              )
            ],
          ),
        ),

        const SizedBox(height: 25),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CARDS (${deck.cards.length})", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
              GestureDetector(
                onTap: () => _showCardEditor(context, deck, null),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: deck.color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.add, color: deck.color, size: 20),
                ),
              )
            ],
          ),
        ),

        // CARD LIST
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 100),
            itemCount: deck.cards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final card = deck.cards[i];
              return Dismissible(
                key: Key(card.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15)),
                  child: const Icon(CupertinoIcons.trash, color: Colors.white)
                ),
                onDismissed: (_) => provider.deleteCard(deck.id, card.id),
                child: GestureDetector(
                  onTap: () => _showCardEditor(context, deck, card),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Icon(card.masteryLevel > 0 ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle, color: deck.color, size: 20),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.question, style: TextStyle(color: textColor, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(card.answer, style: TextStyle(color: secondaryTextColor, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Icon(CupertinoIcons.chevron_right, color: secondaryTextColor.withOpacity(0.3), size: 14),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCardEditor(BuildContext context, FlashcardDeck deck, Flashcard? card) {
    final qCtrl = TextEditingController(text: card?.question);
    final aCtrl = TextEditingController(text: card?.answer);
    final provider = Provider.of<FlashcardsProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
        final isDark = theme.brightness == Brightness.dark;
        final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 40, top: 20, left: 25, right: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(card == null ? "ADD CARD" : "EDIT CARD", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 25),
              
              CupertinoTextField(
                controller: qCtrl,
                placeholder: "Question (Front)",
                placeholderStyle: TextStyle(color: secondaryTextColor),
                style: TextStyle(color: textColor),
                decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(16),
              ),
              const SizedBox(height: 15),
              CupertinoTextField(
                controller: aCtrl,
                placeholder: "Answer (Back)",
                placeholderStyle: TextStyle(color: secondaryTextColor),
                style: TextStyle(color: textColor),
                decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(16),
              ),
              
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: Provider.of<UserProvider>(context).accentColor,
                  borderRadius: BorderRadius.circular(15),
                  child: const Text("Save Card", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (qCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) {
                      if (card == null) {
                        provider.addCard(deck.id, qCtrl.text, aCtrl.text);
                      } else {
                        provider.editCard(deck.id, card.id, qCtrl.text, aCtrl.text);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class _StudyView extends StatefulWidget {
  final FlashcardDeck deck;
  final VoidCallback onExit;
  const _StudyView({required this.deck, required this.onExit});

  @override
  State<_StudyView> createState() => _StudyViewState();
}

class _StudyViewState extends State<_StudyView> {
  late List<Flashcard> _queue;
  bool _showAnswer = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _queue = List.from(widget.deck.cards)..shuffle();
  }

  void _next(bool known) {
    if (_index >= _queue.length) return;
    
    final card = _queue[_index];
    Provider.of<FlashcardsProvider>(context, listen: false).updateCardMastery(widget.deck.id, card.id, known);

    setState(() {
      _index++;
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final cardBg = theme.cardColor;
    final isDark = theme.brightness == Brightness.dark;

    if (_index >= _queue.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.check_mark_circled_solid, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text("SESSION COMPLETE", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 30),
            CupertinoButton(
              color: textColor,
              borderRadius: BorderRadius.circular(15),
              onPressed: widget.onExit, 
              child: Text("Finish", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold))
            )
          ],
        ),
      );
    }

    final card = _queue[_index];

    return Column(
      children: [
        // Custom Study Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: Icon(CupertinoIcons.xmark, color: secondaryTextColor), onPressed: widget.onExit),
              Text("${_index + 1} / ${_queue.length}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 40), // Spacer
            ],
          ),
        ),

        const SizedBox(height: 20),
        
        // Card Area
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _showAnswer = !_showAnswer),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: _showAnswer ? cardBg.withOpacity(0.9) : cardBg,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10))],
                border: Border.all(color: widget.deck.color.withOpacity(0.5), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_showAnswer ? "ANSWER" : "QUESTION", style: TextStyle(color: widget.deck.color, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
                  const SizedBox(height: 30),
                  Text(
                    _showAnswer ? card.answer : card.question, 
                    textAlign: TextAlign.center, 
                    style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                  if (!_showAnswer)
                    Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Text("Tap to flip", style: TextStyle(color: secondaryTextColor.withOpacity(0.5))),
                    )
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _next(false),
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.xmark, color: Colors.redAccent, size: 28),
                ),
              ),
              GestureDetector(
                onTap: () => _next(true),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: Colors.greenAccent, width: 2)),
                  child: const Icon(CupertinoIcons.check_mark, color: Colors.green, size: 32),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }
}