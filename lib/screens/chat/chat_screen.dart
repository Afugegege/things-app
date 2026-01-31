import '../../widgets/confirmation_card.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/tasks_provider.dart'; 
import '../../models/chat_model.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/chat_preview_card.dart';
import '../../utils/json_cleaner.dart';
import '../../widgets/life_app_scaffold.dart'; 

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
  
  bool _isRefining = false;
  String? _pendingActionId;

  // MODES LIST
  final List<String> _modes = ['Assistant', 'Counselor', 'Health (Pulse)', 'Finance', 'Roleplay'];
  String _selectedMode = 'Assistant';

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
    final noteTitles = notesProvider.notes.map((n) => "📝 ${n.title}").toList();
    final taskTitles = tasksProvider.tasks.map((t) => "✅ ${t.title}").toList();
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
    
    final text = _controller.text;
    _controller.clear();
    setState(() {
      _showSuggestions = false;
      _isRefining = false;
      _pendingActionId = null;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    await chatProvider.sendMessage(
      message: text,
      userMemories: userProvider.user.aiMemory,
      mode: _selectedMode,
      customPersona: _selectedMode == 'Roleplay' ? userProvider.user.customPersona : null,
    );
  }

  Widget _buildAiMessageContent(String text, String msgId, bool isLatest) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final isDark = theme.brightness == Brightness.dark;
    final codeBg = isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200;
    final blockBg = isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100;
    final blockBorder = isDark ? Colors.white12 : Colors.black12;

    String displayContent = text;
    Map<String, dynamic>? actionData;

    final codeBlockMatch = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```').firstMatch(text);
    
    if (codeBlockMatch != null) {
      try {
        final jsonStr = codeBlockMatch.group(1)!;
        actionData = jsonDecode(JsonCleaner.clean(jsonStr));
        displayContent = text.replaceFirst(codeBlockMatch.group(0)!, '').trim();
      } catch (e) {
        debugPrint("JSON Parse Error: $e");
      }
    } else {
      final rawMatch = RegExp(r'(\{[\s\S]*"action"[\s\S]*\})').firstMatch(text);
      if (rawMatch != null) {
        try {
          final jsonStr = rawMatch.group(1)!;
          if (jsonStr.contains("action")) {
             actionData = jsonDecode(JsonCleaner.clean(jsonStr));
             displayContent = text.replaceFirst(rawMatch.group(0)!, '').trim();
          }
        } catch (e) {}
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (displayContent.isNotEmpty)
          MarkdownBody(
            data: displayContent,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(color: textColor, fontSize: 16, height: 1.4),
              h1: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
              h2: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              code: TextStyle(backgroundColor: codeBg, fontFamily: 'Courier', fontSize: 14, color: textColor),
              codeblockDecoration: BoxDecoration(
                color: blockBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: blockBorder),
              ),
            ),
          ),

        if (actionData != null) ...[
          const SizedBox(height: 15),
          _buildActionCard(actionData, msgId),
        ],

        if (isLatest) ...[
           const SizedBox(height: 10),
           Divider(color: Colors.grey.withOpacity(0.2)),
           Center(
             child: InkWell(
               onTap: () {
                 final userProvider = Provider.of<UserProvider>(context, listen: false);
                 Provider.of<ChatProvider>(context, listen: false).regenerateLastResponse(
                   context, 
                   userMemories: userProvider.user.aiMemory, 
                   mode: _selectedMode
                 );
               },
               child: Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(Icons.refresh, size: 14, color: Theme.of(context).primaryColor),
                     const SizedBox(width: 5),
                     Text("Regenerate", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                   ],
                 ),
               ),
             ),
           ),
        ]
      ],
    );
  }

  Widget _buildActionCard(Map<String, dynamic> data, String msgId) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    String status = data['status'] ?? 'pending';

    if (status == 'loading') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor)),
          const SizedBox(width: 15),
          Text("Processing...", style: TextStyle(color: textColor.withOpacity(0.7))),
        ]),
      );
    }

    if (status == 'success') {
      String title = data['title'] ?? 'Item';
      if (data['action'] == 'save_note' && data['content'] is Map) {
         title = data['content']['title'] ?? title;
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: Colors.green.withOpacity(0.3))
        ),
        child: Row(
           children: [
             const Icon(Icons.check_circle, color: Colors.green, size: 24),
             const SizedBox(width: 12),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text("SUCCESS", style: TextStyle(color: Colors.green.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                   Text("Saved \"$title\"", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                 ],
               ),
             ),
           ]
        ),
      );
    }

    if (data['action'] == 'create_note' || data['action'] == 'save_note' || data['action'] == 'edit_note') {
       if (data['action'] == 'save_note' && data['content'] is Map) {
         data['title'] = data['content']['title'];
         data['content'] = data['content']['body'];
       } else if (data['content'] is Map) {
         data['content'] = data['content']['body'];
       }

       return ChatPreviewCard(
         data: data,
         onSave: () => Provider.of<ChatProvider>(context, listen: false).executeCommand(msgId, data, context),
         onEdit: () {
           setState(() {
             _isRefining = true;
             _pendingActionId = msgId;
             _controller.text = "Change title to "; 
             FocusScope.of(context).requestFocus();
           });
         },
       );
    } else {
       String detailsText = "${data['title'] ?? 'Update'} ${data['amount'] != null ? '(\$${data['amount']})' : ''}";
       if (data['category'] != null) {
         detailsText += "\nCategory: ${data['category']}";
       }

       return ConfirmationCard(
         action: data['action'].toString().replaceAll('_', ' ').toUpperCase(),
         details: detailsText,
         onConfirm: () => Provider.of<ChatProvider>(context, listen: false).executeCommand(msgId, data, context),
         onCancel: () {}, 
       );
    }
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
            const SizedBox(height: 25),
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

  void _showModePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final primaryColor = theme.primaryColor;

        return Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 25),
              Text("SELECT MODE", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 20),
              ..._modes.map((mode) => ListTile(
                leading: Icon(_getModeIcon(mode), color: _selectedMode == mode ? primaryColor : theme.iconTheme.color),
                title: Text(mode, style: TextStyle(color: _selectedMode == mode ? primaryColor : textColor, fontWeight: FontWeight.bold)),
                trailing: _selectedMode == mode ? Icon(Icons.check, color: primaryColor) : null,
                onTap: () {
                  setState(() => _selectedMode = mode);
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        );
      },
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
      title: _selectedMode.toUpperCase(),
      actions: [
        IconButton(
          icon: Icon(CupertinoIcons.arrow_right_arrow_left_circle, color: textColor),
          onPressed: _showModePicker,
        ),
      ],
      // [FIX] Using a Column with Expanded ensures the input bar is pushed to the bottom
      // but stays above any persistent UI (like navigation bars) within the scaffold.
      child: Column(
        children: [
          // 1. CHAT LIST (Scrollable Area)
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10), 
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = chatProvider.messages[i];
                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(context, msg),
                        child: Align(
                          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(16),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
                            decoration: BoxDecoration(
                              color: msg.isUser 
                                  ? accentColor 
                                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(24),
                                topRight: const Radius.circular(24),
                                bottomLeft: Radius.circular(msg.isUser ? 24 : 4),
                                bottomRight: Radius.circular(msg.isUser ? 4 : 24),
                              ),
                              boxShadow: isDark || msg.isUser ? [] : [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                              ]
                            ),
                            child: msg.isUser 
                                ? Text(msg.text, style: TextStyle(color: onAccentColor, fontWeight: FontWeight.bold))
                                : _buildAiMessageContent(msg.text, msg.id, i == 0),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 2. SUGGESTIONS POPUP (Floating above list)
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

          // 3. INPUT AREA (Fixed at the absolute bottom of the Column)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 125), // Padding adjusted to sit above Nav Bar
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRefining)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, color: onAccentColor, size: 14),
                        const SizedBox(width: 8),
                        Text("Refining...", style: TextStyle(color: onAccentColor, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _isRefining = false),
                          child: Icon(Icons.close, color: onAccentColor, size: 16),
                        )
                      ],
                    ),
                  ),


                
                // [NEW] Persona Input for Roleplay
                if (_selectedMode == 'Roleplay')
                   Padding(
                     padding: const EdgeInsets.only(bottom: 15),
                     child: GestureDetector(
                       onTap: () => _showPersonaEditor(context),
                       child: GlassContainer(
                         width: double.infinity,
                         height: 50,
                         borderRadius: 20,
                         opacity: isDark ? 0.1 : 0.05,
                         padding: const EdgeInsets.symmetric(horizontal: 20),
                         child: Row(
                           children: [
                             Icon(Icons.theater_comedy, color: accentColor, size: 20),
                             const SizedBox(width: 10),
                             Expanded(child: Text(
                               Provider.of<UserProvider>(context).user.customPersona ?? "Set Persona...",
                               style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                               maxLines: 1, overflow: TextOverflow.ellipsis
                             )),
                             const SizedBox(width: 8),
                             const Icon(Icons.edit, size: 16, color: Colors.grey)
                           ],
                         ),
                       ),
                     ),
                   ),

                GlassContainer(
                  height: 60,
                  borderRadius: 30,
                  blur: 20,
                  opacity: isDark ? 0.15 : 0.05,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, 
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(color: textColor),
                          textAlignVertical: TextAlignVertical.center, 
                          decoration: InputDecoration(
                            hintText: _getHintText(),
                            hintStyle: TextStyle(color: hintColor),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            isDense: true, 
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(Icons.arrow_upward, color: onAccentColor),
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

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'Counselor': return Icons.spa;
      case 'Health (Pulse)': return Icons.favorite;
      case 'Finance': return Icons.attach_money;
      case 'Roleplay': return Icons.theater_comedy;
      default: return Icons.smart_toy;
    }
  }

  String _getHintText() {
    switch (_selectedMode) {
      case 'Counselor': return "How are you feeling?";
      case 'Finance': return "Track an expense...";
      case 'Roleplay': return "Chat with your persona...";
      default: return "Message AI...";
    }
  }

  void _showPersonaEditor(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final ctrl = TextEditingController(text: userProvider.user.customPersona);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("CUSTOM PERSONA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: Theme.of(context).disabledColor)),
            const SizedBox(height: 15),
            Text("Describe who the AI should be.", style: TextStyle(color: Theme.of(context).disabledColor)),
            const SizedBox(height: 15),
            CupertinoTextField(
              controller: ctrl,
              placeholder: "e.g. You are a grumpy math teacher...",
              maxLines: 3,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(15)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                child: const Text("Save Persona"), 
                onPressed: () {
                   userProvider.updateCustomPersona(ctrl.text);
                   Navigator.pop(ctx);
                }
              ),
            )
          ],
        ),
      ),
    );
  }
}