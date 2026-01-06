import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../providers/notes_provider.dart';
import '../../models/note_model.dart';
import '../../widgets/dashboard_drawer.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/smart_widgets/widget_factory.dart';
import '../notes/note_editor_screen.dart';

class BrainScreen extends StatefulWidget {
  const BrainScreen({super.key});

  @override
  State<BrainScreen> createState() => _BrainScreenState();
}

class _BrainScreenState extends State<BrainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  bool _isSearching = false;
  bool _showFilters = false; 
  final TextEditingController _searchController = TextEditingController();
  
  // SELECTION STATE
  bool _isMultiSelect = false;
  final Set<String> _selectedIds = {};

  String _activeFilter = "All"; 

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);
    List<Note> displayedNotes = notesProvider.notes;

    // Filter Logic
    if (_isSearching && _searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      displayedNotes = displayedNotes.where((n) => 
        n.title.toLowerCase().contains(query) || 
        n.plainTextContent.toLowerCase().contains(query)
      ).toList();
    }

    if (_activeFilter == "Audio") {
      displayedNotes = displayedNotes.where((n) => 
        n.content.contains('[[audio]]') || n.title.toLowerCase().contains('voice')
      ).toList();
    } else if (_activeFilter == "Visual") {
      displayedNotes = displayedNotes.where((n) => 
        !n.content.contains('[[audio]]') && !n.title.toLowerCase().contains('voice')
      ).toList();
    }

    return Scaffold(
      key: _scaffoldKey, 
      backgroundColor: Colors.black,
      drawer: const DashboardDrawer(), 
      
      floatingActionButton: _isMultiSelect ? null : FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditorScreen())),
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black),
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
                      if (_isMultiSelect)
                        IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _exitMultiSelect)
                      else
                        IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
                      
                      Text(
                        _isMultiSelect ? "${_selectedIds.length} Selected" : "BRAIN", 
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)
                      ),
                      
                      if (!_isMultiSelect)
                        Row(children: [
                          IconButton(
                            icon: Icon(_isSearching ? Icons.close : CupertinoIcons.search, color: Colors.white),
                            onPressed: () => setState(() { _isSearching = !_isSearching; if(!_isSearching) _searchController.clear(); }),
                          ),
                          IconButton(
                            icon: Icon(Icons.filter_list, color: _showFilters ? Colors.blueAccent : Colors.white),
                            onPressed: () => setState(() => _showFilters = !_showFilters),
                          ),
                        ])
                      else
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteSelected(notesProvider)),
                    ],
                  ),

                  if (_isSearching)
                    GlassContainer(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      height: 50,
                      borderRadius: 15,
                      opacity: 0.15,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: "Search...", border: InputBorder.none, icon: Icon(Icons.search, color: Colors.white38)),
                        onChanged: (v) => setState(() {}),
                      ),
                    ),

                  if (_showFilters)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          _buildFilterChip("All"),
                          const SizedBox(width: 10),
                          _buildFilterChip("Visual"),
                          const SizedBox(width: 10),
                          _buildFilterChip("Audio"),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // --- GRID ---
            Expanded(
              child: displayedNotes.isEmpty
                  ? Center(child: Text("No notes found", style: TextStyle(color: Colors.white.withOpacity(0.3))))
                  : MasonryGridView.count(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 100),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      itemCount: displayedNotes.length,
                      itemBuilder: (context, index) {
                        final note = displayedNotes[index];
                        final isSelected = _selectedIds.contains(note.id);
                        
                        return GestureDetector(
                          onTap: () {
                            if (_isMultiSelect) _toggleSelection(note.id);
                            else Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
                          },
                          onLongPress: () {
                            setState(() {
                              _isMultiSelect = true;
                              _selectedIds.add(note.id);
                            });
                          },
                          child: Stack(
                            children: [
                              WidgetFactory.build(context, note),
                              if (_isMultiSelect)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      border: isSelected ? Border.all(color: Colors.blueAccent, width: 3) : null,
                                    ),
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.all(10),
                                    child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: Colors.white),
                                  ),
                                ),
                              if (note.isPinned && !_isMultiSelect)
                                const Positioned(top: 10, right: 10, child: Icon(CupertinoIcons.pin_fill, color: Colors.white54, size: 14)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      
      bottomSheet: _isMultiSelect ? Container(
        color: const Color(0xFF1C1C1E),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(CupertinoIcons.pin, color: Colors.white), onPressed: () {
                for (var id in _selectedIds) notesProvider.togglePin(id);
                _exitMultiSelect();
            }),
            if (_selectedIds.length > 1)
              IconButton(icon: const Icon(Icons.merge_type, color: Colors.white), onPressed: () {
                  notesProvider.mergeNotes(_selectedIds.toList());
                  _exitMultiSelect();
              }),
            IconButton(icon: const Icon(CupertinoIcons.delete, color: Colors.redAccent), onPressed: () => _deleteSelected(notesProvider)),
          ],
        ),
      ) : null,
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isMultiSelect = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() { _isMultiSelect = false; _selectedIds.clear(); });
  }

  void _deleteSelected(NotesProvider provider) {
    provider.deleteNotes(_selectedIds.toList());
    _exitMultiSelect();
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}