import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_model.dart';

class AiService {
  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? ""; 
  final String _model = "gpt-4o"; 

  // --- DYNAMIC SYSTEM PROMPTS ---
  String _getSystemPrompt(String mode) {
    String persona = "";
    
    switch (mode) {
      case 'Counselor':
        persona = "You are an empathetic counselor. Focus on mental well-being, listening, and emotional support.";
        break;
      case 'Health (Pulse)':
        persona = "You are an elite Health Coach & Medical AI. Analyze health logs (Nutrition, Sleep, Symptoms) to provide actionable, medical-grade (but safe) advice.";
        break;
      case 'Nutritionist':
        persona = "You are an expert Dietitian. Estimate calories/macros from food descriptions. Return ONLY JSON for food logs.";
        break;
      case 'Finance':
        persona = "You are a pragmatic Financial Advisor. Focus on budgeting, saving, and expense tracking.";
        break;
      default: // Assistant
        persona = "You are 'Things', an intelligent Life OS. You are productive, sharp, and concise.";
        break;
    }

    // Get current date so AI can calculate "yesterday"
    final now = DateTime.now();
    final dateContext = "Current Date/Time: ${now.toIso8601String()}";

    return """
    $persona
    
    $dateContext
    
    Your goal is to organize the user's life by managing Notes, Tasks, Money, and Health via JSON commands.
    
    CRITICAL INSTRUCTION FOR NOTES:
    If the user asks to create or save a note but DOES NOT provide a specific title, you MUST generate a short, descriptive title (3-5 words) based on the content. NEVER use "Untitled".
    
    INSTRUCTIONS:
    If the user wants to perform an action, return a JSON object with the specific "action".
    
    Actions:
    1. {"action": "create_note", "title": " inferred title", "folder": "category", "content": "body"}
    2. {"action": "create_task", "title": "task name", "priority": 1-3}
    
    3. {"action": "add_transaction", "title": "item", "amount": -0.00, "category": "General", "date": "ISO8601_String"}
       ^ CRITICAL: If the user says "yesterday" or specifies a time, calculate the exact ISO8601 date based on the Current Date/Time provided above and put it in the "date" field.

    4. {"action": "log_food", "name": "food item", "calories": 0, "protein": 0, "carbs": 0, "fat": 0} 
       ^ CRITICAL: Only use this in 'Nutritionist' mode. Estimate values if not provided.
    
    If the user just wants to chat, return plain text.
    """;
  }

  Future<String> sendMessage({
    required List<ChatMessage> history, 
    required List<String> userMemories,
    required String mode, 
    String? contextData,  
  }) async {
    if (_apiKey.isEmpty) return "Error: API Key missing in .env";

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');    
    
    final List<Map<String, String>> messages = [];
    
    // 1. Build System Context
    String fullSystemContext = _getSystemPrompt(mode);
    if (userMemories.isNotEmpty) {
      fullSystemContext += "\n\nUser Memories: ${userMemories.join(', ')}";
    }
    if (contextData != null && contextData.isNotEmpty) {
      fullSystemContext += "\n\nCURRENT APP DATA:\n$contextData";
    }

    messages.add({"role": "system", "content": fullSystemContext});
    
    // 2. Add Chat History
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

  Future<List<Map<String, String>>> generateFlashcards(String topic) async {
    if (_apiKey.isEmpty) return [];
    
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    
    final systemPrompt = """
You are a flashcard generator. Generate 10-15 high-quality flashcards about the given topic.

CRITICAL: Return ONLY a valid JSON array with no markdown formatting or code blocks.
Format: [{"q":"question","a":"answer"},{"q":"question","a":"answer"},...]

Make questions clear and concise. Answers should be accurate and brief (1-3 sentences max).
""";

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey'
        },
        body: jsonEncode({
          "model": _model,
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": "Generate flashcards about: $topic"}
          ],
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        
        // Clean potential markdown formatting
        String cleaned = content.trim();
        if (cleaned.startsWith('```json')) {
          cleaned = cleaned.substring(7);
        } else if (cleaned.startsWith('```')) {
          cleaned = cleaned.substring(3);
        }
        if (cleaned.endsWith('```')) {
          cleaned = cleaned.substring(0, cleaned.length - 3);
        }
        cleaned = cleaned.trim();
        
        final List<dynamic> cards = jsonDecode(cleaned);
        return cards.map((c) => {
          'q': c['q'].toString(),
          'a': c['a'].toString()
        }).toList();
      }
      return [];
    } catch (e) {
      print('Flashcard generation error: $e');
      return [];
    }
  }
}