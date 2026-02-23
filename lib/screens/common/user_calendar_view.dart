import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:intl/intl.dart';
import 'package:e_learning_app/core/calendar_utils.dart';

class StudentCalendarView extends StatefulWidget {
  final DateTime? initialDate;
  const StudentCalendarView({super.key, this.initialDate});

  @override
  State<StudentCalendarView> createState() => _StudentCalendarViewState();
}

class _StudentCalendarViewState extends State<StudentCalendarView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _firestoreEvents = {};
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate ?? DateTime.now();
    _selectedDay = _focusedDay;
    _checkRole();
    _fetchEvents();
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (mounted) {
          final role = doc.data()?['role']?.toString().toLowerCase();
          setState(() {
            _isAdmin = role == 'admin';
          });
        }
      } catch (e) {
        debugPrint("Error checking role: $e");
      }
    }
  }

  void _fetchEvents() {
    FirebaseFirestore.instance
        .collection('academic_events')
        .snapshots()
        .listen((snapshot) {
      final Map<DateTime, List<dynamic>> newEvents = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        Timestamp start =
            (data['startDate'] ?? data['date'] ?? Timestamp.now()) as Timestamp;
        Timestamp end =
            (data['endDate'] ?? data['date'] ?? Timestamp.now()) as Timestamp;

        DateTime startDate = start.toDate();
        DateTime endDate = end.toDate();

        // Normalize to date only
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = DateTime(endDate.year, endDate.month, endDate.day);

        // Populate every day in the range
        for (DateTime date = startDate;
            date.isBefore(endDate.add(const Duration(days: 1)));
            date = date.add(const Duration(days: 1))) {
          final dateKey = DateTime(date.year, date.month, date.day);
          if (newEvents[dateKey] == null) newEvents[dateKey] = [];
          newEvents[dateKey]!.add(data);
        }
      }
      if (mounted) {
        setState(() {
          _firestoreEvents = newEvents;
        });
      }
    });
  }

  List<dynamic> _getAllEventsForDay(DateTime day) {
    List events =
        _firestoreEvents[DateTime(day.year, day.month, day.day)] ?? [];
    final localEvents = IndonesiaHolidays.getEventsForDay(day);
    return [...events, ...localEvents];
  }

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String type = 'event';
    DateTime? rangeStart = _selectedDay;
    DateTime? rangeEnd = _selectedDay;
    DateTime focused = _selectedDay!;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Tambah Agenda/Libur",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Judul"),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: "Keterangan"),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Pilih Rentang Waktu:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: focused,
                    calendarFormat: CalendarFormat.month,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    rangeStartDay: rangeStart,
                    rangeEndDay: rangeEnd,
                    rangeSelectionMode: RangeSelectionMode.enforced,
                    onRangeSelected: (start, end, focusedDay) {
                      setDialogState(() {
                        rangeStart = start;
                        rangeEnd = end;
                        focused = focusedDay;
                      });
                    },
                    calendarStyle: const CalendarStyle(
                      isTodayHighlighted: false,
                      rangeHighlightColor: AppTheme.primaryColor,
                      rangeStartDecoration: BoxDecoration(
                          color: AppTheme.primaryColor, shape: BoxShape.circle),
                      rangeEndDecoration: BoxDecoration(
                          color: AppTheme.primaryColor, shape: BoxShape.circle),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        if (IndonesiaHolidays.isHoliday(day)) {
                          return Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: "Tipe"),
                  items: const [
                    DropdownMenuItem(
                        value: 'event', child: Text("Kegiatan (Biru)")),
                    DropdownMenuItem(
                        value: 'holiday', child: Text("Libur (Merah)")),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => type = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Batal")),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty && rangeStart != null) {
                  await FirebaseFirestore.instance
                      .collection('academic_events')
                      .add({
                    'title': titleController.text,
                    'description': descController.text,
                    'type': type,
                    'startDate': Timestamp.fromDate(rangeStart!),
                    'endDate': Timestamp.fromDate(rangeEnd ?? rangeStart!),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white),
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEvent(String eventId) async {
    await FirebaseFirestore.instance
        .collection('academic_events')
        .doc(eventId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Theme.of(context).cardColor,
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    eventLoader: _getAllEventsForDay,
                    calendarStyle: CalendarStyle(
                      selectedDecoration: const BoxDecoration(
                          color: AppTheme.primaryColor, shape: BoxShape.circle),
                      todayDecoration: const BoxDecoration(
                          color: Colors.blueGrey, shape: BoxShape.circle),
                      markerDecoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      weekendTextStyle: const TextStyle(color: Colors.red),
                      defaultTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      outsideTextStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3)),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final events = _getAllEventsForDay(day);
                        final isHoliday =
                            events.any((e) => e['type'] == 'holiday') ||
                                IndonesiaHolidays.isHoliday(day);

                        if (isHoliday) {
                          return Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return null;
                      },
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return const SizedBox();
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: events.map((event) {
                            final e = event as Map<String, dynamic>;
                            return Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 0.5),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: e['type'] == 'holiday'
                                    ? Colors.red
                                    : Colors.blue,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        "Kegiatan pada ${DateFormat('d MMMM yyyy').format(_selectedDay ?? DateTime.now())}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._getAllEventsForDay(_selectedDay ?? DateTime.now())
                          .map((event) {
                        String dateInfo = "";
                        if (event['startDate'] != null &&
                            event['endDate'] != null) {
                              DateTime start = DateTime.now(); // Initialize with a default value
                              DateTime end = DateTime.now(); // Initialize with a default value
                              final startTs = event['startDate'] as Timestamp?;
                              final endTs = event['endDate'] as Timestamp?;
                              if (startTs != null) start = startTs.toDate();
                              if (endTs != null) end = endTs.toDate();
                          if (!isSameDay(start, end)) {
                            dateInfo =
                                "${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM').format(end)}";
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              event['type'] == 'holiday'
                                  ? Icons.calendar_today_rounded
                                  : Icons.event_rounded,
                              color: event['type'] == 'holiday'
                                  ? Colors.red
                                  : Colors.blue,
                            ),
                            title: Text(event['title'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dateInfo.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(dateInfo,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppTheme.primaryColor)),
                                  ),
                                Text(event['description'] ?? ""),
                              ],
                            ),
                            trailing: _isAdmin && event['id'] != null
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () => _deleteEvent(event['id']),
                                  )
                                : null,
                          ),
                        );
                      }),
                      if (_getAllEventsForDay(_selectedDay ?? DateTime.now())
                          .isEmpty)
                        const Center(
                            child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("Tidak ada kegiatan"),
                        )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: _showAddEventDialog,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
