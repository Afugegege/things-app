import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../providers/events_provider.dart';
import '../../models/event_model.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/life_app_scaffold.dart';
import '../../widgets/dashboard_drawer.dart';

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
    setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day));
  }

  void _nextMonth() {
    setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day));
  }

  void _selectYearMonth() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: theme.brightness,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 20)
              ),
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

  // --- ADD / EDIT EVENT SHEET (Redesigned to match Wallet) ---
  void _showEventEditor({Event? existingEvent}) {
    final isEditing = existingEvent != null;
    final titleCtrl = TextEditingController(text: existingEvent?.title ?? "");
    final locCtrl = TextEditingController(text: existingEvent?.location ?? "");
    
    DateTime selectedDate = existingEvent?.date ?? _selectedDay ?? DateTime.now();
    TimeOfDay startTime = existingEvent != null ? TimeOfDay.fromDateTime(existingEvent.date) : TimeOfDay.now();
    TimeOfDay endTime = existingEvent != null ? TimeOfDay.fromDateTime(existingEvent.endTime) : TimeOfDay(hour: (TimeOfDay.now().hour + 1) % 24, minute: TimeOfDay.now().minute);
    
    bool isAllDay = existingEvent?.isAllDay ?? true;
    bool isDayCounter = existingEvent?.isDayCounter ?? false; 
    Color selectedColor = existingEvent?.color ?? Colors.blueAccent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          // [THEME] Match Wallet Styles
          final theme = Theme.of(context);
          final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
          final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
          final isDark = theme.brightness == Brightness.dark;
          final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

          Future<void> pickTime(bool isStart) async {
            final picked = await showTimePicker(
              context: context,
              initialTime: isStart ? startTime : endTime,
              builder: (context, child) => Theme(
                data: Theme.of(context),
                child: child!
              ),
            );
            if (picked != null) {
              setSheetState(() {
                if (isStart) startTime = picked; else endTime = picked;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40, top: 20, left: 25, right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Container(
                   alignment: Alignment.center,
                   child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))
                 ),
                 const SizedBox(height: 20),

                 // HEADER ROW
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEditing ? "Edit Event" : "New Event", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                    if (isEditing)
                      IconButton(
                        icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                        onPressed: () {
                             Provider.of<EventsProvider>(context, listen: false).removeEvent(existingEvent.id);
                             Navigator.pop(ctx);
                        },
                      )
                  ],
                ),
                const SizedBox(height: 25),
                
                // TITLE INPUT
                CupertinoTextField(
                  controller: titleCtrl,
                  placeholder: "Title",
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 15),

                // LOCATION INPUT
                CupertinoTextField(
                  controller: locCtrl,
                  placeholder: "Location",
                  prefix: Padding(padding: const EdgeInsets.only(left: 16), child: Icon(Icons.location_on_outlined, color: secondaryTextColor, size: 18)),
                  placeholderStyle: TextStyle(color: secondaryTextColor),
                  style: TextStyle(color: textColor),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 15),

                // ALL DAY TOGGLE (Styled as Input)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("All-day", style: TextStyle(color: textColor, fontSize: 16)),
                      Switch(
                        value: isAllDay, 
                        activeColor: textColor,
                        onChanged: (val) => setSheetState(() => isAllDay = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // TIME PICKERS
                if (!isAllDay) ...[
                  Row(
                    children: [
                      Expanded(child: _buildTimeInput(context, "Start", startTime.format(context), () => pickTime(true))),
                      const SizedBox(width: 15),
                      Expanded(child: _buildTimeInput(context, "End", endTime.format(context), () => pickTime(false))),
                    ],
                  ),
                  const SizedBox(height: 15),
                ],

                // DAY COUNTER TOGGLE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.sparkles, color: isDayCounter ? Colors.amber : secondaryTextColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Special Day Counter", style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                            Text("Show countdown on dashboard", style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch(
                        value: isDayCounter,
                        activeColor: Colors.amber,
                        onChanged: (val) => setSheetState(() => isDayCounter = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),
                Text("Color Label", style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 15),

                // COLORS
                SizedBox(
                  height: 45,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [Colors.blueAccent, Colors.redAccent, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink]
                      .map((c) => GestureDetector(
                        onTap: () => setSheetState(() => selectedColor = c),
                        child: Container(
                          margin: const EdgeInsets.only(right: 15),
                          width: 45, height: 45,
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.2), 
                            shape: BoxShape.circle,
                            border: Border.all(color: selectedColor == c ? c : Colors.transparent, width: 2),
                          ),
                          child: Center(child: Container(width: 20, height: 20, decoration: BoxDecoration(color: c, shape: BoxShape.circle))),
                        ),
                      )).toList(),
                  ),
                ),

                const SizedBox(height: 30),
                
                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: textColor,
                    borderRadius: BorderRadius.circular(15),
                    child: Text(isEditing ? "Update Event" : "Save Event", style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (titleCtrl.text.isNotEmpty) {
                        DateTime startDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                        DateTime endDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

                        if (!isAllDay) {
                            startDt = startDt.add(Duration(hours: startTime.hour, minutes: startTime.minute));
                            endDt = endDt.add(Duration(hours: endTime.hour, minutes: endTime.minute));
                            if (endDt.isBefore(startDt)) endDt = endDt.add(const Duration(days: 1));
                        }

                        final event = Event(
                          id: isEditing ? existingEvent.id : const Uuid().v4(),
                          title: titleCtrl.text,
                          location: locCtrl.text,
                          date: startDt,
                          endTime: endDt,
                          isAllDay: isAllDay,
                          isDayCounter: isDayCounter, 
                          color: selectedColor,
                        );

                        if (isEditing) {
                          Provider.of<EventsProvider>(context, listen: false).editEvent(event);
                        } else {
                          Provider.of<EventsProvider>(context, listen: false).addEvent(event);
                        }
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper for Time Inputs to match Wallet aesthetics
  Widget _buildTimeInput(BuildContext context, String label, String value, VoidCallback onTap) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
    final dayEvents = eventsProvider.getEventsForDay(_selectedDay ?? DateTime.now());

    // Matches WalletScreen LifeAppScaffold implementation
    return LifeAppScaffold(
      title: "CALENDAR",
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110), 
        child: FloatingActionButton(
          onPressed: () => _showEventEditor(),
          backgroundColor: isDark ? Colors.white : Colors.black, // High Contrast
          elevation: 0,
          shape: const CircleBorder(),
          child: Icon(CupertinoIcons.add, color: isDark ? Colors.black : Colors.white, size: 28),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: Icon(Icons.chevron_left, color: secondaryTextColor), onPressed: _previousMonth),
                      
                      GestureDetector(
                        onTap: _selectYearMonth,
                        child: Column(
                          children: [
                            Text("CURRENTLY VIEWING", style: TextStyle(color: secondaryTextColor, fontSize: 10, letterSpacing: 2)),
                            const SizedBox(height: 5),
                            Text(
                              DateFormat('MMMM y').format(_focusedDay).toUpperCase(), 
                              style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w300, letterSpacing: -1)
                            ),
                          ],
                        ),
                      ),

                      IconButton(icon: Icon(Icons.chevron_right, color: secondaryTextColor), onPressed: _nextMonth),
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
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                      },
                      onFormatChanged: (format) => setState(() => _calendarFormat = format),
                      onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                      eventLoader: (day) => eventsProvider.getEventsForDay(day),
                      
                      // [THEME] Dynamic Text Styles
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.bold),
                        weekendStyle: TextStyle(color: secondaryTextColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: TextStyle(color: textColor, fontSize: 16),
                        weekendTextStyle: TextStyle(color: secondaryTextColor, fontSize: 16),
                        outsideTextStyle: TextStyle(color: secondaryTextColor.withOpacity(0.3), fontSize: 16),
                        todayDecoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.3), shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(color: isDark ? Colors.white : Colors.black, shape: BoxShape.circle),
                        selectedTextStyle: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        markerDecoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
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
                      Text("SCHEDULE", style: TextStyle(color: secondaryTextColor, fontSize: 12, letterSpacing: 2)),
                      Expanded(child: Divider(color: theme.dividerColor, indent: 15, endIndent: 15)),
                      GestureDetector(
                        onTap: _jumpToToday,
                        child: Text("TODAY", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
                      Icon(CupertinoIcons.calendar_badge_plus, size: 40, color: secondaryTextColor.withOpacity(0.3)),
                      const SizedBox(height: 10),
                      Text("No events for this day", style: TextStyle(color: secondaryTextColor, fontSize: 14)),
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
                    final Color safeColor = event.color; 

                    return Dismissible(
                       key: ValueKey(event.id),
                       direction: DismissDirection.endToStart,
                       onDismissed: (_) => eventsProvider.removeEvent(event.id),
                       background: Container(
                         alignment: Alignment.centerRight, 
                         padding: const EdgeInsets.only(right: 20), 
                         child: const Icon(CupertinoIcons.trash, color: Colors.red)
                       ),
                       child: GestureDetector(
                        onTap: () => _showEventEditor(existingEvent: event),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: null,
                          ),
                          child: Row(
                            children: [
                              // Left Pill
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: safeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(DateFormat('d').format(event.date), style: TextStyle(color: safeColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(DateFormat('MMM').format(event.date).toUpperCase(), style: TextStyle(color: safeColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
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
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(event.title, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16)),
                                        if (event.isDayCounter) 
                                          const Icon(CupertinoIcons.sparkles, color: Colors.amber, size: 14)
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(CupertinoIcons.time, size: 12, color: secondaryTextColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          event.isAllDay 
                                            ? "All Day" 
                                            : "${DateFormat('h:mm a').format(event.date)} - ${DateFormat('h:mm a').format(event.endTime)}", 
                                          style: TextStyle(color: secondaryTextColor, fontSize: 12)
                                        ),
                                      ],
                                    ),
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