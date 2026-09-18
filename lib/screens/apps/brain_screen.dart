import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../providers/notes_provider.dart';
import '../../models/note_model.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart'; // [UPDATED]
import '../../widgets/smart_widgets/widget_factory.dart';
import '../notes/note_editor_screen.dart';
import '../../widgets/common/minimalist_toast.dart';

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
  List<String> _sessionOrder = [];

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
      displayedNotes = displayedNotes
          .where((n) =>
              n.title.toLowerCase().contains(query) ||
              n.plainTextContent.toLowerCase().contains(query))
          .toList();
    }

    if (_activeFilter == "Audio") {
      displayedNotes = displayedNotes
          .where((n) =>
              n.content.contains('[[audio]]') ||
              n.title.toLowerCase().contains('voice'))
          .toList();
    } else if (_activeFilter == "Visual") {
      displayedNotes = displayedNotes
          .where((n) =>
              !n.content.contains('[[audio]]') &&
              !n.title.toLowerCase().contains('voice'))
          .toList();
    }

    // [PRESERVE SESSION ORDER]
    if (_isSearching && _searchController.text.isNotEmpty) {
      _sessionOrder.clear();
    } else if (_sessionOrder.isEmpty) {
      _sessionOrder = displayedNotes.map((n) => n.id).toList();
    } else {
      final currentMap = {for (var n in displayedNotes) n.id: n};
      final List<Note> orderedNotes = [];
      final List<String> updatedOrder = [];

      // Add any new notes first
      for (var n in displayedNotes) {
        if (!_sessionOrder.contains(n.id)) {
          orderedNotes.add(n);
          updatedOrder.add(n.id);
        }
      }

      // Maintain existing notes in session order
      for (var id in _sessionOrder) {
        if (currentMap.containsKey(id)) {
          orderedNotes.add(currentMap[id]!);
          updatedOrder.add(id);
        }
      }

      _sessionOrder = updatedOrder;
      displayedNotes = orderedNotes;
    }

    // [UPDATED] Use LifeAppScaffold
    return LifeAppScaffold(
      // Dynamic Title
      title: _isMultiSelect ? "${_selectedIds.length} SELECTED" : "NOTES",

      // Header Actions
      actions: [
        if (_isMultiSelect)
          IconButton(
              icon: const Icon(CupertinoIcons.clear_circled),
              onPressed: _exitMultiSelect)
        else ...[
          IconButton(
            icon: Icon(
                _isSearching ? CupertinoIcons.clear : CupertinoIcons.search,
                color: textColor),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
          ),
          IconButton(
            icon: Icon(Icons.filter_list,
                color: _showFilters ? (isDark ? Colors.white : Colors.black) : textColor),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ]
      ],

      // Floating Action Button
      floatingActionButton: _isMultiSelect
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 110),
              child: FloatingActionButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NoteEditorScreen())).then((_) {
                  if (mounted) setState(() => _sessionOrder.clear());
                }),
                backgroundColor:
                    isDark ? Colors.white : Colors.black, // High Contrast
                elevation: 0,
                shape: const CircleBorder(),
                child: Icon(CupertinoIcons.add,
                    color: isDark ? Colors.black : Colors.white, size: 28),
              ),
            ),

      // Multi-Select Bottom Sheet
      bottomSheet: _isMultiSelect
          ? (() {
              // MATCH DASHBOARD LOGIC
              final selectedNotesCount = _selectedIds
                  .where((id) => notesProvider.notes.any((n) => n.id == id))
                  .length;
              final canMerge = selectedNotesCount >= 2;

              return GlassContainer(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                height: 70,
                borderRadius: 35,
                opacity: isDark ? 0.2 : 0.05,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // MERGE
                    if (canMerge)
                      IconButton(
                          tooltip: "Merge Notes",
                          icon: Icon(Icons.merge, color: textColor),
                          onPressed: () {
                            notesProvider.mergeNotes(_selectedIds.toList());
                            _exitMultiSelect();
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Notes Merged!")));
                          }),

                    // PIN
                    IconButton(
                        icon: Icon(CupertinoIcons.pin, color: textColor),
                        onPressed: () {
                          for (var id in _selectedIds) {
                            notesProvider.togglePin(id);
                          }
                          _exitMultiSelect();
                        }),

                    // MOVE
                    IconButton(
                        tooltip: "Move to Folder",
                        icon: Icon(CupertinoIcons.folder_badge_plus,
                            color: textColor),
                        onPressed: () => _showFolderSelectionDialog(context)),

                    // DELETE
                    IconButton(
                        icon: Icon(CupertinoIcons.trash, color: textColor),
                        onPressed: () =>
                            _showDeleteConfirmation(context, notesProvider)),

                    // CLOSE
                    Container(width: 1, height: 30, color: theme.dividerColor),
                    IconButton(
                        icon: Icon(CupertinoIcons.xmark,
                            color: secondaryTextColor),
                        onPressed: _exitMultiSelect),
                  ],
                ),
              );
            }())
          : null,

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
                    prefixIcon: Icon(CupertinoIcons.search,
                        color: secondaryTextColor, size: 20),
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
                ? Center(
                    child: Text("No thoughts found.",
                        style: TextStyle(color: secondaryTextColor)))
                : MasonryGridView.count(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 180),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    itemCount: displayedNotes.length,
                    itemBuilder: (context, index) {
                      final note = displayedNotes[index];
                      final isSelected = _selectedIds.contains(note.id);

                      return GestureDetector(
                        onTap: () {
                          if (_isMultiSelect) {
                            _toggleSelection(note.id);
                          } else {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        NoteEditorScreen(note: note))).then((_) {
                              if (mounted) setState(() => _sessionOrder.clear());
                            });
                          }
                        },
                        onLongPress: () {
                          if (_isMultiSelect) {
                            _toggleSelection(note.id);
                            return;
                          }
                          _showNoteWidgetOptions(context, note);
                        },
                        child: AnimatedScale(
                          scale: isSelected ? 0.95 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Stack(
                            children: [
                              AbsorbPointer(
                                  absorbing: _isMultiSelect,
                                  child: WidgetFactory.build(context, note)),

                              // Selection Overlay
                              if (_isMultiSelect)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.2))
                                          : Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: isSelected
                                          ? Border.all(
                                              color: isDark ? Colors.white : Colors.black,
                                              width: 3)
                                          : null,
                                    ),
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.all(10),
                                    child: Icon(
                                        isSelected
                                            ? CupertinoIcons
                                                .check_mark_circled_solid
                                            : CupertinoIcons.circle,
                                        color: Colors.white),
                                  ),
                                ),

                              // Pin Indicator
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

  void _showNoteWidgetOptions(BuildContext context, Note note) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(
                note.isExpanded ? CupertinoIcons.fullscreen_exit : CupertinoIcons.fullscreen,
                color: textColor,
              ),
              title: Text(note.isExpanded ? "Collapse Note Widget" : "Expand Note Widget", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                notesProvider.toggleNoteExpansion(note.id);
              },
            ),
            ListTile(
              leading: Icon(
                note.isPinned ? CupertinoIcons.pin_slash_fill : CupertinoIcons.pin_fill,
                color: textColor,
              ),
              title: Text(note.isPinned ? "Unpin Note" : "Pin Note", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                notesProvider.togglePin(note.id);
              },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.checkmark_circle, color: textColor),
              title: Text("Select (Multiselect)", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _isMultiSelect = true;
                  _selectedIds.add(note.id);
                });
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
              title: const Text("Delete Note", style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                notesProvider.deleteNotes(note.id);
                MinimalistToast.showUndo(
                  context,
                  title: note.title.isNotEmpty ? note.title : "Note",
                  onUndo: () => notesProvider.restoreNote(note),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelect = false;
      _selectedIds.clear();
    });
  }

  void _deleteSelected(NotesProvider provider) {
    for (var id in _selectedIds) {
      provider.deleteNotes(id);
    }
    _exitMultiSelect();
  }

  void _showFolderSelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final notesProvider =
            Provider.of<NotesProvider>(context, listen: false);
        final folders = notesProvider.folders;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          height: 300,
          child: Column(
            children: [
              Text("Move to Folder",
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ListTile(
                      leading: const Icon(CupertinoIcons.folder),
                      title: Text(folder),
                      onTap: () {
                        notesProvider.batchMoveNotes(
                            _selectedIds.toList(), folder);
                        Navigator.pop(ctx);
                        _exitMultiSelect();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Moved to $folder")));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, NotesProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 25),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.trash,
                    color: Colors.redAccent, size: 24),
              ),
              const SizedBox(height: 15),
              Text(
                  "Delete ${_selectedIds.length} item${_selectedIds.length > 1 ? 's' : ''}?",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("This action cannot be undone.",
                  style: TextStyle(color: secondaryTextColor, fontSize: 14)),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      child: Text("Cancel",
                          style: TextStyle(
                              color: textColor, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(14),
                      child: const Text("Delete",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      onPressed: () {
                        _deleteSelected(provider); // calls helper
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
          border: Border.all(
              color: isSelected ? Colors.transparent : theme.dividerColor),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected
                    ? theme.scaffoldBackgroundColor
                    : textColor.withOpacity(0.7),
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }
}
