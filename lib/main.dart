import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_learning_app/services/auth_service.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:e_learning_app/screens/splash_screen.dart';
import 'package:e_learning_app/screens/admin_dashboard.dart';
import 'package:e_learning_app/screens/teacher_dashboard.dart';
import 'package:e_learning_app/screens/student_dashboard.dart';
import 'package:e_learning_app/screens/admin_assign_teacher.dart';
import 'package:e_learning_app/screens/teacher_attendance_qr.dart';
import 'package:e_learning_app/screens/student_krs.dart';
import 'package:e_learning_app/screens/student_enrolled_courses.dart';
import 'package:e_learning_app/screens/student_scanner.dart';
import 'package:e_learning_app/screens/student_grades_screen.dart';
import 'package:e_learning_app/screens/student_course_detail.dart';
import 'package:e_learning_app/screens/admin_user_management.dart';
import 'package:e_learning_app/screens/admin_course_management.dart';
import 'package:e_learning_app/screens/user_calendar_view.dart';
import 'package:e_learning_app/screens/profile_settings_screen.dart';
import 'package:e_learning_app/screens/teacher_classes_screen.dart';
import 'package:e_learning_app/screens/teacher_assignment_detail.dart';
import 'package:e_learning_app/screens/teacher_grades_screen.dart';
import 'package:e_learning_app/screens/admin_major_management.dart';
import 'package:e_learning_app/screens/select_major_screen.dart';
import 'package:flutter/foundation.dart';

import 'package:e_learning_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Enable offline persistence for instant data loading
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppTheme.themeNotifier,
          builder: (context, currentMode, _) {
            return MaterialApp(
              title: 'E-Learning App',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentMode,
              builder: (context, child) {
                return ResponsiveWrapper(child: child!);
              },
              home: snapshot.connectionState == ConnectionState.waiting
                  ? const SplashScreen()
                  : snapshot.hasData
                      ? const AuthWrapper()
                      : const SplashScreen(),
              routes: {
                '/admin': (context) => const AdminDashboard(),
                '/teacher': (context) => const TeacherDashboard(),
                '/student': (context) => const StudentDashboard(),
                '/admin-assign': (context) => const AdminAssignTeacherScreen(),
                '/teacher-qr': (context) => const TeacherAttendanceQrScreen(),
                '/student-krs': (context) => const StudentKrsView(),
                '/student-enrolled-courses': (context) =>
                    const StudentEnrolledCoursesView(),
                '/student-scanner': (context) => const StudentScannerScreen(),
                '/admin-users': (context) => const AdminUserManagementScreen(),
                '/admin-courses': (context) =>
                    const AdminCourseManagementScreen(),
                '/calendar-view': (context) => const StudentCalendarView(),
                '/profile-settings': (context) => const ProfileSettingsView(),
                '/teacher-classes': (context) => const TeacherClassesScreen(),
                '/teacher-grades': (context) => const TeacherGradesScreen(),
                '/admin-majors': (context) =>
                    const AdminMajorManagementScreen(),
                '/select-major': (context) => const SelectMajorScreen(),
                '/student-grades': (context) => const StudentGradesView(),
                '/student-course-detail': (context) {
                  final args = ModalRoute.of(context)!.settings.arguments
                      as Map<String, dynamic>;
                  return StudentCourseDetailScreen(
                    courseId: args['courseId'],
                    courseTitle: args['courseTitle'],
                    assignmentId: args['assignmentId'],
                    meetingId: args['meetingId'],
                  );
                },
                '/teacher-assignment-detail': (context) {
                  final args = ModalRoute.of(context)!.settings.arguments
                      as Map<String, dynamic>;
                  return TeacherAssignmentDetailScreen(
                    courseId: args['courseId'],
                    meetingId: args['meetingId'],
                    assignmentId: args['assignmentId'],
                    assignmentData: args['assignmentData'],
                  );
                },
              },
            );
          },
        );
      },
    );
  }
}

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  void _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'] ?? 'student';
      final major = doc.data()?['major'];

      if (mounted) {
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else if (role == 'teacher') {
          Navigator.pushReplacementNamed(context, '/teacher');
        } else {
          if (major == null || major.toString().trim().isEmpty) {
            Navigator.pushReplacementNamed(context, '/select-major');
          } else {
            Navigator.pushReplacementNamed(context, '/student');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
