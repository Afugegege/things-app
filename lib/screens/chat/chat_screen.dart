import '../../widgets/confirmation_card.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/tasks_provider.dart'; 
import '../../models/chat_model.dart';
import '../../models/note_model.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/chat_preview_card.dart';
import '../../utils/json_cleaner.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  String _suggestionQuery = "";
  
  // Follow-up Logic
  bool _isRefining = false;
  String? _pendingActionId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  // --- SMART SUGGESTION LOGIC ---
  void _onTextChanged() {
    final text = _controller.text;

    if (text.isEmpty) {
      if (_showSuggestions) setState(() => _showSuggestions = false);
      return;
    }

    final match = RegExp(r'(?:^|\s)to\s+(.*?)$', caseSensitive: false).firstMatch(text);

    if (match != null) {
      final query = match.group(1) ?? "";
      setState(() {
        _suggestionQuery = query;
        _showSuggestions = true;
        _updateSuggestions(query);
      });
    } else {
      if (_showSuggestions) setState(() => _showSuggestions = false);
    }
  }

  void _updateSuggestions(String query) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);

    final noteTitles = notesProvider.notes.map((n) => "📝 ${n.title}").toList();
    final taskTitles = tasksProvider.tasks.map((t) => "✅ ${t.title}").toList();
    
    final allItems = [...noteTitles, ...taskTitles];

    setState(() {
      _suggestions = allItems
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .take(5) 
          .toList();
    });
  }

  void _applySuggestion(String suggestion) {
    final cleanName = suggestion.substring(2).trim(); 
    final text = _controller.text;
    
    final newText = text.replaceFirst(
      RegExp(r'to\s+'+ RegExp.escape(_suggestionQuery) + r'$', caseSensitive: false), 
      "to \"$cleanName\" "
    );

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    
    setState(() => _showSuggestions = false);
  }

  void _handleSend() async {
    if (_controller.text.trim().isEmpty) return;
    
    final text = _controller.text;
    _controller.clear();
    setState(() {
      _showSuggestions = false;
      _isRefining = false; // Reset state after sending
      _pendingActionId = null;
    });
    FocusScope.of(context).unfocus();

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await chatProvider.sendMessage(
      message: text,
      userMemories: userProvider.user.aiMemory,
    );
  }

  // --- MODIFIED MESSAGE RENDERER ---
  Widget _buildAiMessageContent(String text, String msgId) {
    try {
      if (text.trim().startsWith('{')) {
        final cleanText = JsonCleaner.clean(text);
        final Map<String, dynamic> data = jsonDecode(cleanText);
        String status = data['status'] ?? 'pending';

        if (status == 'loading') {
          return Container(
            key: const ValueKey("loading"),
            height: 60,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: Colors.white),
          );
        }

        if (status == 'success') {
          return Container(
            key: const ValueKey("success"),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Row(
               children: [
                 const Icon(Icons.check_circle, color: Colors.green),
                 const SizedBox(width: 10),
                 Expanded(child: Text("Action Completed: ${data['action']?.toString().replaceAll('_', ' ').toUpperCase()}", style: const TextStyle(color: Colors.white))),
               ]
            ),
          );
        }

        // PENDING STATE -> PREVIEW CARD
        // Use ChatPreviewCard for Notes, simple ConfirmationCard for Tasks/Money
        if (data['action'] == 'create_note' || data['action'] == 'edit_note') {
           return ChatPreviewCard(
             data: data,
             onSave: () {
               Provider.of<ChatProvider>(context, listen: false).executeCommand(msgId, data, context);
             },
             onEdit: () {
               setState(() {
                 _isRefining = true;
                 _pendingActionId = msgId;
                 _controller.text = "Make it "; // Context helper
                 FocusScope.of(context).requestFocus();
               });
             },
           );
        } else {
           // Fallback for non-visual tasks (Tasks, Money)
           return ConfirmationCard(
              action: data['action'].toString(),
              details: "Action: ${data['title'] ?? 'Update Item'}",
              onConfirm: () => Provider.of<ChatProvider>(context, listen: false).executeCommand(msgId, data, context),
              onCancel: () {}, // Can add logic to delete message
           );
        }
      }
    } catch (e) {
      // Not JSON, just text
    }
    return Text(text, style: const TextStyle(color: Colors.white));
  }

  void _showMessageOptions(BuildContext context, ChatMessage msg) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (ctx) => Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Message Options", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (!msg.isUser)
              ListTile(
                leading: const Icon(Icons.save_alt, color: Colors.amber),
                title: const Text("Save as Note", style: TextStyle(color: Colors.white)),
                onTap: () {
                  chatProvider.saveMessageAsNote(msg.text, notesProvider);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved to Notes!")));
                },
              ),
            ListTile(
              leading: const Icon(CupertinoIcons.delete, color: Colors.red),
              title: const Text("Delete Message", style: TextStyle(color: Colors.red)),
              onTap: () {
                chatProvider.deleteMessage(msg.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double inputBottomPosition = 120.0 + (keyboardHeight > 0 ? keyboardHeight - 100 : 0);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          // Chat List
          Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("AI Companion", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(CupertinoIcons.sparkles, color: Colors.white),
                      onPressed: () {},
                    )
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, inputBottomPosition + 120),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = chatProvider.messages[i];
                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(context, msg),
                      child: Align(
                        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(15),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                          decoration: BoxDecoration(
                            color: msg.isUser ? Colors.white : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(msg.isUser ? 20 : 5),
                              bottomRight: Radius.circular(msg.isUser ? 5 : 20),
                            ),
                          ),
                          child: msg.isUser 
                              ? Text(msg.text, style: const TextStyle(color: Colors.black))
                              : _buildAiMessageContent(msg.text, msg.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // AUTOCOMPLETE SUGGESTIONS
          if (_showSuggestions && _suggestions.isNotEmpty)
            Positioned(
              bottom: inputBottomPosition + 120, 
              left: 25,
              right: 25,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(15, 10, 15, 5),
                        child: Text("SUGGESTED TARGETS", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          itemBuilder: (ctx, i) {
                            return ListTile(
                              dense: true,
                              title: Text(_suggestions[i], style: const TextStyle(color: Colors.white)),
                              onTap: () => _applySuggestion(_suggestions[i]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // INPUT AREA
          Positioned(
            bottom: inputBottomPosition,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // REFINING INDICATOR
                if (_isRefining)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit, color: Colors.white, size: 14),
                        const SizedBox(width: 8),
                        const Text("Refining previous action...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _isRefining = false),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        )
                      ],
                    ),
                  ),

                // ACTION CHIPS BAR
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      _buildActionChip("✨ Modify", () => _controller.text = "Modify note to "), 
                      _buildActionChip("✅ To-Do", () => _controller.text = "Add task to "),
                      _buildActionChip("💰 Expense", () => _controller.text = "Log expense to "),
                      _buildActionChip("🎨 Theme", () => _controller.text = "Change theme to "),
                    ],
                  ),
                ),

                // TEXT FIELD
                GlassContainer(
                  height: 60,
                  borderRadius: 30,
                  blur: 20,
                  opacity: 0.15,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Tell me what to do...", 
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_upward, color: Colors.black),
                          onPressed: _handleSend,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}