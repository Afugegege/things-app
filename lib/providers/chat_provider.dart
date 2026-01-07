import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/note_model.dart';
import '../models/task_model.dart';
import '../services/ai_service.dart';

// Providers
import 'notes_provider.dart';
import 'user_provider.dart';
import 'money_provider.dart';
import 'tasks_provider.dart'; 

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;

  void deleteMessage(String id) {
    _messages.removeWhere((msg) => msg.id == id);
    notifyListeners();
  }

  void saveMessageAsNote(String text, NotesProvider notesProvider) {
    // [FIX]: Convert plain text to Quill JSON Delta so the Editor can read it
    final String jsonContent = jsonEncode([
      {'insert': '$text\n'}
    ]);

    final newNote = Note(
      id: const Uuid().v4(),
      title: "AI Chat Note",
      content: jsonContent, // Saved as JSON
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folder: 'Uncategorised',
      backgroundColor: 0xFF1C1C1E,
    );
    notesProvider.addNote(newNote);
  }

  // --- COMMAND EXECUTION ---
  Future<void> executeCommand(String msgId, Map<String, dynamic> command, BuildContext context) async {
    final action = command['action'];
    
    // 1. SET LOADING STATE
    final index = _messages.indexWhere((m) => m.id == msgId);
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
      // 2. SWITCH ACTIONS
      switch (action) {
        
        // --- NOTE CREATION [FIXED] ---
        case 'create_note':
          final notesProvider = Provider.of<NotesProvider>(context, listen: false);
          final folderName = command['folder'] ?? 'Uncategorised';
          final rawContent = command['content'] ?? '';
          
          // [FIX]: Convert AI plain text response to Quill JSON Delta format
          // This ensures the NoteEditorScreen can load it without showing a blank page
          final String structuredContent = jsonEncode([
            {'insert': '$rawContent\n'}
          ]);

          notesProvider.createFolder(folderName);
          notesProvider.addNote(Note(
            id: const Uuid().v4(),
            title: command['title'] ?? 'Untitled',
            content: structuredContent, // Save structured JSON
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
          moneyProvider.addTransaction(command['title'] ?? 'Transaction', amount);
          break;

        // --- NOTE EDITING [FIXED] ---
        case 'edit_note':
          final notesProvider = Provider.of<NotesProvider>(context, listen: false);
          final searchTitle = command['search_title'] ?? '';
          
          final noteIndex = notesProvider.notes.indexWhere((n) => n.title.toLowerCase().contains(searchTitle.toLowerCase()));
          
          if (noteIndex != -1) {
            final originalNote = notesProvider.notes[noteIndex];
            String currentContent = originalNote.content;
            String newContentJson = currentContent;

            // [FIX]: Handle appending logic for JSON content
            if (command['append_content'] != null) {
              final String textToAppend = "\n${command['append_content']}";
              
              try {
                // Try to parse existing JSON
                List<dynamic> delta = jsonDecode(currentContent);
                // Add new insert op to the end
                delta.add({'insert': textToAppend});
                newContentJson = jsonEncode(delta);
              } catch (e) {
                // If existing wasn't JSON (legacy data), wrap both
                newContentJson = jsonEncode([
                  {'insert': '$currentContent$textToAppend'}
                ]);
              }
            } else if (command['new_content'] != null) {
              // Replace content completely
              newContentJson = jsonEncode([
                {'insert': '${command['new_content']}\n'}
              ]);
            }

            final updatedNote = originalNote.copyWith(
              content: newContentJson,
              updatedAt: DateTime.now(),
            );
            
            notesProvider.updateNote(updatedNote);
          } else {
            throw Exception("Note '$searchTitle' not found.");
          }
          break;

        case 'update_task':
        case 'complete_task':
        case 'delete_task':
          final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
          final searchTitle = command['original_title'] ?? command['title'] ?? '';
          
          final taskIndex = tasksProvider.tasks.indexWhere((t) => t.title.toLowerCase().contains(searchTitle.toLowerCase()));
          
          if (taskIndex != -1) {
            final task = tasksProvider.tasks[taskIndex];
            
            if (action == 'delete_task') {
              tasksProvider.deleteTask(task.id);
            } else if (action == 'complete_task') {
              tasksProvider.toggleTask(task.id);
            } else {
              final newTitle = command['new_title'] ?? task.title;
              final newPriority = command['priority'] ?? task.priority;
              tasksProvider.updateTask(task.copyWith(title: newTitle, priority: newPriority));
            }
          } else {
             throw Exception("Task '$searchTitle' not found.");
          }
          break;
      }
      
      // 3. SET SUCCESS STATE
      if (index != -1) {
        final successJson = Map<String, dynamic>.from(command);
        successJson['status'] = 'success';
        _messages[index] = ChatMessage(
          id: _messages[index].id,
          text: jsonEncode(successJson),
          isUser: false,
          timestamp: _messages[index].timestamp
        );
        notifyListeners();
      }

    } catch (e) {
      if (index != -1) {
        _messages[index] = ChatMessage(
          id: _messages[index].id,
          text: "I tried, but ran into an issue: $e",
          isUser: false,
          timestamp: _messages[index].timestamp
        );
        notifyListeners();
      }
    }
  }

  // --- SEND LOGIC ---
  Future<void> sendMessage({required String message, required List<String> userMemories}) async {
    final userMsg = ChatMessage(id: const Uuid().v4(), text: message, isUser: true, timestamp: DateTime.now());
    _messages.insert(0, userMsg);
    _isTyping = true;
    notifyListeners();

    try {
      final aiService = AiService();
      final responseText = await aiService.sendMessage(
        history: _messages.reversed.toList(), 
        userMemories: userMemories
      );

      final aiMsg = ChatMessage(id: const Uuid().v4(), text: responseText, isUser: false, timestamp: DateTime.now());
      _messages.insert(0, aiMsg);
      
    } catch (e) {
      _messages.insert(0, ChatMessage(id: const Uuid().v4(), text: "Error: $e", isUser: false, timestamp: DateTime.now()));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }
}