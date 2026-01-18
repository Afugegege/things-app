import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/flashcard_model.dart';
import '../../providers/flashcards_provider.dart';
import '../../services/ai_service.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../providers/user_provider.dart';

class AiDeckReviewScreen extends StatefulWidget {
  final String topic;
  final List<Flashcard> initialCards;
  
  const AiDeckReviewScreen({
    super.key, 
    required this.topic,
    required this.initialCards,
  });

  @override
  State<AiDeckReviewScreen> createState() => _AiDeckReviewScreenState();
}

class _AiDeckReviewScreenState extends State<AiDeckReviewScreen> {
  late List<Flashcard> _cards;
  final TextEditingController _refineController = TextEditingController();
  bool _isRefining = false;

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.initialCards);
  }

  Future<void> _refineWithAi() async {
    if (_refineController.text.isEmpty) return;
    
    setState(() => _isRefining = true);
    
    // Build context for AI
    final currentCards = _cards.map((c) => '{"q":"${c.question}","a":"${c.answer}"}').join(',');
    final refinementPrompt = '''
Current flashcards: [$currentCards]

User request: ${_refineController.text}

Generate a NEW complete set of flashcards incorporating the user's feedback.
Return ONLY a JSON array: [{"q":"...","a":"..."},...]
''';

    try {
      final aiService = AiService();
      final response = await aiService.sendMessage(
        history: [],
        userMemories: [],
        mode: 'Assistant',
        contextData: refinementPrompt,
      );

      // Parse AI response
      String cleaned = response.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final List<dynamic> newCardsData = jsonDecode(cleaned);
      final newCards = newCardsData.map((c) => Flashcard(
        question: c['q'].toString(),
        answer: c['a'].toString(),
      )).toList();

      setState(() {
        _cards = newCards;
        _isRefining = false;
        _refineController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deck refined!'))
        );
      }
    } catch (e) {
      setState(() => _isRefining = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refinement failed: $e'))
        );
      }
    }
  }

  void _saveDeck() {
    if (_cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one card!'))
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25))
      ),
      builder: (ctx) => _SaveDeckDialog(
        topic: widget.topic,
        cards: _cards,
        onSave: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final accentColor = Provider.of<UserProvider>(context).accentColor;

    return LifeAppScaffold(
      title: 'AI REVIEW',
      useDrawer: false,
      actions: [
        IconButton(
          icon: Icon(CupertinoIcons.check_mark_circled_solid, color: accentColor),
          onPressed: _saveDeck,
        ),
      ],
      child: Column(
        children: [
          // Topic Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: GlassContainer(
              opacity: isDark ? 0.2 : 0.05,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                   Icon(CupertinoIcons.sparkles, color: accentColor, size: 28),
                   const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.topic.toUpperCase(),
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_cards.length} cards generated',
                          style: TextStyle(color: secondaryTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cards List
          Expanded(
            child: _cards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.square_stack_3d_up, size: 60, color: secondaryTextColor.withOpacity(0.3)),
                        const SizedBox(height: 20),
                        Text('No cards yet', style: TextStyle(color: secondaryTextColor)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 180),
                    itemCount: _cards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildCardItem(i),
                  ),
          ),
        ],
      ),
      bottomSheet: _buildRefineInput(),
    );
  }

  Widget _buildCardItem(int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final accentColor = Provider.of<UserProvider>(context).accentColor;

    return Dismissible(
      key: Key(_cards[index].id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      onDismissed: (_) => setState(() => _cards.removeAt(index)),
      child: GestureDetector(
        onTap: () => _editCard(index),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cards[index].question,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _cards[index].answer,
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, color: secondaryTextColor.withOpacity(0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefineInput() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final accentColor = Provider.of<UserProvider>(context).accentColor;

    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 65,
      borderRadius: 32,
      opacity: isDark ? 0.2 : 0.05,
      child: Row(
        children: [
          if (_isRefining)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(CupertinoIcons.chat_bubble_text, color: secondaryTextColor, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: TextField(
              controller: _refineController,
              enabled: !_isRefining,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Refine with AI (e.g., "Make them harder")',
                hintStyle: TextStyle(color: secondaryTextColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
              ),
              onSubmitted: (_) => _refineWithAi(),
            ),
          ),
          if (!_isRefining && _refineController.text.isNotEmpty)
            IconButton(
              icon: Icon(CupertinoIcons.paperplane_fill, color: accentColor),
              onPressed: _refineWithAi,
            ),
        ],
      ),
    );
  }

  void _editCard(int index) {
    final qCtrl = TextEditingController(text: _cards[index].question);
    final aCtrl = TextEditingController(text: _cards[index].answer);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25))
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
        final isDark = theme.brightness == Brightness.dark;
        final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
        final accentColor = Provider.of<UserProvider>(context).accentColor;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
            top: 20,
            left: 25,
            right: 25
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('EDIT CARD', style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 25),
              CupertinoTextField(
                controller: qCtrl,
                placeholder: 'Question',
                placeholderStyle: TextStyle(color: secondaryTextColor),
                style: TextStyle(color: textColor),
                decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(16),
              ),
              const SizedBox(height: 15),
              CupertinoTextField(
                controller: aCtrl,
                placeholder: 'Answer',
                placeholderStyle: TextStyle(color: secondaryTextColor),
                style: TextStyle(color: textColor),
                decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(16),
                maxLines: 3,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(15),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (qCtrl.text.isNotEmpty && aCtrl.text.isNotEmpty) {
                      setState(() {
                        _cards[index] = Flashcard(
                          id: _cards[index].id,
                          question: qCtrl.text,
                          answer: aCtrl.text,
                        );
                      });
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SaveDeckDialog extends StatefulWidget {
  final String topic;
  final List<Flashcard> cards;
  final VoidCallback onSave;

  const _SaveDeckDialog({
    required this.topic,
    required this.cards,
    required this.onSave,
  });

  @override
  State<_SaveDeckDialog> createState() => _SaveDeckDialogState();
}

class _SaveDeckDialogState extends State<_SaveDeckDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _categoryCtrl;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.topic);
    _categoryCtrl = TextEditingController(text: 'AI Generated');
    // Initialize color in build or didChangeDependencies to safely access Provider, or just use a default and set it later. 
    // Actually, we can't access context in initState. Let's make it nullable and set in build if null.
    // Simplifying: just default to purple, but in build we will use accentColor as one of the options.
    // Wait, let's just use purple as default, but ensure the user's accent color is the first option in the list!
    _selectedColor = Colors.purpleAccent; 
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedColor = Provider.of<UserProvider>(context, listen: false).accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
        top: 20,
        left: 25,
        right: 25
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('SAVE DECK', style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 25),
          CupertinoTextField(
            controller: _titleCtrl,
            placeholder: 'Deck Title',
            placeholderStyle: TextStyle(color: secondaryTextColor),
            style: TextStyle(color: textColor),
            decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
          ),
          const SizedBox(height: 15),
          CupertinoTextField(
            controller: _categoryCtrl,
            placeholder: 'Category',
            placeholderStyle: TextStyle(color: secondaryTextColor),
            style: TextStyle(color: textColor),
            decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(16),
          ),
          const SizedBox(height: 25),
          Text('COLOR LABEL', style: TextStyle(color: secondaryTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Provider.of<UserProvider>(context).accentColor,
              Colors.blueAccent,
              Colors.redAccent,
              Colors.greenAccent,
              Colors.orangeAccent,
              Colors.purpleAccent
            ].map((c) => GestureDetector(
              onTap: () => setState(() => _selectedColor = c),
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedColor == c ? c : Colors.transparent,
                    width: 2
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: _selectedColor,
              borderRadius: BorderRadius.circular(15),
              child: const Text('Save Deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                if (_titleCtrl.text.isNotEmpty) {
                  final newDeck = FlashcardDeck(
                    id: const Uuid().v4(),
                    title: _titleCtrl.text,
                    category: _categoryCtrl.text,
                    colorValue: _selectedColor.value,
                    cards: widget.cards,
                  );

                  Provider.of<FlashcardsProvider>(context, listen: false).addDeck(newDeck);
                  widget.onSave();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.cards.length} cards saved!'))
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
