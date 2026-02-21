import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:e_learning_app/services/auth_service.dart';
import 'package:e_learning_app/widgets/user_avatar.dart';
import 'package:intl/date_symbol_data_local.dart';

// Views
import 'package:e_learning_app/screens/student_home_view.dart';
import 'package:e_learning_app/screens/student_enrolled_courses.dart';
import 'package:e_learning_app/screens/student_krs.dart';
import 'package:e_learning_app/screens/student_grades_screen.dart';
import 'package:e_learning_app/screens/user_calendar_view.dart';
import 'package:e_learning_app/screens/profile_settings_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  List<String> _enrolledCourseIds = [];
  Map<String, String> _enrolledCourseNames = {};
  DateTime? _calendarInitialDate;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _fetchEnrolledCourses();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchEnrolledCourses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final enrollmentsSnap = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .get();

      final ids =
          enrollmentsSnap.docs.map((d) => d['courseId'] as String).toList();

      if (ids.isNotEmpty) {
        // Fetch course names for notification display
        // Firestore 'whereIn' is limited to 10. If > 10, we might need multiple queries.
        // For simplicity/safety, we'll slice if needed, or just fetch all logic.
        // Here assuming user has < 30 courses. If whereIn > 10, it effectively fails or needs split.
        // We will take top 10 for now to avoid crash, or split logic.
        // Simplest valid approach: Split into chunks of 10.
        Map<String, String> names = {};

        for (var i = 0; i < ids.length; i += 10) {
          final chunk =
              ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
          final coursesSnap = await FirebaseFirestore.instance
              .collection('courses')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var d in coursesSnap.docs) {
            names[d.id] = d['title'] as String;
          }
        }

        if (mounted) {
          setState(() {
            _enrolledCourseIds = ids;
            _enrolledCourseNames = names;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _enrolledCourseIds = [];
            _enrolledCourseNames = {};
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching enrolled courses in shell: $e");
    }
  }

  final List<String> _titles = [
    "E-Learning",
    "Kursus Saya",
    "Kartu Rencana Studi",
    "Riwayat Nilai",
    "Kalender Akademik",
    "Profil Pengguna",
  ];

  void _onItemTapped(int index, {DateTime? initialDate}) {
    setState(() {
      _currentIndex = index;
      _calendarInitialDate = initialDate;
    });
    // Refresh enrolled courses if navigating to Home or Courses (to ensure fresh data)
    if (index == 0 || index == 1) {
      _fetchEnrolledCourses();
    }
  }

  Widget _buildScreen(int index) {
    // We recreate the widget to ensure 'initState' runs (fetching fresh data).
    // EXCEPT for Home, keep it alive? No, existing behavior relies on fetching.
    switch (index) {
      case 0:
        return StudentHomeView(
          onTabChange: _onItemTapped,
        );
      case 1:
        return StudentEnrolledCoursesView(onTabChange: _onItemTapped);
      case 2:
        return StudentKrsView(onTabChange: _onItemTapped);
      case 3:
        return const StudentGradesView();
      case 4:
        return StudentCalendarView(initialDate: _calendarInitialDate);
      case 5:
        return const ProfileSettingsView();
      default:
        return const Center(child: Text("Halaman tidak ditemukan"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // Floating Action Button only for Home
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, '/student-scanner');
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan Absen"),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,

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
          // User Avatar navigates to Profil (index 5)
          GestureDetector(
            onTap: () => _onItemTapped(5),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: UserAvatar(
                radius: 18,
                onTap: () => _onItemTapped(5),
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
                          "${FirebaseAuth.instance.currentUser?.displayName ?? 'Siswa'} (Siswa)",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          FirebaseAuth.instance.currentUser?.email ??
                              "student@elearning.com",
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
              leading: const Icon(Icons.home_rounded),
              title: const Text("Beranda"),
              selected: _currentIndex == 0,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_rounded),
              title: const Text("Kursus Saya"),
              selected: _currentIndex == 1,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt_rounded),
              title: const Text("Daftar Matkul"),
              selected: _currentIndex == 2,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text("Nilai"),
              selected: _currentIndex == 3,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text("Kalender"),
              selected: _currentIndex == 4,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text("Profil"),
              selected: _currentIndex == 5,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(5);
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
      body: Stack(
        children: [
          // Main Content
          _buildScreen(_currentIndex),

          // Real-time Attendance Notification (Floating)
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('meetings')
                  .where('isAttendanceActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const SizedBox.shrink();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                // Filter by student's enrolled courses
                final activeSessions = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _enrolledCourseIds.contains(data['courseId']);
                }).toList();

                if (activeSessions.isEmpty) return const SizedBox.shrink();

                final session =
                    activeSessions.first.data() as Map<String, dynamic>;
                final courseName = session['courseName'] ??
                    _enrolledCourseNames[session['courseId']] ??
                    'Mata Kuliah';

                return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('attendance')
                        .where('meetingId', isEqualTo: activeSessions.first.id)
                        .where('studentId',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, attendanceCheckSnap) {
                      final hasAttended = attendanceCheckSnap.hasData &&
                          attendanceCheckSnap.data!.docs.isNotEmpty;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: hasAttended
                              ? Colors.blue.shade600
                              : Colors.green.shade600,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (hasAttended ? Colors.blue : Colors.green)
                                  .withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                                hasAttended
                                    ? Icons.check_circle
                                    : Icons.qr_code_scanner,
                                color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasAttended
                                        ? "Anda Sudah Absen"
                                        : "Absensi Telah Dibuka!",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  Text(
                                    "Matkul $courseName",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!hasAttended)
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                      context, '/student-scanner');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.green.shade700,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text("Scan Now",
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              )
                            else
                              const Text(
                                "Berhasil",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                          ],
                        ),
                      );
                    });
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.book_rounded), label: 'Kursus'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded), label: 'Matkul'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), label: 'Nilai'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded), label: 'Kalender'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded), label: 'Profil'),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}
