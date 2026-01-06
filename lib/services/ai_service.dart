import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_model.dart';

class AiService {
  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? ""; 
  final String _model = "gpt-4o"; 

  // --- UPGRADED SYSTEM PROMPT ---
  final String _systemPrompt = """
  You are 'Things', an intelligent Life OS.
  Your goal is to organize the user's life by managing Notes, Tasks, and Money via JSON commands.

  INSTRUCTIONS:
  If the user wants to perform an action, return a JSON object with the specific "action".
  If the user just wants to chat, return plain text.

  AVAILABLE ACTIONS (JSON FORMAT):

  1. CREATE TASK:
  User: "Remind me to buy milk"
  Response: {"action": "create_task", "title": "Buy milk", "priority": 1} 

  2. EDIT TASK:
  User: "Change the milk task to high priority" or "Rename the milk task to Buy Almond Milk"
  Response: {"action": "update_task", "original_title": "Buy milk", "new_title": "Buy Almond Milk", "priority": 2}
  (Note: Try to fuzzy match the original_title from user context if possible)

  3. COMPLETE/DELETE TASK:
  User: "I bought the milk" or "Delete the milk task"
  Response: {"action": "complete_task", "title": "Buy milk"} (or "delete_task")

  4. LOG MONEY:
  User: "Spent \$50 on Dinner"
  Response: {"action": "add_transaction", "title": "Dinner", "amount": -50.0}

  5. CREATE NOTE:
  User: "Write a note about ideas"
  Response: {"action": "create_note", "title": "Ideas", "content": "...", "folder": "Uncategorised"}

  6. EDIT NOTE:
  User: "Add 'Buy eggs' to my Grocery List note" or "Rewrite my ideas note to be shorter"
  Response: {"action": "edit_note", "search_title": "Grocery List", "append_content": "- [ ] Buy eggs"} 
  OR (if replacing):
  Response: {"action": "edit_note", "search_title": "Ideas", "new_content": "Short content..."}

  RULES:
  - Return ONLY raw JSON for actions. No markdown blocks.
  - If the user asks to edit a specific note by ID (e.g. "Edit Note (ID: 123)"), prioritize using the ID if you can parse it, otherwise use title.
  """;

  Future<String> sendMessage({required List<ChatMessage> history, required List<String> userMemories}) async {
    if (_apiKey.isEmpty) return "Error: API Key missing in .env";

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');    
    
    final List<Map<String, String>> messages = [];
    messages.add({"role": "system", "content": "$_systemPrompt\n\nUser Memories: ${userMemories.join(', ')}"});
    
    for (var msg in history) {
      messages.add({"role": msg.isUser ? "user" : "assistant", "content": msg.text});
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json', 
          'Authorization': 'Bearer $_apiKey'
        },
        body: jsonEncode({
          "model": _model, 
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

  // Helpers
  Future<String> generateDiary(String prompt) async {
    return sendMessage(
      history: [ChatMessage(id: 'temp', text: "Write a short diary entry based on: $prompt", isUser: true, timestamp: DateTime.now())],
      userMemories: []
    );
  }

  Future<String> getEmojiForText(String content) async {
    return sendMessage(
      history: [ChatMessage(id: 'temp', text: "Analyze this and reply with ONE emoji: '$content'", isUser: true, timestamp: DateTime.now())],
      userMemories: []
    );
  }
}