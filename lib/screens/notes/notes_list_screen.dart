import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../providers/notes_provider.dart';
import '../../models/note_model.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState>? parentScaffoldKey;
  const NotesListScreen({super.key, this.parentScaffoldKey});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isGrid = true; 

  final Map<String, Color> _folderColors = {
    'Uncategorised': const Color(0xFFE0E0E0),
    'Personal': const Color(0xFFFDE8B5), 
    'Work': const Color(0xFFD6E4FF),     
    'Ideas': const Color(0xFFE2F0CB),    
    'Journal': const Color(0xFFFFCCF8),
  };

  Color _getFolderColor(String folderName) {
    if (_folderColors.containsKey(folderName)) return _folderColors[folderName]!;
    return const Color(0xFFE0E0E0);
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);
    List<Note> displayedNotes = notesProvider.notes;
    
    // Search Logic
    if (_isSearching && _searchController.text.isNotEmpty) {
      displayedNotes = displayedNotes.where((note) {
        final query = _searchController.text.toLowerCase();
        return note.title.toLowerCase().contains(query) || 
               note.plainTextContent.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.black, size: 30),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditorScreen())),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                        onPressed: () => widget.parentScaffoldKey?.currentState?.openDrawer(),
                      ),
                      Expanded(
                        child: Text(
                          _isSearching ? "Search" : notesProvider.selectedFolder,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_isSearching ? Icons.close : CupertinoIcons.search, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) _searchController.clear();
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(_isGrid ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2, color: Colors.white),
                        onPressed: () => setState(() => _isGrid = !_isGrid),
                      ),
                    ],
                  ),
                  if (_isSearching)
                    Container(
                      margin: const EdgeInsets.only(top: 15),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        autofocus: true,
                        decoration: const InputDecoration(hintText: "Search...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none, icon: Icon(Icons.search, color: Colors.white54)),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                ],
              ),
            ),

            // --- NOTE LIST ---
            Expanded(
              child: displayedNotes.isEmpty
                  ? Center(child: Text("No notes found", style: TextStyle(color: Colors.white.withOpacity(0.3))))
                  : _isGrid 
                      ? MasonryGridView.count(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          itemCount: displayedNotes.length,
                          itemBuilder: (context, index) => _buildNoteCard(context, displayedNotes[index]),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
                          itemCount: displayedNotes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            // FIX: List items wrap content so they don't crash
                            return _buildNoteCard(context, displayedNotes[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note) {
    Color bgColor = const Color(0xFF1C1C1E);
    Color textColor = Colors.white;
    
    if (note.isPinned) {
      bgColor = _getFolderColor(note.folder);
      textColor = Colors.black87;
    }
    if (note.backgroundColor != null) {
      bgColor = Color(note.backgroundColor!);
      textColor = ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark ? Colors.white : Colors.black87;
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note))),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: note.isPinned ? null : Border.all(color: Colors.white12),
          image: note.backgroundImage != null 
             ? DecorationImage(image: FileImage(File(note.backgroundImage!)), fit: BoxFit.cover, opacity: 0.3)
             : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // FIX: Use min size for Column in Grid
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title.isNotEmpty ? note.title : "Untitled",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
                if (note.isPinned) Icon(CupertinoIcons.pin_fill, size: 14, color: textColor.withOpacity(0.6)),
              ],
            ),
            const SizedBox(height: 8),
            
            // FIX: Removed Expanded. Text now sizes itself naturally up to maxLines.
            Text(
              note.plainTextContent, 
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.7), height: 1.4),
            ),
            
            const SizedBox(height: 10),
            Text(
              "${note.createdAt.day}/${note.createdAt.month} • ${note.folder}",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}