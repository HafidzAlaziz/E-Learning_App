import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:e_learning_app/services/auth_service.dart';
import 'package:e_learning_app/widgets/user_avatar.dart';

import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:e_learning_app/core/calendar_utils.dart';
import 'package:e_learning_app/screens/teacher_class_detail.dart';
import 'package:e_learning_app/screens/teacher_classes_screen.dart';
import 'package:e_learning_app/screens/teacher_grades_screen.dart';
import 'package:e_learning_app/screens/user_calendar_view.dart';
import 'package:e_learning_app/screens/profile_settings_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with TickerProviderStateMixin {
  int activeStudentsCount = 0;
  bool isLoadingStudents = true;
  String _currentTime = "";
  String _currentDate = "";
  String _nextClassMessage = "Mencari jadwal berikutnya...";
  DocumentSnapshot? _nextClassDoc;
  late Timer _timer;
  late AnimationController _bellAnimationController;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);

    _bellAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _fetchActiveStudentsCount();
    _updateTime();
    _fetchNextClass();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
      // Refresh next class info every minute
      if (DateTime.now().second == 0) {
        _fetchNextClass();
      }
    });
  }

  int _currentIndex = 0;
  final List<String> _titles = [
    "E-Learning (Teacher)",
    "Kelas Saya",
    "Nilai Siswa",
    "Kalender Akademik",
    "Profil & Pengaturan",
  ];

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return _buildHomeView();
      case 1:
        return const TeacherClassesScreen(isView: true);
      case 2:
        return const TeacherGradesScreen(isView: true);
      case 3:
        return const StudentCalendarView();
      case 4:
        return const ProfileSettingsView();
      default:
        return const Center(child: Text("Halaman tidak ditemukan"));
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _bellAnimationController.dispose();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm:ss').format(now);
        _currentDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
      });
    }
  }

  Future<void> _fetchNextClass() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: uid)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _nextClassMessage = "Tidak ada jadwal mengajar";
            _nextClassDoc = null;
          });
        }
        return;
      }

      final now = DateTime.now();
      DocumentSnapshot? nextClass;
      int minDiffMinutes = 999999;

      final dayToIdx = {
        'Senin': 1,
        'Selasa': 2,
        'Rabu': 3,
        'Kamis': 4,
        'Jumat': 5,
        'Sabtu': 6,
        'Minggu': 7
      };

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dayStr = data['day'] as String;
        final startTime = data['startTime'] as String;
        final targetDayIdx = dayToIdx[dayStr] ?? 1;

        DateTime? classTimeNormalized;
        try {
          final parts = startTime.split(':');
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1].split(' ')[0]);
          classTimeNormalized = DateTime(now.year, now.month, now.day, h, m);

          if (startTime.toUpperCase().contains('PM') && h < 12) {
            classTimeNormalized =
                classTimeNormalized.add(const Duration(hours: 12));
          } else if (startTime.toUpperCase().contains('AM') && h == 12) {
            classTimeNormalized =
                classTimeNormalized.subtract(const Duration(hours: 12));
          }
        } catch (_) {
          classTimeNormalized = DateTime(now.year, now.month, now.day, 0, 0);
        }

        // Find the next occurrence of this class
        DateTime classDateTime = classTimeNormalized;

        // If the day is different or time has passed today, move to next occurrence
        int daysUntil = targetDayIdx - now.weekday;
        if (daysUntil < 0 || (daysUntil == 0 && classDateTime.isBefore(now))) {
          daysUntil += 7;
        }

        classDateTime = classDateTime.add(Duration(days: daysUntil));
        final diff = classDateTime.difference(now).inMinutes;

        if (diff >= 0 && diff < minDiffMinutes) {
          minDiffMinutes = diff;
          nextClass = doc;
        }
      }

      if (mounted) {
        setState(() {
          _nextClassDoc = nextClass;
          if (nextClass != null) {
            final data = nextClass!.data() as Map<String, dynamic>;
            final dayStr = data['day'] as String;
            final startTime = data['startTime'] as String;

            if (minDiffMinutes < 60) {
              _nextClassMessage =
                  "$minDiffMinutes menit lagi kelas ${data['title']}";
            } else if (minDiffMinutes < 24 * 60 &&
                DateTime.now().weekday == dayToIdx[dayStr]) {
              final h = minDiffMinutes ~/ 60;
              final m = minDiffMinutes % 60;
              _nextClassMessage = "$h jam $m menit lagi kelas ${data['title']}";
            } else {
              // Future day
              final nowDay = DateTime(now.year, now.month, now.day);
              final classDay = nowDay.add(Duration(
                  days: (dayToIdx[dayStr]! - now.weekday + 7) % 7 == 0 &&
                          minDiffMinutes > 1440
                      ? 7
                      : (dayToIdx[dayStr]! - now.weekday + 7) % 7));

              final diffDays = classDay.difference(nowDay).inDays;

              String dayDisplay;
              if (diffDays == 1) {
                dayDisplay = "Besok";
              } else if (diffDays == 0) {
                dayDisplay = "Hari ini";
              } else {
                dayDisplay = dayStr;
              }

              _nextClassMessage =
                  "$dayDisplay pukul $startTime kelas ${data['title']}";
            }
          } else {
            _nextClassMessage = "Belum ada jadwal tersedia";
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching next class: $e");
    }
  }

  Future<void> _fetchActiveStudentsCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: uid)
          .get();

      final courseIds = coursesSnapshot.docs.map((doc) => doc.id).toList();

      if (courseIds.isEmpty) {
        if (mounted) {
          setState(() {
            activeStudentsCount = 0;
            isLoadingStudents = false;
          });
        }
        return;
      }

      int total = 0;
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('courseId', whereIn: courseIds)
          .count()
          .get();

      total = enrollmentsSnapshot.count ?? 0;

      if (mounted) {
        setState(() {
          activeStudentsCount = total;
          isLoadingStudents = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching active students: $e");
      if (mounted) {
        setState(() => isLoadingStudents = false);
      }
    }
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
            onTap: () => _onItemTapped(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: UserAvatar(
                radius: 18,
                onTap: () => _onItemTapped(4),
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
                          "${FirebaseAuth.instance.currentUser?.displayName ?? 'Teacher User'} (Teacher)",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          FirebaseAuth.instance.currentUser?.email ??
                              "teacher@elearning.com",
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
              leading: const Icon(Icons.class_rounded),
              title: const Text("Kelas Saya"),
              selected: _currentIndex == 1,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_rounded),
              title: const Text("Nilai Siswa"),
              selected: _currentIndex == 2,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text("Kalender Akademik"),
              selected: _currentIndex == 3,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text("Profil & Pengaturan"),
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
              icon: Icon(Icons.class_rounded), label: 'Kelas'),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded), label: 'Nilai'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded), label: 'Kalender'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded), label: 'Profil'),
        ],
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildHomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Status Pengajaran",
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
                      .collection('courses')
                      .where('teacherId',
                          isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String count = "0";
                    if (snapshot.hasData) {
                      count = snapshot.data!.docs.length.toString();
                    }
                    return GestureDetector(
                      onTap: () => _onItemTapped(1),
                      child: _buildStatCard(
                        context,
                        "Total Kelas",
                        count,
                        Icons.groups_rounded,
                        Colors.indigo,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  "Siswa Aktif",
                  isLoadingStudents ? "..." : activeStudentsCount.toString(),
                  Icons.person_search_rounded,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00695C),
                  Color(0xFF004D40),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004D40).withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _nextClassDoc != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TeacherClassDetailScreen(
                              courseId: _nextClassDoc!.id,
                              courseData:
                                  _nextClassDoc!.data() as Map<String, dynamic>,
                            ),
                          ),
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        _currentTime,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        _currentDate,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8F00), // Solid Amber/Orange
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _bellAnimationController,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _bellAnimationController.value * 0.2 -
                                      0.1,
                                  child: const Icon(
                                      Icons.notifications_active_rounded,
                                      color: Colors.white,
                                      size: 20),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _nextClassMessage,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Informasi & Notifikasi",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildNotificationsList(context),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, coursesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('academic_events')
              .where('endDate',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day)))
              .snapshots(),
          builder: (context, eventsSnap) {
            final myCourseIds =
                coursesSnap.data?.docs.map((d) => d.id).toList() ?? [];

            return StreamBuilder<QuerySnapshot?>(
              stream: myCourseIds.isEmpty
                  ? Stream<QuerySnapshot?>.value(null)
                  : FirebaseFirestore.instance
                      .collectionGroup('submissions')
                      .where('submittedAt',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day)))
                      .snapshots(),
              builder: (context, submissionsSnap) {
                final now = DateTime.now();
                final startOfToday = DateTime(now.year, now.month, now.day);
                final currentDay = DateFormat('EEEE').format(now);
                final daysId = {
                  'Monday': 'Senin',
                  'Tuesday': 'Selasa',
                  'Wednesday': 'Rabu',
                  'Thursday': 'Kamis',
                  'Friday': 'Jumat',
                  'Saturday': 'Sabtu',
                  'Sunday': 'Minggu',
                };
                final todayId = daysId[currentDay];

                List<Map<String, dynamic>> allNotifs = [];

                // 1. Today's Classes
                if (coursesSnap.hasData) {
                  for (var doc in coursesSnap.data!.docs) {
                    if (doc['day'] == todayId) {
                      allNotifs.add({
                        'type': 'class',
                        'label': 'Jadwal Mengajar',
                        'title':
                            "Jangan lupa hari ini ada kelas ${doc['title']}",
                        'subtitle': "Pukul ${doc['startTime']}",
                        'icon': Icons.calendar_today_rounded,
                        'color': Colors.blue,
                        'timestamp': startOfToday,
                        'onTap': () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TeacherClassDetailScreen(
                                  courseId: doc.id,
                                  courseData:
                                      doc.data() as Map<String, dynamic>,
                                ),
                              ),
                            ),
                      });
                    }
                  }
                }

                // 2. Academic Events & Holidays
                if (eventsSnap.hasData) {
                  for (var doc in eventsSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final startTs = data['startDate'] as Timestamp?;
                    if (startTs == null) continue;
                    final start = startTs.toDate();
                    allNotifs.add({
                      'type': 'event',
                      'label': data['type'] == 'holiday' ? 'Libur' : 'Event',
                      'title': data['title'],
                      'subtitle': data['description'] ?? '',
                      'icon': data['type'] == 'holiday'
                          ? Icons.calendar_today_rounded
                          : Icons.event_note_rounded,
                      'color': data['type'] == 'holiday'
                          ? Colors.red
                          : Colors.blue, // Event unified to blue
                      'timestamp': start,
                      'onTap': () => _onItemTapped(3),
                    });
                  }
                }

                // 3. Local Holidays
                for (var h in IndonesiaHolidays.getEventsForDay(now)) {
                  allNotifs.add({
                    'type': 'holiday',
                    'label': 'Libur',
                    'title': h['title'],
                    'subtitle': h['description'],
                    'icon': Icons.calendar_today_rounded,
                    'color': Colors.red,
                    'timestamp': startOfToday,
                    'onTap': () => _onItemTapped(3),
                  });
                }

                // 4. Submissions
                if (submissionsSnap.hasData && submissionsSnap.data != null) {
                  for (var doc in submissionsSnap.data!.docs) {
                    final pathParts = doc.reference.path.split('/');
                    if (pathParts.length < 6) continue;

                    final courseIdInPath = pathParts[1];
                    if (!myCourseIds.contains(courseIdInPath)) continue;

                    final data = doc.data() as Map<String, dynamic>;
                    final submittedAtTs = data['submittedAt'] as Timestamp?;
                    if (submittedAtTs == null) continue;
                    final submittedAt = submittedAtTs.toDate();
                    final courseDoc = coursesSnap.data!.docs
                        .firstWhere((d) => d.id == courseIdInPath);

                    allNotifs.add({
                      'type': 'submission',
                      'label': 'Tugas Siswa',
                      'title':
                          "${data['studentName'] ?? 'Siswa'} mengumpulkan tugas",
                      'subtitle':
                          "Kelas ${courseDoc['title']} - Pukul ${DateFormat('HH:mm').format(submittedAt)}",
                      'icon': Icons.assignment_turned_in_rounded,
                      'color':
                          Colors.orange, // Standardized to Orange for Tugas
                      'timestamp': submittedAt,
                      'onTap': () => Navigator.pushNamed(
                            context,
                            '/teacher-assignment-detail',
                            arguments: {
                              'courseId': courseIdInPath,
                              'meetingId': pathParts[3],
                              'assignmentId': pathParts[5],
                              'assignmentData': {
                                'title': data['assignmentTitle'] ?? 'Tugas',
                                'description':
                                    data['assignmentDescription'] ?? '',
                              },
                            },
                          ),
                    });
                  }
                }

                // Sort and render: Priority Class(0), Submission(1), Holiday(10)
                allNotifs.sort((a, b) {
                  int priorityA = a['type'] == 'class'
                      ? 0
                      : (a['type'] == 'submission' ? 1 : 10);
                  int priorityB = b['type'] == 'class'
                      ? 0
                      : (b['type'] == 'submission' ? 1 : 10);

                  if (priorityA != priorityB) {
                    return priorityA.compareTo(priorityB);
                  }
                  return (b['timestamp'] as DateTime)
                      .compareTo(a['timestamp'] as DateTime);
                });

                if (allNotifs.isEmpty) {
                  return _buildUpcomingTask(
                    context,
                    "Belum ada aktivitas baru hari ini",
                    "Bersantai sejenak",
                    Icons.coffee_rounded,
                    Colors.brown,
                  );
                }

                return Column(
                  children: allNotifs.take(8).map((it) {
                    return _buildUpcomingTask(
                      context,
                      it['title'],
                      it['subtitle'],
                      it['icon'],
                      it['color'],
                      label: it['label'],
                      onTap: it['onTap'],
                    );
                  }).toList(),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
    );
  }

  Widget _buildUpcomingTask(BuildContext context, String text, String time,
      IconData icon, Color iconColor,
      {String? label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (label != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: iconColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
