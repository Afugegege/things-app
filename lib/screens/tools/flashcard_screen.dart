import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/dashboard_drawer.dart';
import '../../providers/flashcards_provider.dart';
import '../../models/flashcard_model.dart';

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
    
    // Dynamic Colors
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      drawer: const DashboardDrawer(),
      appBar: _isStudying ? null : AppBar(
        title: Text(_activeDeck != null ? _activeDeck!.title : "Library", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        leading: _activeDeck != null 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _activeDeck = null))
          : Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(c).openDrawer())),
        actions: [
          if (_activeDeck == null)
            IconButton(
              icon: const Icon(Icons.add), 
              onPressed: () => _showCreateDeckDialog(context, null)
            ),
          if (_activeDeck != null)
             IconButton(
              icon: const Icon(Icons.more_horiz), 
              onPressed: () => _showDeckOptions(context, _activeDeck!),
            ),
        ],
      ),
      // REMOVED STACK AND AMBIENT BACKGROUNDS
      body: SafeArea(
        child: _isStudying 
          ? _StudyView(deck: _activeDeck!, onExit: () => setState(() => _isStudying = false))
          : (_activeDeck == null ? _DeckGridView(decks: decks, onOpen: (d) => setState(() => _activeDeck = d)) 
                                 : _DeckDetailView(deck: _activeDeck!)),
      ),
    );
  }

  // --- DIALOGS ---

  void _showCreateDeckDialog(BuildContext context, FlashcardDeck? existing) {
    final provider = Provider.of<FlashcardsProvider>(context, listen: false);
    final titleCtrl = TextEditingController(text: existing?.title);
    final catCtrl = TextEditingController(text: existing?.category);
    Color selectedColor = existing?.color ?? Colors.blueAccent;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? "New Deck" : "Edit Deck", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _inputField("Deck Title", titleCtrl, context),
              const SizedBox(height: 15),
              _inputField("Category (e.g. Science)", catCtrl, context),
              const SizedBox(height: 20),
              Text("Color", style: TextStyle(color: textColor.withOpacity(0.7))),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Colors.blueAccent, Colors.redAccent, Colors.greenAccent, Colors.orangeAccent, Colors.purpleAccent].map((c) => 
                  GestureDetector(
                    onTap: () => setModalState(() => selectedColor = c),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: selectedColor == c ? Border.all(color: textColor, width: 3) : null),
                    ),
                  )
                ).toList(),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  if (existing == null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(CupertinoIcons.sparkles),
                        label: const Text("Generate with AI"),
                        style: OutlinedButton.styleFrom(foregroundColor: textColor, side: BorderSide(color: textColor.withOpacity(0.3))),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAiDialog(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: selectedColor, foregroundColor: Colors.white),
                      onPressed: () {
                        if (titleCtrl.text.isNotEmpty) {
                          if (existing == null) {
                            provider.createDeck(titleCtrl.text, catCtrl.text, selectedColor);
                          } else {
                            provider.updateDeck(existing.id, titleCtrl.text, catCtrl.text, selectedColor);
                          }
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text(existing == null ? "Create" : "Save"),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showAiDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("AI Generator", style: TextStyle(color: textColor)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(hintText: "Enter topic (e.g. Spanish Basics)", hintStyle: TextStyle(color: textColor.withOpacity(0.5))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: textColor.withOpacity(0.7)))),
          TextButton(
            child: const Text("Generate", style: TextStyle(color: Colors.purpleAccent)),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<FlashcardsProvider>(context, listen: false).generateDeckWithAi(ctrl.text);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI is working magic... check back soon!")));
            },
          )
        ],
      ),
    );
  }

  void _showDeckOptions(BuildContext context, FlashcardDeck deck) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blueAccent),
            title: Text("Edit Deck Info", style: TextStyle(color: textColor)),
            onTap: () { Navigator.pop(ctx); _showCreateDeckDialog(context, deck); },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text("Delete Deck", style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(ctx);
              Provider.of<FlashcardsProvider>(context, listen: false).deleteDeck(deck.id);
              setState(() => _activeDeck = null);
            },
          ),
        ],
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController ctrl, BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: textColor.withOpacity(0.1))
      ),
      child: TextField(
        controller: ctrl,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: hint, 
          hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
          border: InputBorder.none
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
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    if (decks.isEmpty) return Center(child: Text("No decks yet. Tap + to create.", style: TextStyle(color: textColor.withOpacity(0.5))));
    
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,4))],
              border: Border.all(color: deck.color.withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: deck.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(deck.category.toUpperCase(), style: TextStyle(color: deck.color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 15),
                Text(deck.title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text("${deck.cards.length} Cards", style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                const SizedBox(height: 15),
                LinearProgressIndicator(value: deck.progress, backgroundColor: textColor.withOpacity(0.05), color: deck.color, minHeight: 4, borderRadius: BorderRadius.circular(2)),
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
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final cardBg = Theme.of(context).cardColor;

    return Column(
      children: [
        // DECK HEADER
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: deck.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: deck.color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Mastery: ${(deck.progress * 100).toInt()}%", style: TextStyle(color: deck.color, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: deck.progress, color: deck.color, backgroundColor: Colors.black12)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Study"),
                style: ElevatedButton.styleFrom(backgroundColor: deck.color, foregroundColor: Colors.white),
                onPressed: () {
                  if (deck.cards.isNotEmpty) {
                    // Start Study
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

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Cards (${deck.cards.length})", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                onPressed: () => _showCardEditor(context, deck, null),
              )
            ],
          ),
        ),

        // CARD LIST
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: deck.cards.length,
            itemBuilder: (ctx, i) {
              final card = deck.cards[i];
              return Dismissible(
                key: Key(card.id),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) => provider.deleteCard(deck.id, card.id),
                child: GestureDetector(
                  onTap: () => _showCardEditor(context, deck, card),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: cardBg, 
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0,2))]
                    ),
                    child: Row(
                      children: [
                        Icon(card.masteryLevel > 0 ? Icons.check_circle : Icons.circle_outlined, color: deck.color, size: 20),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.question, style: TextStyle(color: textColor, fontWeight: FontWeight.bold), maxLines: 1),
                              Text(card.answer, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12), maxLines: 1),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: textColor.withOpacity(0.3), size: 16),
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
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final cardBg = Theme.of(context).cardColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(card == null ? "Add Card" : "Edit Card", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(controller: qCtrl, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: "Question (Front)", hintStyle: TextStyle(color: textColor.withOpacity(0.5)))),
            const SizedBox(height: 10),
            TextField(controller: aCtrl, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: "Answer (Back)", hintStyle: TextStyle(color: textColor.withOpacity(0.5)))),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              onPressed: () {
                if (card == null) {
                  provider.addCard(deck.id, qCtrl.text, aCtrl.text);
                } else {
                  provider.editCard(deck.id, card.id, qCtrl.text, aCtrl.text);
                }
                Navigator.pop(ctx);
              },
              child: const Text("Save Card"),
            )
          ],
        ),
      ),
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
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final cardBg = Theme.of(context).cardColor;

    if (_index >= _queue.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text("Session Complete!", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: widget.onExit, child: const Text("Finish"))
          ],
        ),
      );
    }

    final card = _queue[_index];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.close, color: textColor), onPressed: widget.onExit),
        title: Text("Card ${_index + 1}/${_queue.length}", style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
                  border: Border.all(color: widget.deck.color.withOpacity(0.5), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_showAnswer ? "ANSWER" : "QUESTION", style: TextStyle(color: widget.deck.color, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 30),
                    Text(
                      _showAnswer ? card.answer : card.question, 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)
                    ),
                    if (!_showAnswer)
                      Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Text("Tap to flip", style: TextStyle(color: textColor.withOpacity(0.3))),
                      )
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(heroTag: "miss", backgroundColor: Colors.redAccent, onPressed: () => _next(false), child: const Icon(Icons.close, color: Colors.white)),
              FloatingActionButton(heroTag: "hit", backgroundColor: Colors.greenAccent, onPressed: () => _next(true), child: const Icon(Icons.check, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}