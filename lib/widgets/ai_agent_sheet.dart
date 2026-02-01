import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_model.dart';
import '../services/ai_service.dart';

class AIAgentSheet extends StatefulWidget {
  final String currentContent;
  final Function(String) onReplaceContent;
  final Function(String) onInsertContent;

  const AIAgentSheet({
    super.key, 
    required this.currentContent,
    required this.onReplaceContent,
    required this.onInsertContent,
  });

  @override
  State<AIAgentSheet> createState() => _AIAgentSheetState();
}

class _AIAgentSheetState extends State<AIAgentSheet> {
  final TextEditingController _inputController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final AiService _aiService = AiService();
  final ScrollController _scrollController = ScrollController();
  
  // New Status Tracking
  String? _loadingStatus; 
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      id: 'welcome',
      text: "I'm here to help with your note. Ask me to rewrite, summarize, or expand on anything.",
      isUser: false,
      timestamp: DateTime.now()
    ));
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Orchestrates the status messages while waiting for the Future
  Future<void> _runWithStatus(Future<String> Function() task, List<String> statuses) async {
    int statusIndex = 0;
    
    // START LOADING:
    if (!mounted) return;
    setState(() {
      _loadingStatus = statuses.isNotEmpty ? statuses[0] : "Thinking...";
    });

    // START TIMER:
    if (statuses.length > 1) {
      _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        if (!mounted) {
           timer.cancel();
           return;
        }
        statusIndex = (statusIndex + 1) % statuses.length;
        setState(() => _loadingStatus = statuses[statusIndex]);
      });
    }

    try {
      // EXECUTE TASK:
      final result = await task();
      
      // SUCCESS:
      if (mounted) {
        setState(() {
          // If result indicates error from Service layer (starts with "Error:")
          if (result.startsWith("Error:")) {
             // Treat as error message but show in chat
             _messages.add(ChatMessage(id: DateTime.now().toString(), text: "⚠️ $result", isUser: false, timestamp: DateTime.now()));
          } else {
             // Normal success
             _messages.add(ChatMessage(id: DateTime.now().toString(), text: result, isUser: false, timestamp: DateTime.now()));
          }
        });
      }
    } catch (e) {
      // EXCEPTION:
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(id: DateTime.now().toString(), text: "⚠️ Error: $e", isUser: false, timestamp: DateTime.now()));
        });
      }
    } finally {
      // CLEANUP:
      _statusTimer?.cancel();
      if (mounted) {
        setState(() => _loadingStatus = null);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOut
        );
      }
    });
  }

  Future<void> _sendMessage({String? predefinedText, List<String>? customStatuses}) async {
    final text = predefinedText ?? _inputController.text.trim();
    if (text.isEmpty) return;

    if (predefinedText == null) _inputController.clear();
    
    setState(() {
      _messages.add(ChatMessage(id: DateTime.now().toString(), text: text, isUser: true, timestamp: DateTime.now()));
    });
    _scrollToBottom();

    final statuses = customStatuses ?? ["Thinking...", "Analyzing request...", "Generating response..."];

    await _runWithStatus(() async {
      return await _aiService.sendMessage(
        history: _messages,
        userMemories: [],
        mode: 'Editor', // [CHANGED] Use 'Editor' mode for cleaner content generation
        contextData: "CURRENT NOTE CONTENT:\n${widget.currentContent}",
      );
    }, statuses);
  }

  void _handleAction(String action) {
    String prompt = "";
    List<String> statuses = [];

    switch (action) {
      case 'summarize':
        prompt = "Summarize the current note content in 3 bullet points.";
        statuses = ["Reading note...", "Analyzing key points...", "Summarizing context..."];
        break;
      case 'fix':
        prompt = "Fix grammar and spelling in the current note content. Return ONLY the corrected text.";
        statuses = ["Reading note...", "Checking grammar...", "Polishing text...", "Finalizing edits..."];
        break;
      case 'longer':
        prompt = "Expand on the current note content, making it more detailed. Return ONLY the new content.";
        statuses = ["Brainstorming ideas...", "Expanding specific sections...", "Adding details...", "Writing content..."];
        break;
      case 'continue':
        prompt = "Continue writing from where the current note ends.";
        statuses = ["Reading previous context...", "Generating ideas...", "Drafting continuation...", "Writing..."];
        break;
    }
    _sendMessage(predefinedText: prompt, customStatuses: statuses);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Tall sheet
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                const Text("AI Editor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessage(msg, isDark);
              },
            ),
          ),

          // STATUS INDICATOR
          if (_loadingStatus != null)
             Container(
               margin: const EdgeInsets.symmetric(vertical: 10),
               padding: const EdgeInsets.fromLTRB(16, 8, 20, 8),
               decoration: BoxDecoration(
                 color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[100],
                 borderRadius: BorderRadius.circular(20),
                 boxShadow: [
                   BoxShadow(blurRadius: 10, color: Colors.purple.withOpacity(0.1), spreadRadius: 1)
                 ]
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   SizedBox(
                     width: 14, height: 14, 
                     child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent)
                   ),
                   const SizedBox(width: 10),
                   AnimatedSwitcher(
                     duration: const Duration(milliseconds: 300),
                     child: Text(
                       _loadingStatus!, 
                       key: ValueKey(_loadingStatus),
                       style: TextStyle(
                         color: theme.textTheme.bodyMedium?.color, 
                         fontSize: 12, 
                         fontWeight: FontWeight.w600
                       )
                     ),
                   ),
                 ],
               ),
             ),

          // Quick Actions (Horizontal Scroll)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _actionChip("Summarize", "summarize", theme),
                _actionChip("Fix Grammar", "fix", theme),
                _actionChip("Make Longer", "longer", theme),
                _actionChip("Continue Writing", "continue", theme),
              ],
            ),
          ),

          // Input Area
          Padding(
            padding: EdgeInsets.only(
              left: 16, 
              right: 16, 
              bottom: MediaQuery.of(context).viewInsets.bottom + 16, 
              top: 8
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: "Ask AI to edit...",
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.arrow_upward, color: Colors.white),
                  onPressed: () => _sendMessage(),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String label, String action, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () => _handleAction(action),
        backgroundColor: theme.canvasColor,
        side: BorderSide(color: theme.dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg, bool isDark) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser 
              ? Colors.blueAccent 
              : (isDark ? const Color(0xFF2C2C2E) : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: Colors.purple), 
                  SizedBox(width: 4), 
                  Text("AI Assistant", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple))
                ],
              ),
              const SizedBox(height: 4),
            ],
            
            MarkdownBody(
              data: msg.text, 
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 15),
              )
            ),

            if (!isUser)
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   _msgActionButton("Replace Note", Icons.copy, () {
                      Navigator.pop(context); // Close sheet so user sees the change
                      widget.onReplaceContent(msg.text);
                   }),
                   const SizedBox(width: 8),
                   _msgActionButton("Insert Below", Icons.add_circle_outline, () {
                      Navigator.pop(context);
                      widget.onInsertContent(msg.text);
                   }),
                 ],
               ),
             )
          ],
        ),
      ),
    );
  }

  Widget _msgActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
