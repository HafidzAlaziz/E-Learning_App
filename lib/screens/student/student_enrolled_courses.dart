import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';

class StudentEnrolledCoursesView extends StatefulWidget {
  final Function(int, {DateTime? initialDate})? onTabChange;

  const StudentEnrolledCoursesView({super.key, this.onTabChange});

  @override
  State<StudentEnrolledCoursesView> createState() =>
      _StudentEnrolledCoursesViewState();
}

class _StudentEnrolledCoursesViewState
    extends State<StudentEnrolledCoursesView> {
  Map<String, List<Map<String, dynamic>>> _coursesByDay = {};
  bool _isLoading = true;
  int _totalSks = 0;

  final List<String> _dayOrder = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  @override
  void initState() {
    super.initState();
    _fetchEnrolledCourses();
  }

  Future<void> _fetchEnrolledCourses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      // 1. Fetch enrolled course IDs
      final enrollmentsSnap = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .get();

      final enrolledCourseIds =
          enrollmentsSnap.docs.map((doc) => doc['courseId'] as String).toList();

      if (enrolledCourseIds.isEmpty) {
        setState(() {
          _coursesByDay = {};
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch course details for enrolled courses
      final coursesSnap = await FirebaseFirestore.instance
          .collection('courses')
          .where(FieldPath.documentId, whereIn: enrolledCourseIds)
          .get();

      // 3. Group courses by day
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var doc in coursesSnap.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        final day = data['day'] as String? ?? 'Lainnya';
        if (!grouped.containsKey(day)) {
          grouped[day] = [];
        }
        grouped[day]!.add(data);
      }

      // 4. Sort courses within each day by startTime
      grouped.forEach((day, courses) {
        courses.sort((a, b) {
          final timeA = a['startTime'] as String? ?? '00:00';
          final timeB = b['startTime'] as String? ?? '00:00';
          return timeA.compareTo(timeB);
        });
      });

      int totalSks = 0;
      for (var doc in coursesSnap.docs) {
        totalSks += (doc.data()['sks'] as num?)?.toInt() ?? 0;
      }

      if (mounted) {
        setState(() {
          _coursesByDay = grouped;
          _totalSks = totalSks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching enrolled courses: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Header since Scaffold AppBar is in Shell
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text('Daftar Mata Kuliah',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Text(
                  '$_totalSks SKS',
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _coursesByDay.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchEnrolledCourses,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _buildDaySections(),
                      ),
                    ),
        ),
      ],
    );
  }

  List<Widget> _buildDaySections() {
    List<Widget> sections = [];

    for (String day in _dayOrder) {
      if (_coursesByDay.containsKey(day) && _coursesByDay[day]!.isNotEmpty) {
        sections.add(_buildDayHeader(day));
        sections.addAll(
            _coursesByDay[day]!.map((course) => _buildCourseCard(course)));
        sections.add(const SizedBox(height: 16));
      }
    }

    // Add any remaining days not in the standard order
    _coursesByDay.forEach((day, courses) {
      if (!_dayOrder.contains(day) && courses.isNotEmpty) {
        sections.add(_buildDayHeader(day));
        sections.addAll(courses.map((course) => _buildCourseCard(course)));
        sections.add(const SizedBox(height: 16));
      }
    });

    return sections;
  }

  Widget _buildDayHeader(String day) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            day,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final startTime = course['startTime'] as String? ?? '-';
    final endTime = course['endTime'] as String? ?? '-';
    final room = course['room'] as String? ??
        course['location'] as String? ??
        'Ruang TBA';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/student-course-detail',
            arguments: {
              'courseId': course['id'],
              'courseTitle': course['courseName'] ?? 'Mata Kuliah',
            },
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${course['sks'] ?? 0} SKS",
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$startTime - $endTime',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                course['courseName'] ?? course['title'] ?? 'Nama Mata Kuliah',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      course['teacherName'] ?? 'Dosen',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.meeting_room_outlined,
                      size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    room,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "Semester ${course['semester'] ?? '-'}",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Mata Kuliah',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ambil mata kuliah di menu Kursus',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              if (widget.onTabChange != null) {
                widget.onTabChange!(2); // Navigate to KRS (index 2)
              } else {
                Navigator.pushNamed(context, '/student-krs');
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Ambil Mata Kuliah'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
