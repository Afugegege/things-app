import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../providers/notes_provider.dart';
import '../../providers/money_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/events_provider.dart';

import '../../models/note_model.dart';
import '../../models/task_model.dart';
import '../../models/event_model.dart';

import '../../widgets/glass_container.dart';
import '../notes/note_editor_screen.dart';
import '../apps/wallet_screen.dart';
import '../../widgets/smart_widgets/widget_factory.dart';
import '../../widgets/smart_widgets/expense_widget.dart';
import '../../widgets/event_ticker.dart';
import 'widget_studio_screen.dart';

class ThingsGridScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState> parentScaffoldKey;
  const ThingsGridScreen({super.key, required this.parentScaffoldKey});

  @override
  State<ThingsGridScreen> createState() => _ThingsGridScreenState();
}

class _ThingsGridScreenState extends State<ThingsGridScreen> {
  bool _isGrid = true;
  bool _isMultiSelect = false;
  final Set<String> _selectedIds = {}; 
  String _activeFilter = 'All';
  final TextEditingController _searchController = TextEditingController(); 
  bool _isSearching = false; 

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);
    final moneyProvider = Provider.of<MoneyProvider>(context);
    final tasksProvider = Provider.of<TasksProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final eventsProvider = Provider.of<EventsProvider>(context);

    final String currentFolder = notesProvider.selectedFolder;
    final bool isFolderView = currentFolder != 'All';
    final List<dynamic> allItems = [];
    final visibility = userProvider.appVisibility;

    // --- DATA GATHERING ---
    if (!isFolderView) {
      // 1. EVENTS [FIX: Added Filter Logic]
      if (_activeFilter == 'All' || _activeFilter == 'Events') {
         if (_activeFilter == 'Events') {
           // Show all upcoming events if filtered
           allItems.addAll(eventsProvider.upcomingEvents);
         } else {
           // Show just ticker if not filtered
           final upcoming = eventsProvider.upcomingEvents;
           if (upcoming.isNotEmpty) allItems.add(upcoming.first); 
         }
      }

      // 2. WIDGETS
      if (visibility['Wallet'] == true && (_activeFilter == 'All' || _activeFilter == 'Money')) {
        allItems.add('EXPENSE_WIDGET');
        allItems.addAll(moneyProvider.transactions.take(2));
      }
      if (visibility['Focus'] == true && (_activeFilter == 'All' || _activeFilter == 'Tasks')) {
        allItems.addAll(tasksProvider.tasks.where((t) => !t.isDone).take(4));
      }
    }
    
    // 3. NOTES
    if ((visibility['Brain'] == true || isFolderView) && (_activeFilter == 'All' || _activeFilter == 'Notes')) {
       final visibleNotes = notesProvider.notes.where((note) {
          if (isFolderView) return true;
          return userProvider.isFolderVisible(note.folder);
       }).toList();
       allItems.addAll(visibleNotes);
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      
      floatingActionButton: _isMultiSelect ? null : Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton(
          onPressed: () => _showQuickAddMenu(context), // [FIX] Now calls menu
          backgroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 10,
          child: const Icon(Icons.add, color: Colors.black, size: 32),
        ),
      ),
      
      body: CustomScrollView(
        slivers: [
          // HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_isMultiSelect)
                         IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _exitMultiSelect)
                      else
                         IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => widget.parentScaffoldKey.currentState?.openDrawer()),
                      
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isMultiSelect ? "${_selectedIds.length} Selected" : (isFolderView ? currentFolder : "Dashboard"), 
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)
                        ),
                      ),
                      
                      if (!_isMultiSelect) ...[
                        IconButton(
                          icon: Icon(_isSearching ? Icons.close : CupertinoIcons.search, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isSearching = !_isSearching;
                              if (!_isSearching) _searchController.clear();
                            });
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                          child: IconButton(
                            icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view, color: Colors.white),
                            onPressed: () => setState(() => _isGrid = !_isGrid),
                          ),
                        ),
                      ]
                    ],
                  ),
                  
                  if (_isSearching)
                    GlassContainer(
                      margin: const EdgeInsets.only(top: 15, bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      height: 50,
                      borderRadius: 15,
                      opacity: 0.15,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: "Search...",
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white38),
                        ),
                        onChanged: (v) => setState(() {}),
                      ),
                    ),

                  if (!_isMultiSelect && !_isSearching) ...[
                    const SizedBox(height: 15),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip("All"),
                          _filterChip("Notes"),
                          _filterChip("Tasks"),
                          _filterChip("Money"),
                          _filterChip("Events"), // [FIX] Added Events
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),

          if (allItems.isEmpty)
            SliverFillRemaining(child: Center(child: Text("Nothing here.", style: TextStyle(color: Colors.white.withOpacity(0.3)))))
          else if (_isGrid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childCount: allItems.length,
                itemBuilder: (context, index) => _buildSelectableItem(context, allItems[index]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    // [FIX] Removed fixed height to prevent overflow
                    child: _buildSelectableItem(context, allItems[index]),
                  ),
                  childCount: allItems.length,
                ),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
      
      bottomSheet: _isMultiSelect ? Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.delete, color: Colors.redAccent),
              onPressed: () {
                for (var id in _selectedIds) {
                  notesProvider.deleteNote(id);
                  tasksProvider.deleteTask(id);
                }
                _exitMultiSelect();
              },
            ),
            if (_hasOnlyNotes(notesProvider))
              IconButton(
                icon: const Icon(Icons.merge_type, color: Colors.white),
                onPressed: () {
                  notesProvider.mergeNotes(_selectedIds.toList());
                  _exitMultiSelect();
                },
              ),
             IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: _exitMultiSelect,
            ),
          ],
        ),
      ) : null,
    );
  }

  // --- [FIX] ADDED QUICK ADD MENU IMPLEMENTATION ---
  void _showQuickAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 250,
        child: Column(
          children: [
            const Text("Quick Add", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickAddOption(CupertinoIcons.doc_text, "Note", Colors.blueAccent, () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditorScreen()));
                }),
                _quickAddOption(CupertinoIcons.check_mark_circled, "Task", Colors.greenAccent, () {
                  Navigator.pop(ctx);
                  Provider.of<TasksProvider>(context, listen: false).addTask(
                    Task(id: const Uuid().v4(), title: "New Task", isDone: false, createdAt: DateTime.now())
                  );
                }),
                _quickAddOption(CupertinoIcons.money_dollar, "Expense", Colors.redAccent, () {
                  Navigator.pop(ctx);
                  Provider.of<MoneyProvider>(context, listen: false).addTransaction("New Expense", -10.0);
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _quickAddOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildSelectableItem(BuildContext context, dynamic item) {
    String? id;
    if (item is Note) id = item.id;
    if (item is Task) id = item.id;
    if (item is Event) id = item.id;
    
    if (id == null) return _buildGridItem(context, item);

    final isSelected = _selectedIds.contains(id);

    return GestureDetector(
      onTap: () {
        if (_isMultiSelect) _toggleSelection(id!);
        else if (item is Note) Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: item)));
      },
      onLongPress: () {
        setState(() { _isMultiSelect = true; _selectedIds.add(id!); });
      },
      child: Stack(
        children: [
          AbsorbPointer(absorbing: _isMultiSelect, child: _buildGridItem(context, item)),
          if (_isMultiSelect)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected ? Border.all(color: Colors.blueAccent, width: 3) : null,
                ),
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(8),
                child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: Colors.white),
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

  bool _hasOnlyNotes(NotesProvider notesProvider) {
    for (var id in _selectedIds) {
      if (!notesProvider.notes.any((n) => n.id == id)) return false;
    }
    return true;
  }

  Widget _filterChip(String label) {
    final bool isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, dynamic item) {
    if (item is Note) return WidgetFactory.build(context, item);
    if (item is Task) return _buildTaskCard(item);
    if (item is Event) return EventTicker(event: item); // Now works because we imported it properly
    if (item is Map) return _buildMoneyCard(Map<String, dynamic>.from(item));
    if (item == 'EXPENSE_WIDGET') return const ExpenseSummaryWidget();
    return const SizedBox();
  }
  
  Widget _buildTaskCard(Task task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent))),
              if (task.priority > 1) Icon(Icons.priority_high, size: 14, color: Colors.orangeAccent),
          ]),
          const SizedBox(height: 8),
          Text(task.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildMoneyCard(Map<String, dynamic> tx) {
    final bool isExp = (tx['amount'] as double) < 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(isExp ? Icons.trending_down : Icons.trending_up, color: isExp ? Colors.redAccent : Colors.greenAccent),
          const SizedBox(height: 5),
          Text(tx['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text("\$${tx['amount']}", style: TextStyle(color: isExp ? Colors.redAccent : Colors.greenAccent)),
      ]),
    );
  }
}