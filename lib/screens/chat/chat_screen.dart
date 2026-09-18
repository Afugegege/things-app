import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/money_provider.dart';
import '../../models/chat_model.dart';
import '../../models/note_model.dart';
import '../../models/task_model.dart';
import '../../models/currency_model.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/action_preview_sheet.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../core/action_registry.dart';
import '../../core/action_executor.dart';
import '../../core/ai_response_parser.dart';
import '../../core/ambiguity_resolver.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final Map<String, bool> _expandedActions = {};
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  String _suggestionQuery = "";

  static const String _selectedMode = 'Assistant';
  String _selectedModel = 'Auto'; // AI engine model (Auto, Daily, Pro)

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

  void _onTextChanged() {
    final text = _controller.text;
    if (text.isEmpty) {
      if (_showSuggestions) setState(() => _showSuggestions = false);
      return;
    }
    final match = RegExp(r'(?:^|\s)to\s+([^\s].*)$', caseSensitive: false).firstMatch(text);
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
    final noteTitles = notesProvider.notes.map((n) => "Note: ${n.title}").toList();
    final taskTitles = tasksProvider.tasks.map((t) => "Task: ${t.title}").toList();
    final allItems = [...noteTitles, ...taskTitles];
    setState(() {
      _suggestions = allItems
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .take(5).toList();
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

    final text = _controller.text.trim();
    _controller.clear();
    setState(() {
      _showSuggestions = false;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await chatProvider.sendMessage(
      message: text,
      userMemories: userProvider.user.aiMemory,
      mode: _selectedMode,
      customPersona: _selectedMode == 'Roleplay' ? userProvider.user.customPersona : null,
      aiModel: _selectedModel,
    );
  }

  void _copyChatText(BuildContext context, String text) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text("Message copied to clipboard"),
          ],
        ),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  AI MESSAGE RENDERING (using ParsedAiResponse)
  // ──────────────────────────────────────────────

  Widget _buildAiMessageContent(String msgId, ParsedAiResponse? parsed, bool isLatest) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final isDark = theme.brightness == Brightness.dark;
    final codeBg = isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200;
    final blockBg = isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100;
    final blockBorder = isDark ? Colors.white12 : Colors.black12;
    final primaryColor = theme.primaryColor;

    // Fallback: if parsing failed or we have no parsed data
    if (parsed == null) {
      final msg = Provider.of<ChatProvider>(context, listen: false)
          .messages.firstWhere((m) => m.id == msgId, orElse: () => ChatMessage(id: '', text: '', isUser: false, timestamp: DateTime.now()));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: msg.text,
            selectable: true,
            styleSheet: _markdownStyle(textColor, codeBg, blockBg, blockBorder),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _copyChatText(context, msg.text),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.doc_on_doc, size: 12, color: textColor.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text("Copy", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Display Text ──
        if (parsed.displayText.isNotEmpty)
          MarkdownBody(
            data: parsed.displayText,
            selectable: true,
            styleSheet: _markdownStyle(textColor, codeBg, blockBg, blockBorder),
          ),

        // ── Action Preview Button ──
        if (parsed.actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildActionSummaryCard(parsed.actions, msgId),
        ],

        // ── Suggestions ──
        if (isLatest && parsed.suggestions.isNotEmpty) ...[
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...parsed.suggestions.map((suggestion) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = suggestion;
                    _handleSend();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      suggestion,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () {
                  _controller.text = "Skip";
                  _handleSend();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.clear, size: 10, color: textColor.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Text(
                        "Skip",
                        style: TextStyle(
                          color: textColor.withOpacity(0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],

        // ── Message Actions (Copy & Regenerate) ──
        const SizedBox(height: 10),
        Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Copy Button
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                final textToCopy = parsed.displayText.isNotEmpty
                    ? parsed.displayText
                    : Provider.of<ChatProvider>(context, listen: false)
                        .messages
                        .firstWhere((m) => m.id == msgId,
                            orElse: () => ChatMessage(id: '', text: '', isUser: false, timestamp: DateTime.now()))
                        .text;
                _copyChatText(context, textToCopy);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.doc_on_doc, size: 12, color: textColor.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text("Copy", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            if (isLatest) ...[
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  Provider.of<ChatProvider>(context, listen: false).regenerateLastResponse(
                    context,
                    userMemories: userProvider.user.aiMemory,
                    mode: _selectedMode,
                    aiModel: _selectedModel,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 13, color: primaryColor),
                      const SizedBox(width: 4),
                      Text("Regenerate", style: TextStyle(color: primaryColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildThinkingIndicator() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 8),
            const SizedBox(width: 8),
            Text(
              "Thinking...",
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSummaryCard(List<ActionIntent> actions, String msgId) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final accentColor = Provider.of<UserProvider>(context).accentColor;

    final allDone = actions.every((a) => a.status == ActionStatus.success);
    final hasErrors = actions.any((a) => a.status == ActionStatus.error);
    final isRunning = actions.any((a) => a.status == ActionStatus.loading);

    final isExpanded = _expandedActions[msgId] ?? false;

    // Show up to 2 actions unless expanded
    final displayedActions = isExpanded ? actions : actions.take(2).toList();
    final hasMore = actions.length > 2;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = allDone
        ? Colors.green.withOpacity(0.4)
        : (hasErrors ? Colors.redAccent.withOpacity(0.4) : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: allDone
                        ? Colors.green.withOpacity(0.15)
                        : (hasErrors ? Colors.redAccent.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    allDone
                        ? CupertinoIcons.checkmark_seal_fill
                        : (hasErrors ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.sparkles),
                    size: 13,
                    color: allDone ? Colors.green : (hasErrors ? Colors.redAccent : textColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  allDone ? "ACTIONS COMPLETED" : "PROPOSED ACTIONS",
                  style: TextStyle(
                    color: allDone ? Colors.green : (hasErrors ? Colors.redAccent : textColor),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                if (!allDone && !isRunning)
                  GestureDetector(
                    onTap: () {
                      final suggestions = AmbiguityResolver.analyze(actions, context);
                      ActionPreviewSheet.show(
                        context,
                        actions: actions.where((a) => a.status != ActionStatus.success).toList(),
                        suggestions: suggestions,
                        onComplete: (results) {
                          setState(() {});
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.slider_horizontal_3, size: 11, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            "Customize",
                            style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          ),

          // Actions List
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ...displayedActions.map((action) {
                  final def = action.definition;
                  final isActDone = action.status == ActionStatus.success;
                  final isActErr = action.status == ActionStatus.error;
                  final isActRunning = action.status == ActionStatus.loading;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(def?.icon ?? CupertinoIcons.doc_text, size: 14, color: textColor.withOpacity(0.7)),
                            const SizedBox(width: 8),
                            Text(
                              def?.displayName ?? action.action.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            if (isActDone)
                              const Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Colors.green)
                            else if (isActErr)
                              const Icon(CupertinoIcons.xmark_circle_fill, size: 14, color: Colors.redAccent)
                            else if (isActRunning)
                              SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: textColor),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildActionDetails(action, isExpanded, isDark, textColor, secondaryColor, accentColor, context),
                      ],
                    ),
                  );
                }),

                // Expand/Collapse Button
                if (hasMore)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedActions[msgId] = !_expandedActions[msgId]!;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isExpanded ? "Show Less" : "Show More (${actions.length - 2} more)",
                            style: TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                            size: 12,
                            color: secondaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Confirm / Skip Buttons at Bottom
          if (!allDone)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      minSize: 38,
                      onPressed: () {
                        setState(() {
                          for (var a in actions) {
                            a.status = ActionStatus.success;
                          }
                        });
                        _controller.text = "Skip plan";
                        _handleSend();
                      },
                      child: Text(
                        "Skip",
                        style: TextStyle(color: secondaryColor, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(14),
                      minSize: 38,
                      onPressed: isRunning
                          ? null
                          : () async {
                              setState(() {
                                for (var a in actions) {
                                  if (a.status != ActionStatus.success) {
                                    a.status = ActionStatus.loading;
                                  }
                                }
                              });

                              await ActionExecutor.executeAll(
                                actions.where((a) => a.status != ActionStatus.success).toList(),
                                context,
                                onProgress: (idx, status) {
                                  if (mounted) setState(() {});
                                },
                              );

                              if (mounted) {
                                setState(() {});
                              }
                            },
                      child: isRunning
                          ? SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.black : Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.checkmark_alt, size: 14, color: isDark ? Colors.black : Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  "Confirm All",
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          // Group into Collection button (only shown if allDone is true and we created >1 note/task)
          if (allDone) ...[
            if (actions.where((a) => a.action == 'create_note' || a.action == 'create_task').length > 1)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  onPressed: () => _groupIntoCollection(context, actions),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.folder_badge_plus, size: 16, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        "Group into Collection",
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionDetails(
    ActionIntent action,
    bool isExpanded,
    bool isDark,
    Color textColor,
    Color secondaryColor,
    Color accentColor,
    BuildContext context,
  ) {
    final act = action.action.toLowerCase();
    final data = action.data;

    final isTransaction = act.contains('transaction') || act.contains('expense');
    final isTask = act.contains('task');
    final isEvent = act.contains('event');
    final isNote = act.contains('note');
    final isRemember = act == 'remember';
    final isDelete = act.startsWith('delete') || act.startsWith('remove');

    final title = data['title'] ?? data['search_title'] ?? data['fact'] ?? data['folder'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.toString().isNotEmpty)
          Text(
            title.toString(),
            style: TextStyle(
              color: action.status == ActionStatus.success ? secondaryColor : textColor.withOpacity(0.95),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: action.status == ActionStatus.success ? TextDecoration.lineThrough : null,
            ),
          ),
        const SizedBox(height: 6),

        // ── Transaction Details (Amount, Category, Date, Currency) ──
        if (isTransaction && !isDelete) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Amount Badge
              if (data['amount'] != null) ...[
                () {
                  final num? amt = num.tryParse(data['amount'].toString());
                  final double val = amt?.toDouble() ?? 0.0;
                  final bool isExp = val < 0 || act.contains('expense');
                  final cur = data['currency']?.toString().toUpperCase() ??
                      Provider.of<MoneyProvider>(context, listen: false).currentCurrency;
                  final sym = AppCurrency.getSymbol(cur);
                  final displayAmt = "${isExp ? '-' : '+'}$sym${val.abs().toStringAsFixed(2)} $cur";

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isExp ? Colors.redAccent.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isExp ? Colors.redAccent.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      displayAmt,
                      style: TextStyle(
                        color: isExp ? (isDark ? Colors.redAccent.shade100 : Colors.red.shade700) : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                }(),
              ],
              // Category Badge
              if (data['category'] != null && data['category'].toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.tag_fill, size: 10, color: secondaryColor),
                      const SizedBox(width: 4),
                      Text(
                        data['category'].toString(),
                        style: TextStyle(color: textColor.withOpacity(0.85), fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              // Date Badge
              if (data['date'] != null && data['date'].toString().isNotEmpty) ...[
                () {
                  final parsedDate = DateHelper.parseFlexibleDate(data['date']);
                  final dateText = parsedDate != null
                      ? DateHelper.formatFriendlyDate(parsedDate)
                      : data['date'].toString().split('T').first;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.calendar, size: 11, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          dateText,
                          style: TextStyle(color: accentColor, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }(),
              ],
            ],
          ),
        ],

        // ── Task Details ──
        if (isTask && !isDelete) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (data['priority'] != null) ...[
                () {
                  final p = int.tryParse(data['priority'].toString()) ?? 1;
                  final pLabel = p == 3 ? 'High Priority' : (p == 2 ? 'Medium' : 'Low Priority');
                  final pColor = p == 3 ? Colors.redAccent : (p == 2 ? Colors.amber : Colors.blueAccent);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: pColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: pColor, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(pLabel, style: TextStyle(color: pColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }(),
              ],
              if (data['dueDate'] != null || data['date'] != null) ...[
                () {
                  final dt = DateHelper.parseFlexibleDate(data['dueDate'] ?? data['date']);
                  final dText = dt != null ? DateHelper.formatFriendlyDate(dt) : (data['dueDate'] ?? data['date']).toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.clock, size: 10, color: secondaryColor),
                        const SizedBox(width: 4),
                        Text("Due: $dText", style: TextStyle(color: secondaryColor, fontSize: 11.5)),
                      ],
                    ),
                  );
                }(),
              ],
            ],
          ),
          if (data['note'] != null && data['note'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              data['note'].toString(),
              maxLines: isExpanded ? null : 2,
              overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(color: secondaryColor, fontSize: 12),
            ),
          ],
        ],

        // ── Event Details ──
        if (isEvent && !isDelete) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (data['date'] != null) ...[
                () {
                  final dt = DateHelper.parseFlexibleDate(data['date']);
                  final dText = dt != null ? DateHelper.formatFriendlyDate(dt) : data['date'].toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.calendar, size: 11, color: accentColor),
                        const SizedBox(width: 4),
                        Text(dText, style: TextStyle(color: accentColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }(),
              ],
              if (data['location'] != null && data['location'].toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.location_solid, size: 10, color: secondaryColor),
                      const SizedBox(width: 4),
                      Text(data['location'].toString(), style: TextStyle(color: secondaryColor, fontSize: 11.5)),
                    ],
                  ),
                ),
            ],
          ),
          if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              data['description'].toString(),
              maxLines: isExpanded ? null : 2,
              overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(color: secondaryColor, fontSize: 12),
            ),
          ],
        ],

        // ── Note Details ──
        if (isNote && !isDelete) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (data['folder'] != null && data['folder'].toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.folder_fill, size: 10, color: secondaryColor),
                      const SizedBox(width: 4),
                      Text(data['folder'].toString(), style: TextStyle(color: secondaryColor, fontSize: 11.5)),
                    ],
                  ),
                ),
              if (act == 'edit_note' && data['append_content'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text("+ Append", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (data['content'] != null && data['content'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              data['content'].toString(),
              maxLines: isExpanded ? null : 2,
              overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(color: secondaryColor, fontSize: 12, height: 1.4),
            ),
          ],
          if (data['append_content'] != null && data['append_content'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "+ ${data['append_content'].toString()}",
              maxLines: isExpanded ? null : 2,
              overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(color: Colors.green.withOpacity(0.9), fontSize: 12, height: 1.4),
            ),
          ],
        ],

        // ── Delete Actions ──
        if (isDelete) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.trash_fill, size: 11, color: Colors.redAccent),
                const SizedBox(width: 5),
                Text(
                  "Will delete: ${data['search_title'] ?? data['title'] ?? data['id'] ?? ''}",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],

        // ── Remember Fact ──
        if (isRemember && data['fact'] != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.lightbulb_fill, size: 12, color: Colors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "\"${data['fact']}\"",
                    style: const TextStyle(color: Colors.amber, fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }



  void _groupIntoCollection(BuildContext context, List<ActionIntent> actions) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    // Suggest a default folder name based on the first note title, or first task title
    final noteAction = actions.firstWhere(
      (a) => a.action == 'create_note',
      orElse: () => actions.firstWhere((a) => a.action == 'create_task'),
    );
    String defaultName = "My Collection";
    if (noteAction.data['title'] != null) {
      defaultName = noteAction.data['title'].toString();
    }

    final ctrl = TextEditingController(text: defaultName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "CREATE COLLECTION",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5, color: textColor),
            ),
            const SizedBox(height: 10),
            Text(
              "Group all created notes and tasks together into a new collection.",
              style: TextStyle(color: theme.disabledColor, fontSize: 13),
            ),
            const SizedBox(height: 15),
            CupertinoTextField(
              controller: ctrl,
              placeholder: "Collection Name",
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: theme.primaryColor,
                child: const Text("Group Together", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  final folderName = ctrl.text.trim();
                  if (folderName.isEmpty) return;

                  final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                  final tasksProvider = Provider.of<TasksProvider>(context, listen: false);

                  // 1. Add folder/collection
                  notesProvider.addFolder(folderName);

                  // Find note ids
                  final noteIds = <String>[];
                  for (final a in actions) {
                    if (a.action == 'create_note') {
                      final title = a.data['title'] ?? '';
                      final note = notesProvider.notes.cast<Note?>().firstWhere(
                        (n) => n!.title.toLowerCase() == title.toString().toLowerCase(),
                        orElse: () => null,
                      );
                      if (note != null) {
                        noteIds.add(note.id);
                      }
                    }
                  }

                  // 2. Move notes to new folder/collection
                  if (noteIds.isNotEmpty) {
                    notesProvider.batchMoveNotes(noteIds, folderName);
                  }

                  // 3. Link tasks to the first note in this collection (if any notes exist)
                  if (noteIds.isNotEmpty) {
                    final targetNoteId = noteIds.first;
                    for (final a in actions) {
                      if (a.action == 'create_task') {
                        final title = a.data['title'] ?? '';
                        final task = tasksProvider.tasks.cast<Task?>().firstWhere(
                          (t) => t!.title.toLowerCase() == title.toString().toLowerCase(),
                          orElse: () => null,
                        );
                        if (task != null) {
                          tasksProvider.updateTask(task.copyWith(linkedNoteId: targetNoteId));
                        }
                      }
                    }
                  }

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Grouped under '$folderName' collection!")),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(Color textColor, Color codeBg, Color blockBg, Color blockBorder) {
    return MarkdownStyleSheet(
      p: TextStyle(color: textColor, fontSize: 16, height: 1.4),
      h1: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
      h2: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
      code: TextStyle(backgroundColor: codeBg, fontFamily: 'Courier', fontSize: 14, color: textColor),
      codeblockDecoration: BoxDecoration(
        color: blockBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: blockBorder),
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage msg) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final primaryColor = theme.primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(CupertinoIcons.doc_on_doc, color: primaryColor),
              title: Text("Copy Text", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _copyChatText(context, msg.text);
              },
            ),
            ListTile(
              leading: Icon(Icons.bookmark_add, color: primaryColor),
              title: Text("Save as Note", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              onTap: () {
                chatProvider.saveMessageAsNote(msg.text, notesProvider);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!")));
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.trash, color: Colors.red),
              title: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final hintColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final accentColor = Provider.of<UserProvider>(context).accentColor;
    final onAccentColor = accentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return LifeAppScaffold(
      title: "AI ASSISTANT",
      child: Column(
        children: [
          // 1. CHAT LIST
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    itemCount: chatProvider.messages.length + (chatProvider.isTyping ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (chatProvider.isTyping && i == 0) {
                        return _buildThinkingIndicator();
                      }
                      final msgIndex = chatProvider.isTyping ? i - 1 : i;
                      final msg = chatProvider.messages[msgIndex];
                      final parsed = msg.isUser ? null : chatProvider.getParsedResponse(msg.id);

                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(context, msg),
                        child: Align(
                          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(16),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
                            decoration: msg.isUser
                                ? BoxDecoration(
                                    color: isDark ? Colors.white : Colors.black,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(22),
                                      topRight: Radius.circular(22),
                                      bottomLeft: Radius.circular(22),
                                      bottomRight: Radius.circular(6),
                                    ),
                                  )
                                : BoxDecoration(
                                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(22),
                                      topRight: Radius.circular(22),
                                      bottomLeft: Radius.circular(6),
                                      bottomRight: Radius.circular(22),
                                    ),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                                      width: 1.0,
                                    ),
                                  ),
                            child: msg.isUser
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          msg.text,
                                          style: TextStyle(
                                            color: isDark ? Colors.black : Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _copyChatText(context, msg.text),
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 2),
                                          child: Icon(
                                            CupertinoIcons.doc_on_doc,
                                            size: 13,
                                            color: (isDark ? Colors.black : Colors.white).withOpacity(0.55),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : _buildAiMessageContent(msg.id, parsed, i == 0),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 2. SUGGESTIONS POPUP
                if (_showSuggestions && _suggestions.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    left: 20, right: 20,
                    child: GlassContainer(
                      borderRadius: 20,
                      opacity: isDark ? 0.2 : 0.95,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                          itemBuilder: (ctx, i) => ListTile(
                            dense: true,
                            title: Text(_suggestions[i], style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                            onTap: () => _applySuggestion(_suggestions[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. INPUT AREA
          Padding(
            padding: EdgeInsets.fromLTRB(
              20, 10, 20,
              MediaQuery.of(context).orientation == Orientation.landscape ? 70 : 125,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassContainer(
                  borderRadius: 30,
                  blur: 20,
                  opacity: isDark ? 0.15 : 0.05,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Engine Selector Dropdown
                      Theme(
                        data: theme.copyWith(
                          cardColor: theme.cardColor,
                        ),
                        child: PopupMenuButton<String>(
                          initialValue: _selectedModel,
                          tooltip: "Select Engine",
                          onSelected: (String value) {
                            setState(() {
                              _selectedModel = value;
                            });
                          },
                          offset: const Offset(0, -145), // Pop up upwards
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'Auto',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.sparkles, size: 16, color: _selectedModel == 'Auto' ? accentColor : textColor.withOpacity(0.6)),
                                  const SizedBox(width: 8),
                                  Text("Auto Model", style: TextStyle(color: textColor, fontWeight: _selectedModel == 'Auto' ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'Daily',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.bolt_fill, size: 16, color: _selectedModel == 'Daily' ? accentColor : textColor.withOpacity(0.6)),
                                  const SizedBox(width: 8),
                                  Text("Daily Use (Fast)", style: TextStyle(color: textColor, fontWeight: _selectedModel == 'Daily' ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'Pro',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.waveform_path_ecg, size: 16, color: _selectedModel == 'Pro' ? accentColor : textColor.withOpacity(0.6)),
                                  const SizedBox(width: 8),
                                  Text("Pro Model (Smart)", style: TextStyle(color: textColor, fontWeight: _selectedModel == 'Pro' ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedModel == 'Auto'
                                      ? CupertinoIcons.sparkles
                                      : (_selectedModel == 'Daily' ? CupertinoIcons.bolt_fill : CupertinoIcons.waveform_path_ecg),
                                  size: 13,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedModel,
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(CupertinoIcons.chevron_up, size: 10, color: textColor.withOpacity(0.4)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),

                      // Text Field
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(color: textColor),
                          textAlignVertical: TextAlignVertical.center,
                          maxLines: 5,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: "Message AI...",
                            hintStyle: TextStyle(color: hintColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),

                      // Send Button
                      Container(
                        margin: const EdgeInsets.only(left: 5),
                        decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(Icons.arrow_upward, color: onAccentColor, size: 18),
                          onPressed: _handleSend,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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


}