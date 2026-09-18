import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../providers/events_provider.dart';
import '../../providers/notes_provider.dart';
import '../../models/event_model.dart';
import '../../models/note_model.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../widgets/dashboard_drawer.dart';
import '../../widgets/common/minimalist_toast.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // --- NAVIGATION LOGIC ---
  void _previousMonth() {
    setState(() => _focusedDay =
        DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day));
  }

  void _nextMonth() {
    setState(() => _focusedDay =
        DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day));
  }

  void _selectYearMonth() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: theme.brightness,
              textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                      color: theme.textTheme.bodyLarge?.color, fontSize: 20)),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _focusedDay,
              onDateTimeChanged: (val) => setState(() => _focusedDay = val),
            ),
          ),
        );
      },
    );
  }

  void _jumpToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }

  // --- ADD / EDIT EVENT SHEET ---
  void _showEventEditor({Event? existingEvent}) {
    final isEditing = existingEvent != null;
    final titleCtrl = TextEditingController(text: existingEvent?.title ?? "");
    final locCtrl = TextEditingController(text: existingEvent?.location ?? "");
    final descCtrl =
        TextEditingController(text: existingEvent?.description ?? "");

    DateTime selectedDate =
        existingEvent?.date ?? _selectedDay ?? DateTime.now();
    TimeOfDay startTime = existingEvent != null
        ? TimeOfDay.fromDateTime(existingEvent.date)
        : TimeOfDay.now();
    TimeOfDay endTime = existingEvent != null
        ? TimeOfDay.fromDateTime(existingEvent.endTime)
        : TimeOfDay(
            hour: (TimeOfDay.now().hour + 1) % 24,
            minute: TimeOfDay.now().minute);

    bool isAllDay = existingEvent?.isAllDay ?? true;
    bool isDayCounter = existingEvent?.isDayCounter ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color selectedColor = existingEvent?.color ?? (isDark ? Colors.white : Colors.black);
    EventType selectedType = existingEvent?.type ?? EventType.event;
    String? selectedNoteId = existingEvent?.linkedNoteId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor =
              theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05);

          Future<void> pickTime(bool isStart) async {
            final picked = await showTimePicker(
              context: context,
              initialTime: isStart ? startTime : endTime,
              builder: (context, child) =>
                  Theme(data: Theme.of(context), child: child!),
            );
            if (picked != null) {
              setSheetState(() {
                if (isStart) {
                  startTime = picked;
                } else {
                  endTime = picked;
                }
              });
            }
          }

          // Generate a 2-week date strip centred on selectedDate
          final today = DateTime.now();
          final stripStart = selectedDate.subtract(const Duration(days: 7));

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 14,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DRAG HANDLE
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? "Edit Event" : "New Event",
                        style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      if (isEditing)
                        IconButton(
                          icon: const Icon(CupertinoIcons.trash,
                              color: Colors.redAccent, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Provider.of<EventsProvider>(context, listen: false)
                                .removeEvent(existingEvent.id);
                            Navigator.pop(ctx);
                            MinimalistToast.showUndo(
                              context,
                              title: existingEvent.title.isNotEmpty ? existingEvent.title : "Event",
                              onUndo: () => Provider.of<EventsProvider>(context, listen: false)
                                  .restoreEvent(existingEvent),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── INLINE DATE STRIP ──
                  SizedBox(
                    height: 68,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 14,
                      itemBuilder: (_, i) {
                        final d = stripStart.add(Duration(days: i));
                        final isSelected = d.year == selectedDate.year &&
                            d.month == selectedDate.month &&
                            d.day == selectedDate.day;
                        final isToday = d.year == today.year &&
                            d.month == today.month &&
                            d.day == today.day;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedDate = d),
                          child: Container(
                            width: 44,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? textColor : inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: isToday && !isSelected
                                  ? Border.all(
                                      color: textColor.withValues(alpha: 0.4),
                                      width: 1.5)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  [
                                    'S',
                                    'M',
                                    'T',
                                    'W',
                                    'T',
                                    'F',
                                    'S'
                                  ][d.weekday % 7],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? theme.scaffoldBackgroundColor
                                            .withValues(alpha: 0.7)
                                        : secondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? theme.scaffoldBackgroundColor
                                        : textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // "Jump to another date" small tappable label
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null)
                          setSheetState(() => selectedDate = picked);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          '${DateFormat('MMM d, yyyy').format(selectedDate)}  ›',
                          style: TextStyle(
                              color: secondaryTextColor, fontSize: 12),
                        ),
                      ),
                    ),
                  ),

                  // TITLE
                  CupertinoTextField(
                    controller: titleCtrl,
                    placeholder: "Title",
                    placeholderStyle: TextStyle(color: secondaryTextColor),
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                  ),
                  const SizedBox(height: 8),

                  // LOCATION + DESCRIPTION side-by-side compact row
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: locCtrl,
                          placeholder: "Location",
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Icon(CupertinoIcons.location,
                                color: secondaryTextColor, size: 15),
                          ),
                          placeholderStyle: TextStyle(
                              color: secondaryTextColor, fontSize: 13),
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  CupertinoTextField(
                    controller: descCtrl,
                    placeholder: "Notes / Description",
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(CupertinoIcons.text_alignleft,
                          color: secondaryTextColor, size: 15),
                    ),
                    placeholderStyle:
                        TextStyle(color: secondaryTextColor, fontSize: 13),
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 11),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),

                  // TYPE CHIPS + ALL DAY in one row
                  Row(
                    children: [
                      // Type chips
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              EventType.event,
                              EventType.task,
                              EventType.birthday
                            ].map((type) {
                              final isSel = selectedType == type;
                              return GestureDetector(
                                onTap: () =>
                                    setSheetState(() => selectedType = type),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSel ? textColor : inputBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isSel
                                            ? Colors.transparent
                                            : theme.dividerColor),
                                  ),
                                  child: Text(
                                    type
                                        .toString()
                                        .split('.')
                                        .last
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: isSel
                                          ? theme.scaffoldBackgroundColor
                                          : textColor,
                                      fontSize: 11,
                                      fontWeight: isSel
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      // All-day compact toggle
                      Row(
                        children: [
                          Text("All-day",
                              style: TextStyle(
                                  color: secondaryTextColor, fontSize: 12)),
                          const SizedBox(width: 4),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: isAllDay,
                              activeThumbColor: textColor,
                              onChanged: (val) =>
                                  setSheetState(() => isAllDay = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // TIME PICKERS (only if not all-day)
                  if (!isAllDay) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTimeInput(
                                context,
                                "Start",
                                startTime.format(context),
                                () => pickTime(true))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildTimeInput(
                                context,
                                "End",
                                endTime.format(context),
                                () => pickTime(false))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),

                  // DAY COUNTER + COLOR in one row
                  Row(
                    children: [
                      // Day counter compact
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setSheetState(() => isDayCounter = !isDayCounter),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDayCounter
                                  ? textColor.withValues(alpha: 0.12)
                                  : inputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDayCounter
                                    ? textColor.withValues(alpha: 0.4)
                                    : theme.dividerColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.sparkles,
                                    color: isDayCounter
                                        ? textColor
                                        : secondaryTextColor,
                                    size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Day Counter",
                                    style: TextStyle(
                                      color: isDayCounter
                                          ? textColor
                                          : secondaryTextColor,
                                      fontSize: 12,
                                      fontWeight: isDayCounter
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Color swatch strip compact
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Colors.red,
                              Colors.orange,
                              Colors.yellow,
                              Colors.green,
                              Colors.blue,
                              Colors.indigo,
                              Colors.purple,
                              Colors.pink,
                              Colors.black,
                              Colors.white,
                            ]
                                .map((c) => GestureDetector(
                                      onTap: () => setSheetState(
                                          () => selectedColor = c),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selectedColor == c
                                                ? (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                : theme.dividerColor,
                                            width: selectedColor == c ? 2.5 : 1,
                                          ),
                                        ),
                                        child: selectedColor == c
                                            ? Icon(Icons.check,
                                                color: c == Colors.white
                                                    ? Colors.black
                                                    : Colors.white,
                                                size: 14)
                                            : null,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // RELATED NOTE SECTION
                  Text("Note",
                      style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Consumer<NotesProvider>(
                    builder: (context, notesProvider, _) {
                      final notes = notesProvider.notes;
                      final linkedNote = selectedNoteId != null
                          ? notes
                              .where((n) => n.id == selectedNoteId)
                              .firstOrNull
                          : null;

                      return Column(
                        children: [
                          if (linkedNote != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.doc_text_fill,
                                      color: textColor, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(linkedNote.title,
                                            style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        Text(
                                          linkedNote.plainTextContent.isNotEmpty
                                              ? linkedNote.plainTextContent
                                              : "Empty",
                                          style: TextStyle(
                                              color: secondaryTextColor,
                                              fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setSheetState(
                                        () => selectedNoteId = null),
                                    child: Icon(
                                        CupertinoIcons.xmark_circle_fill,
                                        color: secondaryTextColor,
                                        size: 18),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked =
                                        await showModalBottomSheet<String?>(
                                      context: context,
                                      backgroundColor: theme.cardColor,
                                      shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(20))),
                                      builder: (ctx) => Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(height: 12),
                                          Container(
                                              width: 36,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                  color: theme.dividerColor,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          2))),
                                          const SizedBox(height: 16),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text("Select a Note",
                                                    style: TextStyle(
                                                        color: textColor,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                if (selectedNoteId != null)
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, 'NONE'),
                                                    child: Text("Remove",
                                                        style: TextStyle(
                                                            color: Colors
                                                                .redAccent
                                                                .withValues(
                                                                    alpha: 0.8),
                                                            fontSize: 13)),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Flexible(
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: notes.length,
                                              itemBuilder: (ctx2, i) {
                                                final note = notes[i];
                                                final isSel =
                                                    note.id == selectedNoteId;
                                                return ListTile(
                                                  dense: true,
                                                  leading: Icon(
                                                      CupertinoIcons.doc_text,
                                                      color: isSel
                                                          ? textColor
                                                          : secondaryTextColor,
                                                      size: 18),
                                                  title: Text(note.title,
                                                      style: TextStyle(
                                                          color: textColor,
                                                          fontWeight: isSel
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                          fontSize: 14)),
                                                  subtitle: Text(
                                                      note.plainTextContent
                                                              .isNotEmpty
                                                          ? note
                                                              .plainTextContent
                                                          : "Empty",
                                                      style: TextStyle(
                                                          color:
                                                              secondaryTextColor,
                                                          fontSize: 11),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                  trailing: isSel
                                                      ? Icon(
                                                          CupertinoIcons
                                                              .checkmark_alt,
                                                          color: textColor,
                                                          size: 16)
                                                      : null,
                                                  onTap: () => Navigator.pop(
                                                      ctx, note.id),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                                    );
                                    if (picked != null)
                                      setSheetState(() => selectedNoteId =
                                          picked == 'NONE' ? null : picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                        color: inputBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: theme.dividerColor)),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(CupertinoIcons.doc_text_search,
                                            color: secondaryTextColor,
                                            size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                            linkedNote != null
                                                ? "Change"
                                                : "Pick Note",
                                            style: TextStyle(
                                                color: secondaryTextColor,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final tc = TextEditingController();
                                    final cc = TextEditingController();
                                    final created = await showDialog<Note?>(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        backgroundColor: theme.cardColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        title: Text("New Note",
                                            style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold)),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: tc,
                                              style:
                                                  TextStyle(color: textColor),
                                              decoration: InputDecoration(
                                                hintText: "Title",
                                                hintStyle: TextStyle(
                                                    color: secondaryTextColor),
                                                filled: true,
                                                fillColor: inputBg,
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    borderSide:
                                                        BorderSide.none),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: cc,
                                              style:
                                                  TextStyle(color: textColor),
                                              maxLines: 4,
                                              decoration: InputDecoration(
                                                hintText: "Content...",
                                                hintStyle: TextStyle(
                                                    color: secondaryTextColor),
                                                filled: true,
                                                fillColor: inputBg,
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    borderSide:
                                                        BorderSide.none),
                                                contentPadding:
                                                    const EdgeInsets.all(12),
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dCtx),
                                              child: Text("Cancel",
                                                  style: TextStyle(
                                                      color:
                                                          secondaryTextColor))),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              foregroundColor: isDark
                                                  ? Colors.black
                                                  : Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                            ),
                                            onPressed: () {
                                              final n = Note(
                                                id: const Uuid().v4(),
                                                title: tc.text.trim().isEmpty
                                                    ? "Untitled"
                                                    : tc.text.trim(),
                                                content: cc.text.trim(),
                                                createdAt: DateTime.now(),
                                                updatedAt: DateTime.now(),
                                                folder: 'General',
                                              );
                                              Navigator.pop(dCtx, n);
                                            },
                                            child: const Text("Save"),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (created != null) {
                                      Provider.of<NotesProvider>(context,
                                              listen: false)
                                          .addNote(created);
                                      setSheetState(
                                          () => selectedNoteId = created.id);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.07)
                                          : Colors.black
                                              .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(10),
                                      border:
                                          Border.all(color: theme.dividerColor),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(CupertinoIcons.plus,
                                            color: textColor, size: 14),
                                        const SizedBox(width: 6),
                                        Text("New Note",
                                            style: TextStyle(
                                                color: textColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: textColor,
                      borderRadius: BorderRadius.circular(13),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        isEditing ? "Update Event" : "Save Event",
                        style: TextStyle(
                            color: theme.scaffoldBackgroundColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      onPressed: () {
                        if (titleCtrl.text.isNotEmpty) {
                          DateTime startDt = DateTime(selectedDate.year,
                              selectedDate.month, selectedDate.day);
                          DateTime endDt = DateTime(selectedDate.year,
                              selectedDate.month, selectedDate.day);
                          if (!isAllDay) {
                            startDt = startDt.add(Duration(
                                hours: startTime.hour,
                                minutes: startTime.minute));
                            endDt = endDt.add(Duration(
                                hours: endTime.hour, minutes: endTime.minute));
                            if (endDt.isBefore(startDt))
                              endDt = endDt.add(const Duration(days: 1));
                          }
                          final event = Event(
                            id: isEditing
                                ? existingEvent.id
                                : const Uuid().v4(),
                            title: titleCtrl.text,
                            description: descCtrl.text,
                            location: locCtrl.text,
                            date: startDt,
                            endTime: endDt,
                            isAllDay: isAllDay,
                            isDayCounter: isDayCounter,
                            type: selectedType,
                            color: selectedColor,
                            linkedNoteId: selectedNoteId,
                          );
                          if (isEditing) {
                            Provider.of<EventsProvider>(context, listen: false)
                                .editEvent(event);
                          } else {
                            Provider.of<EventsProvider>(context, listen: false)
                                .addEvent(event);
                          }
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper for Time Inputs to match Wallet aesthetics
  Widget _buildTimeInput(
      BuildContext context, String label, String value, VoidCallback onTap) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: inputBg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [THEME] Setup
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final eventsProvider = Provider.of<EventsProvider>(context);
    final dayEvents =
        eventsProvider.getEventsForDay(_selectedDay ?? DateTime.now());

    // Matches WalletScreen LifeAppScaffold implementation
    return LifeAppScaffold(
      title: "CALENDAR",
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton(
          onPressed: () => _showEventEditor(),
          backgroundColor:
              isDark ? Colors.white : Colors.black, // High Contrast
          elevation: 0,
          shape: const CircleBorder(),
          child: Icon(CupertinoIcons.add,
              color: isDark ? Colors.black : Colors.white, size: 28),
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // MONTH NAVIGATOR (Styled like Wallet Balance Section)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          icon: Icon(Icons.chevron_left,
                              color: secondaryTextColor),
                          onPressed: _previousMonth),
                      GestureDetector(
                        onTap: _selectYearMonth,
                        child: Column(
                          children: [
                            Text("CURRENTLY VIEWING",
                                style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 10,
                                    letterSpacing: 2)),
                            const SizedBox(height: 5),
                            Text(
                                DateFormat('MMMM y')
                                    .format(_focusedDay)
                                    .toUpperCase(),
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: -1)),
                          ],
                        ),
                      ),
                      IconButton(
                          icon: Icon(Icons.chevron_right,
                              color: secondaryTextColor),
                          onPressed: _nextMonth),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // CALENDAR GRID
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: GlassContainer(
                    opacity: isDark ? 0.2 : 0.05,
                    padding: const EdgeInsets.fromLTRB(10, 5, 10, 20),
                    borderRadius: 25,
                    hasBorder: false,
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      rowHeight: 50,
                      daysOfWeekHeight: 30,
                      headerVisible: false,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onFormatChanged: (format) =>
                          setState(() => _calendarFormat = format),
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                      },
                      eventLoader: (day) => eventsProvider.getEventsForDay(day),

                      // [THEME] Dynamic Text Styles
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        weekendStyle: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle:
                            TextStyle(color: textColor, fontSize: 16),
                        weekendTextStyle:
                            TextStyle(color: secondaryTextColor, fontSize: 16),
                        outsideTextStyle: TextStyle(
                            color: secondaryTextColor.withOpacity(0.3),
                            fontSize: 16),
                        todayDecoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.1),
                            shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            shape: BoxShape.circle),
                        selectedTextStyle: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                        markerDecoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            shape: BoxShape.circle),
                        markersMaxCount: 1,
                        markerSize: 6,
                        markerMargin: const EdgeInsets.only(top: 8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // EVENTS LIST HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      Text("SCHEDULE",
                          style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                              letterSpacing: 2)),
                      Expanded(
                          child: Divider(
                              color: theme.dividerColor,
                              indent: 15,
                              endIndent: 15)),
                      GestureDetector(
                        onTap: _jumpToToday,
                        child: Text("TODAY",
                            style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),
              ],
            ),
          ),

          // EVENTS LIST or EMPTY STATE
          if (dayEvents.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(top: 50, bottom: 200),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.calendar_badge_plus,
                          size: 40, color: secondaryTextColor.withOpacity(0.3)),
                      const SizedBox(height: 10),
                      Text("No events for this day",
                          style: TextStyle(
                              color: secondaryTextColor, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 200),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final event = dayEvents[index];
                    Color safeColor = event.color;
                    if (isDark && safeColor == Colors.black)
                      safeColor = Colors.white;
                    if (!isDark && safeColor == Colors.white)
                      safeColor = Colors.black;

                    return Dismissible(
                      key: ValueKey(event.id),
                      direction: DismissDirection.endToStart,
                      dismissThresholds: const {
                        DismissDirection.endToStart: 0.65,
                      },
                      onDismissed: (_) {
                        eventsProvider.removeEvent(event.id);
                        MinimalistToast.showUndo(
                          context,
                          title: event.title.isNotEmpty ? event.title : "Event",
                          onUndo: () => eventsProvider.restoreEvent(event),
                        );
                      },
                      background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(CupertinoIcons.trash,
                              color: Colors.red)),
                      child: GestureDetector(
                        onTap: () => _showEventEditor(existingEvent: event),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: null,
                          ),
                          child: Row(
                            children: [
                              // Left Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: safeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(DateFormat('d').format(event.date),
                                        style: TextStyle(
                                            color: safeColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Text(
                                        DateFormat('MMM')
                                            .format(event.date)
                                            .toUpperCase(),
                                        style: TextStyle(
                                            color: safeColor.withOpacity(0.8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(children: [
                                            Icon(
                                                event.type == EventType.birthday
                                                    ? CupertinoIcons.gift
                                                    : event.type ==
                                                            EventType.task
                                                        ? CupertinoIcons
                                                            .checkmark_circle
                                                        : CupertinoIcons
                                                            .calendar,
                                                size: 14,
                                                color: safeColor),
                                            const SizedBox(width: 6),
                                            Expanded(
                                                child: Text(event.title,
                                                    style: TextStyle(
                                                        color: textColor,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 16),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                          ]),
                                        ),
                                        if (event.isDayCounter)
                                          Icon(CupertinoIcons.sparkles,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              size: 14)
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(CupertinoIcons.time,
                                            size: 12,
                                            color: secondaryTextColor),
                                        const SizedBox(width: 4),
                                        Text(
                                            event.isAllDay
                                                ? "All Day"
                                                : "${DateFormat('h:mm a').format(event.date)} - ${DateFormat('h:mm a').format(event.endTime)}",
                                            style: TextStyle(
                                                color: secondaryTextColor,
                                                fontSize: 12)),
                                      ],
                                    ),
                                    if (event.description.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(event.description,
                                          style: TextStyle(
                                              color: secondaryTextColor,
                                              fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: dayEvents.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
