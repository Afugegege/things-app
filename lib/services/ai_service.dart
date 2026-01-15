import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_model.dart';

class AiService {
  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? ""; 
  final String _model = "gpt-4o"; 

  // --- EXISTING SYSTEM PROMPT (Kept for Chat) ---
  final String _systemPrompt = """
  You are 'Things', an intelligent Life OS.
  Your goal is to organize the user's life by managing Notes, Tasks, and Money via JSON commands.
  
  INSTRUCTIONS:
  If the user wants to perform an action, return a JSON object with the specific "action".
  If the user just wants to chat, return plain text.
  
  (Keep existing actions...)
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

  // --- NEW: STUDENT FEATURES ---

  // Generate Flashcards from a topic or note content
  Future<List<Map<String, String>>> generateFlashcards(String topic) async {
    if (_apiKey.isEmpty) return [];

    const String flashcardPrompt = """
    Create 5-8 high-quality flashcards based on the user's input.
    Return ONLY a raw JSON array of objects with keys "q" (question) and "a" (answer).
    Keep answers concise (under 15 words).
    Example: [{"q": "Capital of France?", "a": "Paris"}, {"q": "H2O is?", "a": "Water"}]
    Do not include markdown formatting like ```json.
    """;

    try {
      final response = await http.post(
        Uri.parse('[https://api.openai.com/v1/chat/completions](https://api.openai.com/v1/chat/completions)'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'},
        body: jsonEncode({
          "model": _model,
          "messages": [
            {"role": "system", "content": flashcardPrompt},
            {"role": "user", "content": "Topic/Content: $topic"}
          ],
          "temperature": 0.5,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];
        // Clean potential markdown code blocks if the AI misbehaves
        final cleanJson = content.replaceAll('```json', '').replaceAll('```', '').trim();
        
        List<dynamic> parsed = jsonDecode(cleanJson);
        return parsed.map((item) => {"q": item['q'].toString(), "a": item['a'].toString()}).toList();
      }
    } catch (e) {
      print("AI Error: $e");
    }
    return [];
  }
}