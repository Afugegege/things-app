import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../providers/notes_provider.dart';
import '../../models/note_model.dart';
import '../../widgets/dashboard_drawer.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart'; // [UPDATED]
import '../../widgets/smart_widgets/widget_factory.dart';
import '../notes/note_editor_screen.dart';

class BrainScreen extends StatefulWidget {
  const BrainScreen({super.key});

  @override
  State<BrainScreen> createState() => _BrainScreenState();
}

class _BrainScreenState extends State<BrainScreen> {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

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

    // [UPDATED] Use LifeAppScaffold
    return LifeAppScaffold(
      // Dynamic Title
      title: _isMultiSelect ? "${_selectedIds.length} SELECTED" : "BRAIN",
      
      // Header Actions
      actions: [
        if (_isMultiSelect)
          IconButton(icon: const Icon(CupertinoIcons.clear_circled), onPressed: _exitMultiSelect)
        else ...[
          IconButton(
            icon: Icon(_isSearching ? CupertinoIcons.clear : CupertinoIcons.search, color: textColor),
            onPressed: () => setState(() { 
              _isSearching = !_isSearching; 
              if (!_isSearching) _searchController.clear(); 
            }),
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: _showFilters ? Colors.blueAccent : textColor),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ]
      ],

      // Floating Action Button
      floatingActionButton: _isMultiSelect ? null : Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditorScreen())),
          backgroundColor: isDark ? Colors.white : Colors.black, // High Contrast
          elevation: 0,
          shape: const CircleBorder(),
          child: Icon(CupertinoIcons.add, color: isDark ? Colors.black : Colors.white, size: 28),
        ),
      ),

      // Multi-Select Bottom Sheet
      bottomSheet: _isMultiSelect ? Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25), 
          border: Border.all(color: theme.dividerColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(CupertinoIcons.pin, color: Colors.orangeAccent), onPressed: () {
                for (var id in _selectedIds) notesProvider.togglePin(id);
                _exitMultiSelect();
            }),
            if (_selectedIds.length > 1)
              IconButton(icon: const Icon(CupertinoIcons.arrow_merge, color: Colors.blueAccent), onPressed: () {
                  notesProvider.mergeNotes(_selectedIds.toList());
                  _exitMultiSelect();
              }),
            IconButton(icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent), onPressed: () => _deleteSelected(notesProvider)),
          ],
        ),
      ) : null,

      child: Column(
        children: [
          const SizedBox(height: 10),

          // SEARCH BAR (Fixed top style)
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: GlassContainer(
                height: 50,
                borderRadius: 15,
                opacity: isDark ? 0.2 : 0.05,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor),
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: "Search thoughts...", 
                    border: InputBorder.none, 
                    prefixIcon: Icon(CupertinoIcons.search, color: secondaryTextColor, size: 20),
                    hintStyle: TextStyle(color: secondaryTextColor),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    isCollapsed: true,
                  ),
                  onChanged: (v) => setState(() {}),
                ),
              ),
            ),

          // FILTERS
          if (_showFilters && !_isMultiSelect)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildFilterChip("All"),
                  _buildFilterChip("Visual"),
                  _buildFilterChip("Audio"),
                ],
              ),
            ),

          const SizedBox(height: 15),

          // NOTE GRID
          Expanded(
            child: displayedNotes.isEmpty
                ? Center(child: Text("No thoughts found.", style: TextStyle(color: secondaryTextColor)))
                : MasonryGridView.count(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 100),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
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
                        child: AnimatedScale(
                          scale: isSelected ? 0.95 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Stack(
                            children: [
                              AbsorbPointer(absorbing: _isMultiSelect, child: WidgetFactory.build(context, note)),
                              
                              // Selection Overlay
                              if (_isMultiSelect)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: isSelected ? Border.all(color: Colors.blueAccent, width: 3) : null,
                                    ),
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.all(10),
                                    child: Icon(isSelected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle, color: Colors.white),
                                  ),
                                ),

                              // Pin Indicator
                              if (note.isPinned && !_isMultiSelect)
                                const Positioned(
                                  top: 10, right: 10, 
                                  child: Icon(CupertinoIcons.pin_fill, color: Colors.orangeAccent, size: 14)
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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
    for (var id in _selectedIds) {
      provider.deleteNotes(id);
    }
    _exitMultiSelect();
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _activeFilter == label;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? textColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : theme.dividerColor),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? theme.scaffoldBackgroundColor : textColor.withOpacity(0.7), 
            fontWeight: FontWeight.bold, 
            fontSize: 12
          )
        ),
      ),
    );
  }
}