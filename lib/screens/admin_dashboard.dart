import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:e_learning_app/services/auth_service.dart';
import 'package:e_learning_app/core/calendar_utils.dart';
import 'package:e_learning_app/widgets/user_avatar.dart';
import 'package:e_learning_app/screens/admin_user_management.dart';
import 'package:e_learning_app/screens/admin_course_management.dart';
import 'package:e_learning_app/screens/profile_settings_screen.dart';
import 'package:e_learning_app/screens/user_calendar_view.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Timer _timer;
  late DateTime _currentTime;
  late DateTime _calendarFocusedDay;

  int _currentIndex = 0;

  final List<String> _titles = [
    "E-Learning (Admin)",
    "Kelola Pengguna",
    "Manajemen Prodi",
    "Profil & Pengaturan",
    "Kalender Akademik",
  ];

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _calendarFocusedDay = _currentTime;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return _buildHomeView();
      case 1:
        return AdminUserManagementScreen(isView: true);
      case 2:
        return AdminCourseManagementScreen(isView: true);
      case 3:
        return ProfileSettingsView();
      case 4:
        return StudentCalendarView();
      default:
        return const Center(child: Text("Halaman tidak ditemukan"));
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _showDayDetailOverlay(DateTime day, List events) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM').format(day),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text("Tidak ada agenda atau libur di hari ini."),
                ),
              )
            else
              ...events.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: e['type'] == 'holiday'
                            ? Colors.red.withValues(alpha: 0.1)
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        e['type'] == 'holiday'
                            ? Icons.calendar_today_rounded
                            : Icons.event_rounded,
                        color: e['type'] == 'holiday'
                            ? Colors.red
                            : AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      e['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(e['description'] ?? "Tidak ada keterangan"),
                    trailing: e['type'] == 'holiday'
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "LIBUR",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          )
                        : null,
                  )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.themeNotifier,
            builder: (context, currentMode, _) {
              return IconButton(
                onPressed: () {
                  AppTheme.themeNotifier.value = currentMode == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light;
                },
                icon: Icon(currentMode == ThemeMode.light
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_rounded),
              );
            },
          ),
          GestureDetector(
            onTap: () => _onItemTapped(3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: UserAvatar(
                radius: 18,
                onTap: () => _onItemTapped(3),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                  top: 50, left: 16, right: 16, bottom: 16),
              decoration: const BoxDecoration(color: AppTheme.primaryColor),
              child: Row(
                children: [
                  const UserAvatar(radius: 30),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${FirebaseAuth.instance.currentUser?.displayName ?? 'Admin User'} (Admin)",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          FirebaseAuth.instance.currentUser?.email ??
                              "admin@elearning.com",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_rounded),
              title: const Text("Dashboard"),
              selected: _currentIndex == 0,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded),
              title: const Text("Pengguna"),
              selected: _currentIndex == 1,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school_rounded),
              title: const Text("Manajemen Prodi"),
              selected: _currentIndex == 2,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text("Profil & Pengaturan"),
              selected: _currentIndex == 3,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text("Kalender Akademik"),
              selected: _currentIndex == 4,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(4);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text("Keluar", style: TextStyle(color: Colors.red)),
              onTap: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
          ],
        ),
      ),
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded), label: 'Pengguna'),
          BottomNavigationBarItem(
              icon: Icon(Icons.school_rounded), label: 'Prodi'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded), label: 'Profil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded), label: 'Kalender'),
        ],
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildHomeView() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _currentTime = DateTime.now();
        });
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ringkasan Statistik",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    builder: (context, snapshot) {
                      String totalUsers = "...";
                      if (snapshot.hasData) {
                        totalUsers = snapshot.data!.docs.length.toString();
                      }
                      return _buildStatCard(
                        context,
                        "Total Pengguna",
                        totalUsers,
                        Icons.people_outline_rounded,
                        Colors.blue,
                        onTap: () => _onItemTapped(1),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('majors')
                        .snapshots(),
                    builder: (context, snapshot) {
                      String totalMajors = "...";
                      if (snapshot.hasData) {
                        totalMajors = snapshot.data!.docs.length.toString();
                      }
                      return _buildStatCard(
                        context,
                        "Manajemen Prodi",
                        totalMajors,
                        Icons.school_outlined,
                        Colors.orange,
                        onTap: () => _onItemTapped(2),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildClockAndCalendar(),
          ],
        ),
      ),
    );
  }

  Widget _buildClockAndCalendar() {
    String formattedTime = DateFormat('HH:mm:ss').format(_currentTime);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                "Jam Digital",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 8),
              Text(
                formattedTime,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('academic_events')
                    .snapshots(),
                builder: (context, snapshot) {
                  final Map<DateTime, List> eventsMap = {};
                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;

                      final startTs = (data['startDate'] ??
                          data['date'] ??
                          Timestamp.now()) as Timestamp;
                      final endTs = (data['endDate'] ??
                          data['date'] ??
                          Timestamp.now()) as Timestamp;

                      DateTime start = startTs.toDate();
                      DateTime end = endTs.toDate();

                      // Normalize to date only
                      start = DateTime(start.year, start.month, start.day);
                      end = DateTime(end.year, end.month, end.day);

                      // Populate every day in the range
                      for (DateTime date = start;
                          date.isBefore(end.add(const Duration(days: 1)));
                          date = date.add(const Duration(days: 1))) {
                        final key = DateTime(date.year, date.month, date.day);
                        if (eventsMap[key] == null) eventsMap[key] = [];
                        eventsMap[key]!.add(data);
                      }
                    }
                  }

                  return TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _calendarFocusedDay,
                    onPageChanged: (focusedDay) {
                      _calendarFocusedDay = focusedDay;
                    },
                    currentDay: _currentTime,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      holidayTextStyle: const TextStyle(color: Colors.red),
                      todayDecoration: const BoxDecoration(
                          color: AppTheme.primaryColor, shape: BoxShape.circle),
                      markerDecoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      weekendTextStyle: const TextStyle(color: Colors.red),
                    ),
                    eventLoader: (day) {
                      List events =
                          eventsMap[DateTime(day.year, day.month, day.day)] ??
                              [];
                      // Merge with Indonesia Holidays
                      final localEvents =
                          IndonesiaHolidays.getEventsForDay(day);
                      return [...events, ...localEvents];
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final dayKey = DateTime(day.year, day.month, day.day);
                        final events = eventsMap[dayKey] ?? [];

                        // Check if this day is a holiday
                        bool isHoliday = IndonesiaHolidays.isHoliday(day) ||
                            events.any((e) => e['type'] == 'holiday');

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
                              width: 5,
                              height: 5,
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
                    onDaySelected: (selectedDay, focusedDay) {
                      List events = eventsMap[DateTime(selectedDay.year,
                              selectedDay.month, selectedDay.day)] ??
                          [];
                      final localEvents =
                          IndonesiaHolidays.getEventsForDay(selectedDay);
                      _showDayDetailOverlay(
                          selectedDay, [...events, ...localEvents]);
                    },
                  );
                }),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
