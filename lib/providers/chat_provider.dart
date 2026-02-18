import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/note_model.dart';
import '../models/task_model.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

// Providers
import 'notes_provider.dart';
import 'user_provider.dart';
import 'money_provider.dart';
import 'tasks_provider.dart'; 
import '../utils/markdown_to_quill.dart'; // [ADDED] 

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  
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
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading chat history: $e");
    }
  }

  Future<void> regenerateLastResponse(BuildContext context, {required List<String> userMemories, required String mode}) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    if (_messages.isEmpty || _messages.first.isUser) return;

    // 1. Remove the last AI response
    _messages.removeAt(0);
    notifyListeners();

    // 2. Get the last user message to retry
    if (_messages.isEmpty) return; // Should not happen if flow is correct
    final lastUserMsg = _messages.first;
    if (!lastUserMsg.isUser) return; // Safety check

    // 3. Re-send
    // We remove the user message temporarily because sendMessage adds it back?
    // Actually sendMessage adds a NEW user message. We don't want that.
    // We want to call the AI service directly and add the AI response.
    
    _isTyping = true;
    notifyListeners();
    
    // Construct context again
    String contextData = "";
    if (mode == 'Finance') {
       // contextData = "Recent Transactions: []"; 
    }

    try {
      final aiService = AiService();
      // History should exclude the recently removed AI message (already done)
      // AND we need to make sure we don't duplicate the user message in the input history if sendMessage normally handles it.
      // aiService.sendMessage expects 'history' to be the previous chat.
      
      final responseText = await aiService.sendMessage(
        history: _messages.reversed.toList(), // Pass full history including the last user message
        userMemories: userMemories,
        mode: mode,
        contextData: contextData,
        customPersona: mode == 'Roleplay' ? userProvider.user.customPersona : null,
      );

      final aiMsg = ChatMessage(id: const Uuid().v4(), text: responseText, isUser: false, timestamp: DateTime.now());
      _messages.insert(0, aiMsg);
      _save();
      
    } catch (e) {
      _messages.insert(0, ChatMessage(id: const Uuid().v4(), text: "Regeneration Error: $e", isUser: false, timestamp: DateTime.now()));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  void _save() {
    StorageService.saveChatHistory(_messages.map((m) => m.toMap()).toList());
  }

  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;

  void deleteMessage(String id) {
    _messages.removeWhere((msg) => msg.id == id);
    _save();
    notifyListeners();
  }

  void saveMessageAsNote(String text, NotesProvider notesProvider) {
    // Clean text to remove JSON if present
    String cleanText = text;
    if (text.trim().startsWith('{') && text.contains('"action"')) {
       // It's a command, don't save the JSON, save the result description
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

  // --- COMMAND EXECUTION ---
  Future<void> executeCommand(String msgId, Map<String, dynamic> command, BuildContext context) async {
    final action = command['action'];
    final index = _messages.indexWhere((m) => m.id == msgId);
    
    // 1. SET LOADING
    if (index != -1) {
      final loadingJson = Map<String, dynamic>.from(command);
      loadingJson['status'] = 'loading';
      _messages[index] = ChatMessage(
        id: _messages[index].id,
        text: jsonEncode(loadingJson),
        isUser: false,
        timestamp: _messages[index].timestamp
      );
      notifyListeners();
    }

    await Future.delayed(const Duration(milliseconds: 800)); 

    try {
      switch (action) {
        case 'create_note':
        case 'save_note': 
          final notesProvider = Provider.of<NotesProvider>(context, listen: false);
          final folderName = command['folder'] ?? 'Uncategorised';
          
          String rawContent = '';
          String title = command['title'] ?? 'Untitled'; 

          if (command['content'] is Map) {
            rawContent = command['content']['body'] ?? '';
            if (command['content']['title'] != null) title = command['content']['title'];
          } else {
            rawContent = command['content'] ?? '';
          }
          
          final delta = markdownToQuill(rawContent).toDelta();
          final String structuredContent = jsonEncode(delta.toJson());

          notesProvider.addFolder(folderName);
          notesProvider.addNote(Note(
            id: const Uuid().v4(),
            title: title,
            content: structuredContent, 
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            folder: folderName,
          ));
          break;

        case 'create_task':
          final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
          tasksProvider.addTask(Task(
            id: const Uuid().v4(),
            title: command['title'] ?? 'New Task',
            isDone: false,
            createdAt: DateTime.now(),
            priority: command['priority'] ?? 1,
          ));
          break;

        case 'add_transaction':
          final moneyProvider = Provider.of<MoneyProvider>(context, listen: false);
          double amount = double.tryParse(command['amount'].toString()) ?? 0.0;
          String category = command['category'] ?? 'General';
          
          // [FIX] Parse the date if the AI provided it
          DateTime? customDate;
          if (command['date'] != null) {
            customDate = DateTime.tryParse(command['date']);
          }

          moneyProvider.addTransaction(
            command['title'] ?? 'Transaction', 
            amount, 
            category,
            date: customDate
          );
          break;
          
        case 'edit_note':
           // ... (Existing edit logic)
           break;
           break;
          
        case 'remember':
           final userProvider = Provider.of<UserProvider>(context, listen: false);
           if (command['fact'] != null) {
             userProvider.addMemory(command['fact']);
           }
           break;
      }
      
      // 2. SET SUCCESS
      if (index != -1) {
        final successJson = Map<String, dynamic>.from(command);
        successJson['status'] = 'success';
        _messages[index] = ChatMessage(
          id: _messages[index].id,
          text: jsonEncode(successJson),
          isUser: false,
          timestamp: _messages[index].timestamp
        );

        _save();
        notifyListeners();
      }

    } catch (e) {
      if (index != -1) {
        _messages[index] = ChatMessage(
          id: _messages[index].id,
          text: "Error: $e",
          isUser: false,
          timestamp: _messages[index].timestamp
        );
        notifyListeners();
      }
    }
  }

  // --- SEND LOGIC ---

  Future<void> sendMessage({
    required String message, 
    required List<String> userMemories,
    required String mode,
    String? customPersona, // [NEW]
  }) async {
    final userMsg = ChatMessage(id: const Uuid().v4(), text: message, isUser: true, timestamp: DateTime.now());
    _messages.insert(0, userMsg);
    _isTyping = true;

    _save();
    notifyListeners();

    String contextData = "";
    
    if (mode == 'Finance') {
       // contextData = "Recent Transactions: []"; 
    }

    try {
      final aiService = AiService();
      final responseText = await aiService.sendMessage(
        history: _messages.reversed.toList(), 
        userMemories: userMemories,
        mode: mode,
        contextData: contextData,
        customPersona: customPersona,
      );

      final aiMsg = ChatMessage(id: const Uuid().v4(), text: responseText, isUser: false, timestamp: DateTime.now());
      _messages.insert(0, aiMsg);
      _save();
      
    } catch (e) {
      _messages.insert(0, ChatMessage(id: const Uuid().v4(), text: "Connection Error: $e", isUser: false, timestamp: DateTime.now()));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }
}