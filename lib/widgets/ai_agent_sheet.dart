import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_model.dart';
import '../services/ai_service.dart';

class AIAgentSheet extends StatefulWidget {
  final String currentContent;
  final String? selectedText;
  final Function(String) onReplaceContent;
  final Function(String) onInsertContent;
  final Function(String)? onReplaceSelection;
  final String? initialAction; // [ADDED] Auto-run action

  const AIAgentSheet({
    super.key, 
    required this.currentContent,
    this.selectedText,
    required this.onReplaceContent,
    required this.onInsertContent,
    this.onReplaceSelection,
    this.initialAction,
  });

  @override
  State<AIAgentSheet> createState() => _AIAgentSheetState();
}

class _AIAgentSheetState extends State<AIAgentSheet> with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final AiService _aiService = AiService();
  final ScrollController _scrollController = ScrollController();
  
  String? _loadingStatus;
  Timer? _statusTimer;
  
  // Conversation state
  final List<_AIMessage> _messages = [];
  bool _showActions = true;

  @override
  void initState() {
    super.initState();
    // If there's selected text, show relevant context
    if (widget.selectedText != null && widget.selectedText!.isNotEmpty) {
      _showActions = true;
    }
    
    // [ADDED] Auto-run initial action if provided
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _executeAction(widget.initialAction!, _getLabelForAction(widget.initialAction!));
      });
    }
  }

  String _getLabelForAction(String action) {
    if (action == 'summarize') return "Summarize";
    if (action == 'continue') return "Continue writing";
    if (action == 'style') return "Format & Style"; // Label for style
    return "AI Action";
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // === CORE AI LOGIC ===
  
  Future<void> _runWithStatus(Future<String> Function() task, List<String> statuses) async {
    int statusIndex = 0;
    if (!mounted) return;
    setState(() {
      _loadingStatus = statuses.isNotEmpty ? statuses[0] : "Thinking...";
      _showActions = false;
    });

    if (statuses.length > 1) {
      _statusTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
        if (!mounted) { timer.cancel(); return; }
        statusIndex = (statusIndex + 1) % statuses.length;
        setState(() => _loadingStatus = statuses[statusIndex]);
      });
    }

    try {
      final result = await task();
      if (mounted) {
        setState(() {
          _messages.add(_AIMessage(
            text: result.startsWith("Error:") ? "⚠️ $result" : result,
            isUser: false,
            isError: result.startsWith("Error:"),
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_AIMessage(text: "⚠️ Error: $e", isUser: false, isError: true));
        });
      }
    } finally {
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
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendCustomPrompt() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    
    setState(() {
      _messages.add(_AIMessage(text: text, isUser: true));
    });
    _scrollToBottom();

    await _runWithStatus(() async {
      final history = _messages.map((m) => ChatMessage(
        id: DateTime.now().toString(),
        text: m.text,
        isUser: m.isUser,
        timestamp: DateTime.now(),
      )).toList();

      return await _aiService.sendMessage(
        history: history,
        userMemories: [],
        mode: 'Editor',
        contextData: widget.selectedText != null && widget.selectedText!.isNotEmpty
            ? "SELECTED TEXT:\n${widget.selectedText}\n\nFULL NOTE:\n${widget.currentContent}"
            : "CURRENT NOTE CONTENT:\n${widget.currentContent}",
      );
    }, ["Thinking...", "Processing your request...", "Generating response..."]);
  }

  Future<void> _executeAction(String action, String displayLabel) async {
    String prompt = "";
    List<String> statuses = [];
    final hasSelection = widget.selectedText != null && widget.selectedText!.isNotEmpty;
    final targetText = hasSelection ? widget.selectedText! : widget.currentContent;

    setState(() {
      _messages.add(_AIMessage(text: displayLabel, isUser: true));
    });
    _scrollToBottom();

    switch (action) {
      // ── EDIT ACTIONS ──
      case 'improve':
        prompt = "Improve the writing quality of the following text. Make it clearer, more concise, and better structured. Return ONLY the improved text:\n\n$targetText";
        statuses = ["Reading content...", "Improving writing...", "Polishing text..."];
        break;
      case 'fix_grammar':
        prompt = "Fix all grammar, spelling, and punctuation errors in the following text. Return ONLY the corrected text:\n\n$targetText";
        statuses = ["Scanning for errors...", "Fixing grammar...", "Polishing..."];
        break;
      case 'shorter':
        prompt = "Make the following text shorter and more concise without losing key information. Return ONLY the shortened text:\n\n$targetText";
        statuses = ["Analyzing content...", "Condensing text...", "Trimming..."];
        break;
      case 'longer':
        prompt = "Expand on the following text, adding more detail, examples, and depth. Return ONLY the expanded text:\n\n$targetText";
        statuses = ["Brainstorming...", "Adding detail...", "Expanding content..."];
        break;
        prompt = "Simplify the following text so it's easier to understand. Use simpler words and shorter sentences. Return ONLY the simplified text:\n\n$targetText";
        statuses = ["Reading content...", "Simplifying language...", "Making it clearer..."];
        break;
      case 'style':
        prompt = "Format the following text nicely using Markdown. Use headers, bullet points, bold text for emphasis, and make it look clean and structured. Return ONLY the formatted markdown text:\n\n$targetText";
        statuses = ["Analyzing structure...", "Applying formatting...", "Styling content..."];
        break;

      // ── TONE ACTIONS ──
      case 'professional':
        prompt = "Rewrite the following text in a professional, business-appropriate tone. Return ONLY the rewritten text:\n\n$targetText";
        statuses = ["Adjusting tone...", "Making it professional...", "Finalizing..."];
        break;
      case 'casual':
        prompt = "Rewrite the following text in a casual, friendly tone. Return ONLY the rewritten text:\n\n$targetText";
        statuses = ["Adjusting tone...", "Making it casual...", "Finalizing..."];
        break;
      case 'academic':
        prompt = "Rewrite the following text in an academic, scholarly tone. Return ONLY the rewritten text:\n\n$targetText";
        statuses = ["Adjusting tone...", "Adding formality...", "Finalizing..."];
        break;

      // ── GENERATE ACTIONS ──
      case 'summarize':
        prompt = "Summarize the following text into 3-5 concise bullet points. Return ONLY the bullet points:\n\n$targetText";
        statuses = ["Reading content...", "Identifying key points...", "Summarizing..."];
        break;
      case 'action_items':
        prompt = "Extract all action items and to-dos from the following text. Return them as a clean checklist:\n\n$targetText";
        statuses = ["Scanning for actions...", "Extracting tasks...", "Creating checklist..."];
        break;
      case 'continue':
        prompt = "Continue writing from where the following text ends. Match the style and topic:\n\n$targetText";
        statuses = ["Reading context...", "Generating ideas...", "Writing continuation..."];
        break;
      case 'explain':
        prompt = "Explain the following text in simple terms, as if explaining to someone unfamiliar with the topic:\n\n$targetText";
        statuses = ["Analyzing content...", "Simplifying concepts...", "Writing explanation..."];
        break;
      case 'translate_es':
        prompt = "Translate the following text to Spanish. Return ONLY the translation:\n\n$targetText";
        statuses = ["Translating...", "Processing language...", "Finalizing..."];
        break;
      case 'translate_fr':
        prompt = "Translate the following text to French. Return ONLY the translation:\n\n$targetText";
        statuses = ["Translating...", "Processing language...", "Finalizing..."];
        break;
      case 'translate_zh':
        prompt = "Translate the following text to Chinese. Return ONLY the translation:\n\n$targetText";
        statuses = ["Translating...", "Processing language...", "Finalizing..."];
        break;
      case 'translate_ja':
        prompt = "Translate the following text to Japanese. Return ONLY the translation:\n\n$targetText";
        statuses = ["Translating...", "Processing language...", "Finalizing..."];
        break;
      default:
        return;
    }

    await _runWithStatus(() async {
      final history = _messages.map((m) => ChatMessage(
        id: DateTime.now().toString(),
        text: m.text,
        isUser: m.isUser,
        timestamp: DateTime.now(),
      )).toList();

      return await _aiService.sendMessage(
        history: history,
        userMemories: [],
        mode: 'Editor',
        contextData: "CURRENT NOTE CONTENT:\n${widget.currentContent}",
      );
    }, statuses);
  }

  // === BUILD ===

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final inputBg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // ── HEADER ──
          _buildHeader(textColor, secondaryColor, isDark),
          
          // ── CONTENT ──
          Expanded(
            child: _messages.isEmpty && _showActions
                ? _buildActionGrid(textColor, secondaryColor, isDark, inputBg)
                : _buildConversation(textColor, secondaryColor, isDark),
          ),

          // ── LOADING STATUS ──
          if (_loadingStatus != null) _buildLoadingIndicator(isDark, secondaryColor),

          // ── INPUT BAR ──
          _buildInputBar(isDark, textColor, secondaryColor, inputBg),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color secondaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // AI Icon with glow
            // AI Icon with monochrome
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: textColor.withOpacity(0.1)),
              ),
              child: Icon(CupertinoIcons.sparkles, color: textColor, size: 16),
            ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("AI Assistant", style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15)),
              if (widget.selectedText != null && widget.selectedText!.isNotEmpty)
                Text(
                  "${widget.selectedText!.length} characters selected",
                  style: TextStyle(color: secondaryColor, fontSize: 11),
                ),
            ],
          ),
          const Spacer(),
          if (_messages.isNotEmpty)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("New chat", style: TextStyle(color: secondaryColor, fontSize: 12)),
              ),
              onPressed: () => setState(() {
                _messages.clear();
                _showActions = true;
              }),
            ),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minSize: 28,
            child: Icon(CupertinoIcons.xmark, color: secondaryColor, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(Color textColor, Color secondaryColor, bool isDark, Color inputBg) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        // Selected text preview
        if (widget.selectedText != null && widget.selectedText!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: secondaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.text_quote, size: 12, color: secondaryColor),
                    const SizedBox(width: 6),
                    Text("Selected text", style: TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.selectedText!,
                  style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],

        // ── EDIT SECTION ──
        _sectionLabel("Edit", CupertinoIcons.pencil, secondaryColor),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _actionButton("Improve writing", "improve", CupertinoIcons.sparkles, isDark),
            _actionButton("Fix grammar", "fix_grammar", CupertinoIcons.checkmark_circle, isDark),
            _actionButton("Make shorter", "shorter", CupertinoIcons.minus_circle, isDark),
            _actionButton("Make longer", "longer", CupertinoIcons.plus_circle, isDark),
            _actionButton("Simplify", "simplify", CupertinoIcons.lightbulb, isDark),
            _actionButton("Fix Styling", "style", CupertinoIcons.paintbrush, isDark), // [ADDED]
          ],
        ),

        const SizedBox(height: 20),

        // ── TONE SECTION ──
        _sectionLabel("Change tone", CupertinoIcons.speaker_2, secondaryColor),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _actionButton("Professional", "professional", CupertinoIcons.briefcase, isDark),
            _actionButton("Casual", "casual", CupertinoIcons.hand_thumbsup, isDark),
            _actionButton("Academic", "academic", CupertinoIcons.book, isDark),
          ],
        ),

        const SizedBox(height: 20),

        // ── GENERATE SECTION ──
        _sectionLabel("Generate from note", CupertinoIcons.wand_stars, secondaryColor),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _actionButton("Summarize", "summarize", CupertinoIcons.doc_plaintext, isDark),
            _actionButton("Action items", "action_items", CupertinoIcons.checkmark_square, isDark),
            _actionButton("Continue writing", "continue", CupertinoIcons.arrow_right, isDark),
            _actionButton("Explain this", "explain", CupertinoIcons.question_circle, isDark),
          ],
        ),

        const SizedBox(height: 20),

        // ── TRANSLATE SECTION ──
        _sectionLabel("Translate", CupertinoIcons.globe, secondaryColor),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _actionButton("Spanish", "translate_es", CupertinoIcons.globe, isDark),
            _actionButton("French", "translate_fr", CupertinoIcons.globe, isDark),
            _actionButton("Chinese", "translate_zh", CupertinoIcons.globe, isDark),
            _actionButton("Japanese", "translate_ja", CupertinoIcons.globe, isDark),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _actionButton(String label, String action, IconData icon, bool isDark) {
    return GestureDetector(
      onTap: _loadingStatus != null ? null : () => _executeAction(action, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white70 : Colors.black54),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(Color textColor, Color secondaryColor, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg, isDark, textColor, secondaryColor);
      },
    );
  }

  Widget _buildMessageBubble(_AIMessage msg, bool isDark, Color textColor, Color secondaryColor) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.person_fill, size: 14, color: secondaryColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(msg.text, style: TextStyle(color: textColor, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    // AI response
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI label
          Row(
            children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(CupertinoIcons.sparkles, color: textColor, size: 11),
              ),
              const SizedBox(width: 6),
              Text("AI", style: TextStyle(color: secondaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          
          // Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
            ),
            child: MarkdownBody(
              data: msg.text,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: textColor, fontSize: 14, height: 1.6),
                listBullet: TextStyle(color: textColor),
                h1: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                h2: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
                h3: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                code: TextStyle(color: textColor, backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                blockquote: TextStyle(color: textColor.withOpacity(0.7), fontStyle: FontStyle.italic),
              ),
            ),
          ),

          // ACTION BUTTONS (Notion-style)
          if (!msg.isError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _responseAction("Replace all", CupertinoIcons.arrow_2_squarepath, () {
                    widget.onReplaceContent(msg.text);
                  }, isDark),
                  const SizedBox(width: 6),
                  _responseAction("Insert below", CupertinoIcons.plus_square, () {
                    widget.onInsertContent(msg.text);
                  }, isDark),
                  if (widget.onReplaceSelection != null && widget.selectedText != null) ...[
                    const SizedBox(width: 6),
                    _responseAction("Replace selection", CupertinoIcons.text_cursor, () {
                      widget.onReplaceSelection!(msg.text);
                    }, isDark),
                  ],
                  const Spacer(),
                  _iconAction(CupertinoIcons.doc_on_doc, () {
                    // Copy to clipboard — no external dep needed
                  }, isDark),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _responseAction(String label, IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: () {
        onTap();
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isDark ? Colors.white60 : Colors.black54),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.black38),
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark, Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 20, height: 20,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: CircularProgressIndicator(strokeWidth: 1.5, color: secondaryColor),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _loadingStatus!,
              key: ValueKey(_loadingStatus),
              style: TextStyle(color: secondaryColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, Color textColor, Color secondaryColor, Color inputBg) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: widget.selectedText != null 
                      ? "Ask AI about selection..." 
                      : "Ask AI anything...",
                  hintStyle: TextStyle(color: secondaryColor.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Icon(CupertinoIcons.sparkles, size: 16, color: textColor.withOpacity(0.6)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 0),
                ),
                onSubmitted: (_) => _sendCustomPrompt(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loadingStatus != null ? null : _sendCustomPrompt,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _loadingStatus != null ? Colors.grey.withOpacity(0.3) : textColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(CupertinoIcons.arrow_up, color: isDark ? Colors.black : Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple message model for AI sheet
class _AIMessage {
  final String text;
  final bool isUser;
  final bool isError;

  _AIMessage({required this.text, required this.isUser, this.isError = false});
}
