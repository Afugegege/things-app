import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/note_model.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../core/ai_response_parser.dart';

// Providers
import 'notes_provider.dart';
import 'user_provider.dart';
import '../utils/markdown_to_quill.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  // Stores parsed responses keyed by message ID
  final Map<String, ParsedAiResponse> _parsedResponses = {};

  ChatProvider() {
    _loadHistory();
  }

  void _loadHistory() {
    try {
      final history = StorageService.loadChatHistory();
      for (var m in history) {
        try {
          _messages.add(ChatMessage.fromMap(m));
        } catch (e) {
          debugPrint("Error loading chat message: $e");
        }
      }
      // Re-parse stored AI messages
      for (final msg in _messages) {
        if (!msg.isUser) {
          _parsedResponses[msg.id] = AiResponseParser.parse(msg.text);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading chat history: $e");
    }
  }

  void _save() {
    StorageService.saveChatHistory(_messages.map((m) => m.toMap()).toList());
  }

  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;

  /// Get the parsed response for a given AI message ID.
  ParsedAiResponse? getParsedResponse(String messageId) {
    return _parsedResponses[messageId];
  }

  void deleteMessage(String id) {
    _messages.removeWhere((msg) => msg.id == id);
    _parsedResponses.remove(id);
    _save();
    notifyListeners();
  }

  void saveMessageAsNote(String text, NotesProvider notesProvider) {
    String cleanText = text;
    if (text.trim().startsWith('{') && text.contains('"action"')) {
      cleanText = "AI Action Result";
    }

    final delta = markdownToQuill(cleanText).toDelta();
    final String jsonContent = jsonEncode(delta.toJson());

    final newNote = Note(
      id: const Uuid().v4(),
      title: "AI Conversation",
      content: jsonContent,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: 'Ideas',
      backgroundColor: 0xFF1C1C1E,
    );
    notesProvider.addNote(newNote);
  }

  // --- REGENERATE ---
  Future<void> regenerateLastResponse(BuildContext context, {required List<String> userMemories, required String mode, String? aiModel}) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (_messages.isEmpty || _messages.first.isUser) return;

    // Remove the last AI response
    final removedId = _messages.first.id;
    _messages.removeAt(0);
    _parsedResponses.remove(removedId);
    notifyListeners();

    if (_messages.isEmpty) return;
    final lastUserMsg = _messages.first;
    if (!lastUserMsg.isUser) return;

    _isTyping = true;
    notifyListeners();

    try {
      final currency = StorageService.loadSelectedCurrency();
      final aiService = AiService();
      final responseText = await aiService.sendMessage(
        history: _messages.reversed.toList(),
        userMemories: userMemories,
        mode: mode,
        customPersona: mode == 'Roleplay' ? userProvider.user.customPersona : null,
        aiModel: aiModel,
        currencyCode: currency,
      );

      final aiMsg = ChatMessage(id: const Uuid().v4(), text: responseText, isUser: false, timestamp: DateTime.now());
      _messages.insert(0, aiMsg);

      // Parse the response through the new pipeline
      _parsedResponses[aiMsg.id] = AiResponseParser.parse(responseText, userPrompt: lastUserMsg.text);

      _save();
    } catch (e) {
      _messages.insert(0, ChatMessage(id: const Uuid().v4(), text: "Regeneration Error: $e", isUser: false, timestamp: DateTime.now()));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // --- SEND LOGIC ---
  Future<void> sendMessage({
    required String message,
    required List<String> userMemories,
    required String mode,
    String? customPersona,
    String? aiModel,
    String? currencyCode,
  }) async {
    final userMsg = ChatMessage(id: const Uuid().v4(), text: message, isUser: true, timestamp: DateTime.now());
    _messages.insert(0, userMsg);
    _isTyping = true;

    _save();
    notifyListeners();

    String contextData = "";
    final cur = currencyCode ?? StorageService.loadSelectedCurrency();

    try {
      final aiService = AiService();
      final responseText = await aiService.sendMessage(
        history: _messages.reversed.toList(),
        userMemories: userMemories,
        mode: mode,
        contextData: contextData,
        customPersona: customPersona,
        aiModel: aiModel,
        currencyCode: cur,
      );

      final aiMsg = ChatMessage(id: const Uuid().v4(), text: responseText, isUser: false, timestamp: DateTime.now());
      _messages.insert(0, aiMsg);

      // Parse the response through the new pipeline with userPrompt
      _parsedResponses[aiMsg.id] = AiResponseParser.parse(responseText, userPrompt: message);

      _save();
    } catch (e) {
      _messages.insert(0, ChatMessage(id: const Uuid().v4(), text: "Connection Error: $e", isUser: false, timestamp: DateTime.now()));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }
}