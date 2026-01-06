import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../providers/events_provider.dart';
import '../../models/event_model.dart';
import '../../widgets/glass_container.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // --- NAVIGATION: SPINNER PICKER ---
  void _selectYearMonth() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Jump to Date", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Done", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _focusedDay,
                    minimumDate: DateTime(2020),
                    maximumDate: DateTime(2030),
                    onDateTimeChanged: (DateTime newDate) {
                      setState(() {
                        _focusedDay = newDate;
                        _selectedDay = newDate;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _prevMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
    });
  }

  void _jumpToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }

  // --- ADD EVENT SHEET ---
  void _showAddEventSheet() {
    final titleCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
    Color selectedColor = Colors.blueAccent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(25, 25, 25, 40),
            height: 600, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("New Event", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: "Add Title", 
                    hintStyle: TextStyle(color: Colors.white24), 
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.edit, color: Colors.white54),
                  ),
                ),
                const Divider(color: Colors.white12),
                
                TextField(
                  controller: locCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: "Add Location", 
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.location_on_outlined, color: Colors.white54),
                  ),
                ),
                const Divider(color: Colors.white12),
                
                const SizedBox(height: 20),
                const Text("Color Code", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Colors.blueAccent, Colors.redAccent, Colors.green, Colors.orange, Colors.purple]
                      .map((c) => GestureDetector(
                            onTap: () => setSheetState(() => selectedColor = c),
                            child: Container(
                              width: 45, height: 45,
                              decoration: BoxDecoration(
                                color: c.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == c ? c : Colors.transparent, 
                                  width: 2
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                
                const Spacer(),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.isNotEmpty) {
                        final startDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
                        final endDt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime.hour, endTime.minute);
                        
                        Provider.of<EventsProvider>(context, listen: false).addEvent(Event(
                          id: const Uuid().v4(),
                          title: titleCtrl.text,
                          location: locCtrl.text,
                          date: startDt,
                          endTime: endDt,
                          color: selectedColor,
                        ));
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, 
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))
                    ),
                    child: const Text("Save Event", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsProvider = Provider.of<EventsProvider>(context);
    final dayEvents = eventsProvider.getEventsForDay(_selectedDay ?? DateTime.now());

    return Scaffold(
      backgroundColor: Colors.black,
      
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110), 
        child: FloatingActionButton(
          onPressed: _showAddEventSheet,
          backgroundColor: Colors.white,
          elevation: 10,
          child: const Icon(Icons.add, color: Colors.black, size: 28),
        ),
      ),
      
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20), // Top spacing

            // --- SPACIOUS CALENDAR CARD ---
            GlassContainer(
              margin: const EdgeInsets.symmetric(horizontal: 20), // Detached from sides
              padding: const EdgeInsets.fromLTRB(15, 20, 15, 25), // Inner breathing room
              borderRadius: 30, // Softer corners
              opacity: 0.08, // Subtle glass effect
              child: Column(
                children: [
                  // CUSTOM HEADER INSIDE CARD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _selectYearMonth,
                          child: Row(
                            children: [
                              Text(
                                DateFormat('MMMM y').format(_focusedDay),
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.white54),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white70), onPressed: _prevMonth),
                            IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white70), onPressed: _nextMonth),
                          ],
                        )
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 10),

                  // THE CALENDAR GRID
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    rowHeight: 52, // Tall rows for spaciousness
                    
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) => setState(() => _calendarFormat = format),
                    onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                    eventLoader: (day) => eventsProvider.getEventsForDay(day),
                    
                    headerVisible: false, // We built our own custom header above
                    
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                      weekendStyle: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    
                    calendarStyle: const CalendarStyle(
                      defaultTextStyle: TextStyle(color: Colors.white, fontSize: 16),
                      weekendTextStyle: TextStyle(color: Colors.white70, fontSize: 16),
                      outsideTextStyle: TextStyle(color: Colors.white12, fontSize: 16),
                      
                      // Circle Styles
                      todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      selectedTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                      
                      // Marker Dots
                      markerDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      markersMaxCount: 1, // Cleaner look with just one dot
                      markerSize: 6,
                      markerMargin: EdgeInsets.only(top: 6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- SCHEDULE HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("SCHEDULE", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  
                  GestureDetector(
                    onTap: _jumpToToday,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text("Today", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),

            // --- EVENTS LIST ---
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: dayEvents.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available, size: 40, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 10),
                          Text("Nothing planned for today", style: const TextStyle(color: Colors.white38)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 150),
                      itemCount: dayEvents.length,
                      itemBuilder: (context, index) {
                        final event = dayEvents[index];
                        final Color safeColor = event.color; 

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: safeColor.withOpacity(0.1), // Very subtle background
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: safeColor.withOpacity(0.3)), // Colored border instead of solid fill
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4, height: 40,
                                decoration: BoxDecoration(color: safeColor, borderRadius: BorderRadius.circular(2)),
                              ),
                              const SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('h:mm a').format(event.date), 
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.title, 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}