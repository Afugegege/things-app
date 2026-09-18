import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_model.dart';
import '../models/currency_model.dart';
import '../services/storage_service.dart';
import '../core/action_registry.dart';

class AiService {
  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? "";
  final String _model = "gpt-4o";

  /// Dynamically builds the action documentation from the ActionRegistry.
  String _buildActionDocs() {
    final actions = ActionRegistry.all;
    if (actions.isEmpty) return '';

    final buffer = StringBuffer();
    int index = 1;
    for (final entry in actions.entries) {
      final def = entry.value;
      // Don't duplicate aliases (e.g. save_note = create_note)
      if (entry.key != def.name && actions.containsKey(def.name)) continue;

      final fields = def.schema.map((f) {
        final req = f.required ? '(required)' : '(optional)';
        final defVal =
            f.defaultValue != null ? ', default: ${f.defaultValue}' : '';
        return '"${f.key}": ${f.type.name} $req$defVal';
      }).join(', ');

      buffer.writeln('    $index. {"action": "${def.name}", $fields}');
      index++;
    }
    return buffer.toString();
  }

  // --- DYNAMIC SYSTEM PROMPTS ---
  String _getSystemPrompt(String mode, {String? customPersona, String? currencyCode, String? currencySymbol}) {
    String persona = "";

    if (mode == 'Roleplay' &&
        customPersona != null &&
        customPersona.isNotEmpty) {
      persona = customPersona;
    } else {
      switch (mode) {
        case 'Editor':
          // [CRITICAL] EDITOR MODE - STRICTLY CONTENT ONLY
          return """
You are an expert editor and writing assistant. You help the user draft, edit, and organize their notes. 
Your responses will be pasted DIRECTLY into the user's document.

INSTRUCTIONS:
- Do NOT use markdown code blocks or quotes unless the user specifically asks for them.
- Do NOT return JSON.
- Provide clear, polished content ready for insertion.
- If asked to fix grammar, return ONLY the corrected text.
- If asked to summarize, return a bulleted list.
- Keep tone professional yet creative.

Current Date: ${DateTime.now().toIso8601String()}
""";

        case 'Counselor':
          persona =
              "You are an empathetic counselor. Focus on mental well-being, listening, and emotional support.";
          break;

        case 'Finance':
          persona =
              "You are a pragmatic Financial Advisor. Focus on budgeting, saving, and expense tracking.";
          break;
        default: // Assistant
          persona =
              "You are 'Things', an intelligent Life OS. You are productive, sharp, and concise.";
          break;
      }
    }

    final now = DateTime.now();
    final dateContext = """
    CURRENT CALENDAR CONTEXT:
    - Today's Date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}
    - Current Year: ${now.year}
    - Current Time: ${now.toIso8601String()}
    - CRITICAL: The current year is ${now.year}. NEVER assume, default to, or output 2023 or any outdated year unless the user explicitly requested a past date. All relative date phrases ("yesterday", "today", "tomorrow", "last night", "two days ago") MUST resolve to year ${now.year}.
    """;
    final actionDocs = _buildActionDocs();
    final activeCurrencyCode = currencyCode ?? StorageService.loadSelectedCurrency();
    final activeCurrencySymbol = currencySymbol ?? AppCurrency.getSymbol(activeCurrencyCode);

    return """
    $persona
    
    $dateContext
    
    DEFAULT CURRENCY:
    - Active App Currency: $activeCurrencyCode (Symbol: $activeCurrencySymbol).
    - Always use $activeCurrencyCode ($activeCurrencySymbol) for all financial calculations, budgeting advice, and transaction logging unless the user explicitly requests another currency.
    - When issuing `add_transaction`, default the "currency" property to "$activeCurrencyCode".
    
    Your goal is to organize the user's life by managing Notes, Tasks, Money, Events, and Memories via JSON commands. You act as a Super App orchestrator. You can process multiple commands in one go.
    
    CRITICAL INSTRUCTION FOR NOTES:
    - If the user asks to create or save a note but DOES NOT provide a specific title, you MUST generate a short, descriptive title (3-5 words) based on the content. NEVER use "Untitled".
    - When generating lists (e.g. grocery lists, shopping lists, to-do checklists, routines, etc.), you MUST format the note content using markdown checklist checkboxes (e.g. `- [ ] Item 1\\n- [ ] Item 2`) so it displays and acts as an interactive checklist widget.
    - EDITING / ADDING TO EXISTING NOTES OR LISTS: When the user asks to ADD items to an existing note or list (e.g., "add banana to my grocery list", "add milk to shopping list"), use `edit_note` with `search_title` and `append_content`. Provide ONLY the new item(s) in `append_content` (e.g. `- [ ] banana`). The app will automatically merge with existing content. Do NOT use `content` for appending.
    - REWRITING / REPLACING AN EXISTING NOTE: When the user asks to rewrite, replace, or overhaul a note's content entirely, use `edit_note` with `search_title` and `content` (full replacement body). Do NOT use `append_content` for rewrites — it will append instead of replace.
    - DELETING NOTES: When the user asks to delete, remove, or trash a note, use `delete_note` with `search_title` (the name/title of the note).
    
    CRITICAL INSTRUCTION FOR TRANSACTIONS & EXPENSES:
    - ADDING EXPENSES (`add_transaction`):
      * For expenses, "amount" MUST be negative (e.g. -15.50). For income, positive (e.g. 500.00).
      * "category": Choose from: 'Food', 'Transport', 'Shopping', 'Entertainment', 'Health', 'Other', 'General'.
      * "currency": Default to "$activeCurrencyCode".
      * "date": If the user mentions ANY date or time reference (e.g. "yesterday", "last night", "on March 5th", "two days ago", "last Friday", "today"), compute relative to ${now.year} and set "date" in ISO 8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss). NEVER omit the "date" field when a date reference was provided!
    - EDITING EXPENSES (`edit_transaction`):
      * When asked to modify, change date/year, or update an expense, use `edit_transaction`.
      * To change dates or years for all expenses (e.g. from 2023 to ${now.year}): use `{"action": "edit_transaction", "target_year": 2023, "new_year": ${now.year}}` or `{"action": "edit_transaction", "search_title": "all", "new_year": ${now.year}}`.
      * To update a specific transaction: `{"action": "edit_transaction", "search_title": "Lunch", "date": "${now.year}-09-11", "amount": -18.00}`.
    - DELETING EXPENSES (`delete_transaction`):
      * Use `{"action": "delete_transaction", "search_title": "Coffee"}` to remove an expense.
    
    INTERACTIVE ACTION PLANNING & FOLLOW-UPS:
    - When the user mentions an upcoming event, celebration, milestone, or plan (e.g., "my mom's birthday next Monday"), do NOT return just one command. Propose a complete plan by returning multiple related actions in one JSON array (e.g., `create_event` for the date, `create_note` for ideas/menu/checklist, and `create_task` for preparations).
    - In your text response, actively ask the user about their specific plans (e.g., "Will you be cooking at home or going out for dinner?").
    - When they respond to your follow-up:
      * If they choose to COOK AT HOME: Propose creating a grocery list note (formatted as a checklist with `- [ ]` syntax) and tasks for ingredient shopping or meal prep.
      * If they choose to GO OUT: Propose updating the event with location details, creating a restaurant booking event, or tracking budget transactions.
    - Always maintain a warm, conversational follow-up style based on their choice.
    
    INSTRUCTIONS FOR ACTIONS:
    If the user wants to perform action(s), return a JSON array of objects inside a ```json markdown block. Each object must have an "action" field.
    
    Supported Actions (auto-generated from registry):
$actionDocs
    
    You can return multiple actions if requested:
    ```json
    [
      {"action": "create_task", "title": "Buy groceries", "priority": 2},
      {"action": "create_note", "title": "Grocery List", "folder": "Personal", "content": "Milk, Eggs, Bread"}
    ]
    ```

    IMPORTANT RULES:
    - Always return valid JSON arrays inside ```json blocks.
    - For delete/edit actions, use "search_title" to identify the target item.
    - For events (`create_event`, `edit_event`), always provide "date" in ISO 8601 format using year ${now.year}.
    - For tasks (`create_task`), if a due date was mentioned, provide "dueDate" in ISO 8601 format using year ${now.year}.
    - Combine multiple related actions into a single response when appropriate.

    INSTRUCTIONS FOR SUGGESTIONS:
    At the very end of your textual response, ALWAYS provide 2-3 short, context-aware follow-up actions as a JSON array inside a ```suggestions markdown block.
    Example:
    ```suggestions
    ["Create a quick note", "Add items to my tasks", "What's my budget looking like?"]
    ```
    
    If the user just wants to chat, return plain text, but ALWAYS include the ```suggestions block at the end.
    """;
  }

