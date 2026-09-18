import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_model.dart';
import '../services/ai_service.dart';
import '../services/ai_templates.dart';

class AIAgentSheet extends StatefulWidget {
  final String currentContent;
  final String? selectedText;
  final Function(String) onReplaceContent;
  final Function(String) onInsertContent;
  final Function(String)? onReplaceSelection;
  final Function(String suggestedText, {String? targetText})? onPreviewEdit;
  final VoidCallback? onClearSelection;
  final String? initialAction;

  const AIAgentSheet({
    super.key,
    required this.currentContent,
    this.selectedText,
    required this.onReplaceContent,
    required this.onInsertContent,
    this.onReplaceSelection,
    this.onPreviewEdit,
    this.onClearSelection,
    this.initialAction,
  });

  @override
  State<AIAgentSheet> createState() => _AIAgentSheetState();
}

class _AIAgentSheetState extends State<AIAgentSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final AiService _aiService = AiService();
  final ScrollController _scrollController = ScrollController();

  String? _loadingStatus;
  Timer? _statusTimer;

  // Selected tab category index: 0=Quick, 1=Writing, 2=Tone, 3=Insights, 4=Translate, 5=Templates
  int _selectedCategory = 0;

  // Conversation state
  final List<_AIMessage> _messages = [];
  bool _showActions = true;

  @override
  void initState() {
    super.initState();

    // Auto-run initial action if provided
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _executeAction(
            widget.initialAction!, _getLabelForAction(widget.initialAction!));
      });
    }
  }

  String _getLabelForAction(String action) {
    switch (action) {
      case 'summarize':
        return "Summarize";
      case 'continue':
        return "Continue writing";
      case 'style':
        return "Format & Style";
      case 'improve':
        return "Improve writing";
      case 'fix_grammar':
        return "Fix grammar";
      default:
        return "AI Action";
    }
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

  Future<void> _runWithStatus(
      Future<String> Function() task, List<String> statuses) async {
    int statusIndex = 0;
    if (!mounted) return;
    setState(() {
      _loadingStatus = statuses.isNotEmpty ? statuses[0] : "Thinking...";
      _showActions = false;
    });

    if (statuses.length > 1) {
      _statusTimer =
          Timer.periodic(const Duration(milliseconds: 1600), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        statusIndex = (statusIndex + 1) % statuses.length;
        setState(() => _loadingStatus = statuses[statusIndex]);
      });
    }

    try {
      final result = await task();
      if (mounted) {
        setState(() {
          _messages.add(_AIMessage(
            text: result,
            isUser: false,
            isError: result.startsWith("Error:"),
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
              _AIMessage(text: "Error: $e", isUser: false, isError: true));
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
      final history = _messages
          .map((m) => ChatMessage(
                id: DateTime.now().toString(),
                text: m.text,
                isUser: m.isUser,
                timestamp: DateTime.now(),
              ))
          .toList();

      return await _aiService.sendMessage(
        history: history,
        userMemories: [],
        mode: 'Editor',
        contextData: widget.selectedText != null &&
                widget.selectedText!.isNotEmpty
            ? "SELECTED TEXT:\n${widget.selectedText}\n\nFULL NOTE:\n${widget.currentContent}"
            : "CURRENT NOTE CONTENT:\n${widget.currentContent}",
      );
    }, ["Thinking...", "Processing your request...", "Generating response..."]);
  }

  Future<void> _executeAction(String action, String displayLabel) async {
    String prompt = "";
    List<String> statuses = [];
    final hasSelection =
        widget.selectedText != null && widget.selectedText!.isNotEmpty;
    final targetText =
        hasSelection ? widget.selectedText! : widget.currentContent;

    setState(() {
      _messages.add(_AIMessage(text: displayLabel, isUser: true));
    });
    _scrollToBottom();

    switch (action) {
      // ── EDIT ACTIONS ──
      case 'improve':
        prompt =
            "Improve the writing quality of the following text. Make it clearer, more concise, and better structured. Return ONLY the improved text:\n\n$targetText";
        statuses = [
          "Reading content...",
          "Improving writing...",
          "Polishing text..."
        ];
        break;
      case 'fix_grammar':
        prompt =
            "Fix all grammar, spelling, and punctuation errors in the following text. Return ONLY the corrected text:\n\n$targetText";
        statuses = [
          "Scanning for errors...",
          "Fixing grammar...",
          "Polishing..."
        ];
        break;
      case 'shorter':
        prompt =
            "Make the following text shorter and more concise without losing key information. Return ONLY the shortened text:\n\n$targetText";
        statuses = [
          "Analyzing content...",
          "Condensing text...",
          "Trimming..."
        ];
        break;
      case 'longer':
        prompt =
            "Expand on the following text, adding more detail, examples, and depth. Return ONLY the expanded text:\n\n$targetText";
        statuses = [
          "Brainstorming...",
          "Adding detail...",
          "Expanding content..."
        ];
        break;
      case 'simplify':
        prompt =
            "Simplify the following text so it's easier to understand. Use simpler words and shorter sentences. Return ONLY the simplified text:\n\n$targetText";
        statuses = [
          "Reading content...",
          "Simplifying language...",
          "Making it clearer..."
        ];
        break;
      case 'style':
        prompt =
            "Format the following text nicely using Markdown. Use headers, bullet points, bold text for emphasis, and make it look clean and structured. Return ONLY the formatted markdown text:\n\n$targetText";
        statuses = [
          "Analyzing structure...",
          "Applying formatting...",
          "Styling content..."
        ];
        break;

      // ── TONE ACTIONS ──
      case 'professional':
        prompt =
            "Rewrite the following text in a professional, business-appropriate tone. Return ONLY the rewritten text:\n\n$targetText";
        statuses = [
          "Adjusting tone...",
          "Making it professional...",
          "Finalizing..."
        ];
        break;
      case 'casual':
        prompt =
            "Rewrite the following text in a casual, friendly tone. Return ONLY the rewritten text:\n\n$targetText";
        statuses = [
          "Adjusting tone...",
          "Making it casual...",
          "Finalizing..."
        ];
        break;
      case 'academic':
        prompt =
            "Rewrite the following text in an academic, scholarly tone. Return ONLY the rewritten text:\n\n$targetText";
        statuses = [
          "Adjusting tone...",
          "Adding formality...",
          "Finalizing..."
        ];
        break;

      // ── GENERATE ACTIONS ──
      case 'summarize':
        prompt =
            "Summarize the following text into 3-5 concise bullet points. Return ONLY the bullet points:\n\n$targetText";
        statuses = [
          "Reading content...",
          "Identifying key points...",
          "Summarizing..."
        ];
        break;
      case 'action_items':
        prompt =
            "Extract all action items and to-dos from the following text. Return them as a clean checklist:\n\n$targetText";
        statuses = [
          "Scanning for actions...",
          "Extracting tasks...",
          "Creating checklist..."
        ];
        break;
      case 'continue':
        prompt =
            "Continue writing from where the following text ends. Match the style and topic:\n\n$targetText";
        statuses = [
          "Reading context...",
          "Generating ideas...",
          "Writing continuation..."
        ];
        break;
      case 'explain':
        prompt =
            "Explain the following text in simple terms, as if explaining to someone unfamiliar with the topic:\n\n$targetText";
        statuses = [
          "Analyzing content...",
          "Simplifying concepts...",
          "Writing explanation..."
        ];
        break;

      // ── TRANSLATE ACTIONS ──
      case 'translate_es':
        prompt =
            "Translate the following text to Spanish. Return ONLY the translation:\n\n$targetText";
        statuses = ["Translating to Spanish...", "Finalizing..."];
        break;
      case 'translate_fr':
        prompt =
            "Translate the following text to French. Return ONLY the translation:\n\n$targetText";
        statuses = ["Translating to French...", "Finalizing..."];
        break;
      case 'translate_zh':
        prompt =
            "Translate the following text to Chinese. Return ONLY the translation:\n\n$targetText";
        statuses = ["Translating to Chinese...", "Finalizing..."];
        break;
      case 'translate_ja':
        prompt =
            "Translate the following text to Japanese. Return ONLY the translation:\n\n$targetText";
        statuses = ["Translating to Japanese...", "Finalizing..."];
        break;
      default:
        return;
    }

    await _runWithStatus(() async {
      final history = _messages
          .map((m) => ChatMessage(
                id: DateTime.now().toString(),
                text: m.text,
                isUser: m.isUser,
                timestamp: DateTime.now(),
              ))
          .toList();

      return await _aiService.sendMessage(
        history: history,
        userMemories: [],
        mode: 'Editor',
        contextData: prompt,
      );
    }, statuses);
  }

  Future<void> _executeTemplate(AiTemplate tpl) async {
    setState(() {
      _messages.add(_AIMessage(
          text: "${tpl.icon} Generate ${tpl.title}", isUser: true));
    });
    _scrollToBottom();

    await _runWithStatus(() async {
      final history = _messages
          .map((m) => ChatMessage(
                id: DateTime.now().toString(),
                text: m.text,
                isUser: m.isUser,
                timestamp: DateTime.now(),
              ))
          .toList();

      return await _aiService.sendMessage(
        history: history,
        userMemories: [],
        mode: 'Editor',
        contextData:
            "${tpl.defaultPrompt}\n\nCURRENT NOTE CONTENT:\n${widget.currentContent}",
      );
    }, [
      "Analyzing template structure...",
      "Generating ${tpl.title}...",
      "Formatting structured note..."
    ]);
  }

  // === BUILD ===

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87);
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white60 : Colors.black54);
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? Colors.white.withOpacity(0.06) : Colors.white;
    final inputBg = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      height: MediaQuery.of(context).size.height * (isLandscape ? 0.90 : 0.72),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── TOP DRAG HANDLE ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // ── MINIMALIST IOS HEADER ──
          _buildHeader(textColor, secondaryColor, isDark),

          // ── SELECTED TEXT CONTEXT BADGE ──
          if (widget.selectedText != null && widget.selectedText!.isNotEmpty)
            _buildSelectionBadge(textColor, secondaryColor, isDark),

          // ── CONTENT ──
          Expanded(
            child: _messages.isEmpty && _showActions
                ? _buildMinimalistActionView(textColor, secondaryColor, isDark, cardBg)
                : _buildConversation(textColor, secondaryColor, isDark),
          ),

          // ── LOADING STATUS ──
          if (_loadingStatus != null)
            _buildLoadingIndicator(secondaryColor),

          // ── INPUT BAR ──
          _buildInputBar(isDark, textColor, secondaryColor, inputBg),
        ],
      ),
    );
  }

  // ── MINIMALIST HEADER ──
  Widget _buildHeader(Color textColor, Color secondaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
      child: Row(
        children: [
          // Sparkle icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.sparkles, color: textColor, size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            "Writing Tools",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (_messages.isNotEmpty)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              child: Icon(CupertinoIcons.arrow_counterclockwise,
                  color: secondaryColor, size: 18),
              onPressed: () => setState(() {
                _messages.clear();
                _showActions = true;
              }),
            ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            child: Icon(CupertinoIcons.xmark_circle_fill,
                color: secondaryColor.withOpacity(0.4), size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── SELECTION BADGE ──
  Widget _buildSelectionBadge(
      Color textColor, Color secondaryColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.text_quote, size: 13, color: secondaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.selectedText!,
              style: TextStyle(
                  color: textColor.withOpacity(0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${widget.selectedText!.length} chars",
              style: TextStyle(
                  color: secondaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (widget.onClearSelection != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: widget.onClearSelection,
              child: Icon(CupertinoIcons.xmark_circle_fill,
                  size: 14, color: secondaryColor.withOpacity(0.5)),
            ),
          ],
        ],
      ),
    );
  }

  // ── MINIMALIST ACTION VIEW (CATEGORY TABS + CLEAN TILES) ──
  Widget _buildMinimalistActionView(
      Color textColor, Color secondaryColor, bool isDark, Color cardBg) {
    return Column(
      children: [
        // ── CATEGORY TAB FILTER ROW ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _categoryChip(0, "Quick", isDark, textColor, secondaryColor),
              const SizedBox(width: 6),
              _categoryChip(1, "Write", isDark, textColor, secondaryColor),
              const SizedBox(width: 6),
              _categoryChip(2, "Tone", isDark, textColor, secondaryColor),
              const SizedBox(width: 6),
              _categoryChip(3, "Insights", isDark, textColor, secondaryColor),
              const SizedBox(width: 6),
              _categoryChip(4, "Translate", isDark, textColor, secondaryColor),
              const SizedBox(width: 6),
              _categoryChip(5, "Templates", isDark, textColor, secondaryColor),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ── ACTION TILES LIST ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              if (_selectedCategory == 0) ..._buildQuickCategory(textColor, secondaryColor, isDark, cardBg),
              if (_selectedCategory == 1) ..._buildWriteCategory(textColor, secondaryColor, isDark, cardBg),
              if (_selectedCategory == 2) ..._buildToneCategory(textColor, secondaryColor, isDark, cardBg),
              if (_selectedCategory == 3) ..._buildInsightsCategory(textColor, secondaryColor, isDark, cardBg),
              if (_selectedCategory == 4) ..._buildTranslateCategory(textColor, secondaryColor, isDark, cardBg),
              if (_selectedCategory == 5) ..._buildTemplatesCategory(textColor, secondaryColor, isDark, cardBg),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(int index, String label, bool isDark, Color textColor, Color secondaryColor) {
    final isSelected = _selectedCategory == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? textColor
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? textColor
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : secondaryColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── QUICK CATEGORY (TOP ESSENTIAL TOOLS) ──
  List<Widget> _buildQuickCategory(Color textColor, Color secondaryColor, bool isDark, Color cardBg) {
    return [
      _iosTile("Proofread", "Fix spelling, grammar & punctuation",
          CupertinoIcons.checkmark_seal, 'fix_grammar', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Rewrite", "Improve writing quality & flow",
          CupertinoIcons.wand_stars, 'improve', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Summarize", "Key bullet points & summary",
          CupertinoIcons.doc_text, 'summarize', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Continue writing", "Generate natural continuation",
          CupertinoIcons.arrow_right_circle, 'continue', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Format & Style", "Structure with titles & lists",
          CupertinoIcons.paintbrush, 'style', textColor, secondaryColor, cardBg, isDark),
    ];
  }

  // ── WRITE CATEGORY ──
  List<Widget> _buildWriteCategory(Color textColor, Color secondaryColor, bool isDark, Color cardBg) {
    return [
      _iosTile("Improve writing", "Enhance tone & sentence flow",
          CupertinoIcons.sparkles, 'improve', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Fix grammar", "Correct spelling & grammar errors",
          CupertinoIcons.checkmark_circle, 'fix_grammar', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Make shorter", "Condense and remove fluff",
          CupertinoIcons.minus_circle, 'shorter', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Make longer", "Add detail, depth & explanations",
          CupertinoIcons.plus_circle, 'longer', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Simplify", "Use simpler vocabulary & sentences",
          CupertinoIcons.lightbulb, 'simplify', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Format & Style", "Organize with clean markdown styling",
          CupertinoIcons.paintbrush, 'style', textColor, secondaryColor, cardBg, isDark),
    ];
  }

  // ── TONE CATEGORY ──
  List<Widget> _buildToneCategory(Color textColor, Color secondaryColor, bool isDark, Color cardBg) {
    return [
      _iosTile("Professional", "Clear, formal & business-ready",
          CupertinoIcons.briefcase, 'professional', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Casual", "Friendly, warm & natural tone",
          CupertinoIcons.hand_thumbsup, 'casual', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Academic", "Scholarly, authoritative & detailed",
          CupertinoIcons.book, 'academic', textColor, secondaryColor, cardBg, isDark),
    ];
  }

  // ── INSIGHTS CATEGORY ──
  List<Widget> _buildInsightsCategory(Color textColor, Color secondaryColor, bool isDark, Color cardBg) {
    return [
      _iosTile("Summarize", "Create a 3-5 bullet point summary",
          CupertinoIcons.doc_plaintext, 'summarize', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Action items", "Extract tasks into a checklist",
          CupertinoIcons.checkmark_square, 'action_items', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Continue writing", "Keep writing from cursor position",
          CupertinoIcons.arrow_right, 'continue', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Explain concepts", "Explain topic in simple terms",
          CupertinoIcons.question_circle, 'explain', textColor, secondaryColor, cardBg, isDark),
    ];
  }

  // ── TRANSLATE CATEGORY ──
  List<Widget> _buildTranslateCategory(Color textColor, Color secondaryColor, bool isDark, Color cardBg) {
    return [
      _iosTile("Spanish", "Translate note content to Spanish",
          CupertinoIcons.globe, 'translate_es', textColor, secondaryColor, cardBg, isDark),
      _iosTile("French", "Translate note content to French",
          CupertinoIcons.globe, 'translate_fr', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Chinese", "Translate note content to Chinese",
          CupertinoIcons.globe, 'translate_zh', textColor, secondaryColor, cardBg, isDark),
      _iosTile("Japanese", "Translate note content to Japanese",
          CupertinoIcons.globe, 'translate_ja', textColor, secondaryColor, cardBg, isDark),
    ];
  }

  // ── TEMPLATES CATEGORY ──
  List<Widget> _buildTemplatesCategory(Color textColor, Color secondaryColor, bool isDark, Color cardBg) {
    return AiTemplateService.templates.map((tpl) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _loadingStatus != null ? null : () => _executeTemplate(tpl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tpl.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(tpl.icon, style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tpl.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tpl.description,
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right,
                      size: 14, color: secondaryColor.withOpacity(0.5)),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ── IOS REUSABLE LIST TILE ──
  Widget _iosTile(
      String title,
      String subtitle,
      IconData icon,
      String actionKey,
      Color textColor,
      Color secondaryColor,
      Color cardBg,
      bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _loadingStatus != null
              ? null
              : () => _executeAction(actionKey, title),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: textColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.chevron_right,
                    size: 14, color: secondaryColor.withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── CONVERSATION VIEW ──
  Widget _buildConversation(
      Color textColor, Color secondaryColor, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg, isDark, textColor, secondaryColor);
      },
    );
  }

  Widget _buildMessageBubble(
      _AIMessage msg, bool isDark, Color textColor, Color secondaryColor) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            msg.text,
            style: TextStyle(
                color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    // AI response preview card (iOS Minimalist)
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.sparkles, size: 12, color: textColor),
              ),
              const SizedBox(width: 6),
              Text(
                "AI GENERATED PREVIEW",
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: MarkdownBody(
              data: msg.text,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: textColor, fontSize: 13.5, height: 1.55),
                listBullet: TextStyle(color: textColor),
                h1: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                h2: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                h3: TextStyle(
                  color: textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                code: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                ),
              ),
            ),
          ),

          // RESPONSE ACTIONS BAR (Notion AI Style)
          if (!msg.isError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (widget.onPreviewEdit != null) ...[
                      _primaryPill("Preview in Note", CupertinoIcons.sparkles, () {
                        widget.onPreviewEdit!(msg.text, targetText: widget.selectedText);
                        Navigator.pop(context);
                      }, isDark, textColor),
                      const SizedBox(width: 6),
                    ],
                    if (widget.onReplaceSelection != null &&
                        widget.selectedText != null) ...[
                      _responsePill("Replace selection", CupertinoIcons.text_cursor, () {
                        widget.onReplaceSelection!(msg.text);
                        Navigator.pop(context);
                      }, isDark, textColor),
                      const SizedBox(width: 6),
                    ],
                    _responsePill("Insert below", CupertinoIcons.plus_square, () {
                      widget.onInsertContent(msg.text);
                      Navigator.pop(context);
                    }, isDark, textColor),
                    const SizedBox(width: 6),
                    if (widget.selectedText == null) ...[
                      _responsePill("Replace all", CupertinoIcons.arrow_2_squarepath, () {
                        widget.onReplaceContent(msg.text);
                        Navigator.pop(context);
                      }, isDark, textColor),
                      const SizedBox(width: 6),
                    ],
                    _iconPill(CupertinoIcons.doc_on_doc, () {
                      Clipboard.setData(ClipboardData(text: msg.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Copied to clipboard"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }, isDark, textColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _primaryPill(
      String label, IconData icon, VoidCallback onTap, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isDark ? Colors.black : Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.black : Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _responsePill(
      String label, IconData icon, VoidCallback onTap, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconPill(IconData icon, VoidCallback onTap, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 13, color: textColor.withOpacity(0.7)),
      ),
    );
  }

  // ── LOADING INDICATOR ──
  Widget _buildLoadingIndicator(Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CupertinoActivityIndicator(radius: 8),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _loadingStatus!,
              key: ValueKey(_loadingStatus),
              style: TextStyle(
                  color: secondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── INPUT BAR ──
  Widget _buildInputBar(
      bool isDark, Color textColor, Color secondaryColor, Color inputBg) {
    final canSend = _inputController.text.trim().isNotEmpty && _loadingStatus == null;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(21),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: widget.selectedText != null
                      ? "Ask AI about selection..."
                      : "Describe changes or ask AI...",
                  hintStyle: TextStyle(
                      color: secondaryColor.withOpacity(0.5), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Icon(CupertinoIcons.sparkles,
                        size: 15, color: secondaryColor.withOpacity(0.6)),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 28, minHeight: 0),
                ),
                onSubmitted: (_) => _sendCustomPrompt(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canSend ? _sendCustomPrompt : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: canSend
                    ? textColor
                    : (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.arrow_up,
                color: canSend
                    ? (isDark ? Colors.black : Colors.white)
                    : secondaryColor.withOpacity(0.4),
                size: 16,
              ),
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