  Future<String> sendMessage({
    required List<ChatMessage> history,
    required List<String> userMemories,
    required String mode,
    String? contextData,
    String? customPersona,
    String? aiModel,
    String? currencyCode,
    String? currencySymbol,
  }) async {
    if (_apiKey.isEmpty) return "Error: API Key missing in .env";

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    // Model Resolution
    String selectedModel = _model; // Default gpt-4o
    if (aiModel == 'Daily') {
      selectedModel = "gpt-4o-mini";
    } else if (aiModel == 'Pro') {
      selectedModel = "gpt-4o";
    } else {
      // Auto logic: use faster mini for simple chats, pro for commands/memories
      if (userMemories.isNotEmpty || (contextData != null && contextData.isNotEmpty)) {
        selectedModel = "gpt-4o";
      } else {
        selectedModel = "gpt-4o-mini";
      }
    }

    final List<Map<String, String>> messages = [];

    // 1. Build System Context
    String fullSystemContext =
        _getSystemPrompt(mode, customPersona: customPersona, currencyCode: currencyCode, currencySymbol: currencySymbol);
    if (userMemories.isNotEmpty) {
      fullSystemContext += "\n\nUser Memories: ${userMemories.join(', ')}";
    }
    if (contextData != null && contextData.isNotEmpty) {
      fullSystemContext += "\n\nCURRENT APP DATA:\n$contextData";
    }

    messages.add({"role": "system", "content": fullSystemContext});

    // 2. Add Chat History
    for (var msg in history) {
      messages.add(
          {"role": msg.isUser ? "user" : "assistant", "content": msg.text});
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey'
        },
        body: jsonEncode({
          "model": selectedModel,
          "messages": messages,
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'];
        }
      }
      return "Error: ${response.statusCode}";
    } catch (e) {
      return "Error: $e";
    }
  }

  /// Generates a morning AI briefing summary based on user tasks, events, notes, and budget.
  Future<String> generateMorningBriefing({
    required List<String> tasks,
    required List<String> events,
    required List<String> trips,
    required double monthSpend,
    String? currencyCode,
    String? currencySymbol,
  }) async {
    final curCode = currencyCode ?? StorageService.loadSelectedCurrency();
    final curSymbol = currencySymbol ?? AppCurrency.getSymbol(curCode);

    final prompt = """
Generate a warm, inspiring 3-paragraph Morning Life Briefing for the user.
Today's Date: ${DateTime.now().toLocal().toString().split(' ')[0]}

Context Data:
- Pending Tasks: ${tasks.join(', ')}
- Today's Events: ${events.join(', ')}
- Active Trips: ${trips.join(', ')}
- Monthly Spend: $curSymbol${monthSpend.toStringAsFixed(2)} ($curCode)

Requirements:
1. Start with an energetic greeting & daily vibe quote.
2. Highlight key priorities (tasks/events) & trip reminders.
3. End with a quick financial check & encouraging closing sentence in $curCode ($curSymbol). Use emojis!
""";

    return await sendMessage(
      history: [ChatMessage(id: '1', text: prompt, isUser: true, timestamp: DateTime.now())],
      userMemories: [],
      mode: 'Assistant',
      currencyCode: curCode,
      currencySymbol: curSymbol,
    );
  }

  /// Auto-categorizes a note into a folder and generates #hashtags.
  Future<Map<String, dynamic>> autoCategorizeNote({
    required String title,
    required String content,
    required List<String> availableFolders,
  }) async {
    final prompt = """
Analyze the following note title & content and categorize it:
TITLE: $title
CONTENT: $content
AVAILABLE FOLDERS: ${availableFolders.join(', ')}

Return strictly a JSON object with two fields:
{
  "folder": "One of the available folders or best fit",
  "tags": ["#tag1", "#tag2", "#tag3"]
}
Only output valid JSON.
""";

    final res = await sendMessage(
      history: [ChatMessage(id: '1', text: prompt, isUser: true, timestamp: DateTime.now())],
      userMemories: [],
      mode: 'Editor',
    );

    try {
      final clean = res.replaceAll('```json', '').replaceAll('```', '').trim();
      return Map<String, dynamic>.from(jsonDecode(clean));
    } catch (_) {
      return {
        "folder": availableFolders.contains("General") ? "General" : availableFolders.first,
        "tags": ["#note", "#general"]
      };
    }
  }

  /// Parses receipt text into structured financial transaction details.
  Future<Map<String, dynamic>> parseReceiptText(String receiptText, {String? defaultCurrency}) async {
    final curCode = defaultCurrency ?? StorageService.loadSelectedCurrency();
    final curSymbol = AppCurrency.getSymbol(curCode);

    final prompt = """
Extract transaction details from the following receipt text:
RECEIPT TEXT:
$receiptText

Return strictly a JSON object formatted as:
{
  "merchant": "Store Name",
  "amount": 0.00,
  "currency": "$curCode",
  "category": "Food|Shopping|Transport|Health|Entertainment|Other",
  "items": ["Item 1 ($curSymbol X)", "Item 2 ($curSymbol Y)"]
}
Only output valid JSON.
""";

    final res = await sendMessage(
      history: [ChatMessage(id: '1', text: prompt, isUser: true, timestamp: DateTime.now())],
      userMemories: [],
      mode: 'Editor',
      currencyCode: curCode,
      currencySymbol: curSymbol,
    );

    try {
      final clean = res.replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = Map<String, dynamic>.from(jsonDecode(clean));
      if (parsed['currency'] == null) {
        parsed['currency'] = curCode;
      }
      return parsed;
    } catch (_) {
      return {
        "merchant": "Store Receipt",
        "amount": 15.50,
        "currency": curCode,
        "category": "Shopping",
        "items": ["Receipt Items"]
      };
    }
  }
}
