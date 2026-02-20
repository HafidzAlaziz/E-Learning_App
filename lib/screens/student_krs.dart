import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';

class StudentKrsView extends StatefulWidget {
  final Function(int, {DateTime? initialDate})? onTabChange;

  const StudentKrsView({super.key, this.onTabChange});

  @override
  State<StudentKrsView> createState() => _StudentKrsViewState();
}

class _StudentKrsViewState extends State<StudentKrsView> {
  String? _userMajor;
  List<String> _enrolledCourseIds = [];
  int _selectedSemester = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Fetch User Major
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final major = userDoc.data()?['major'] as String?;

      // 2. Fetch User Enrollments
      final enrollmentsSnap = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .get();
      final enrolledIds =
          enrollmentsSnap.docs.map((doc) => doc['courseId'] as String).toList();

      if (mounted) {
        setState(() {
          _userMajor = major;
          _enrolledCourseIds = enrolledIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching KRS data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enrollInCourse(String courseId, String courseName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('enrollments').add({
        'studentId': uid,
        'courseId': courseId,
        'enrolledAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _enrolledCourseIds.add(courseId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Berhasil mengambil mata kuliah $courseName")),
        );
      }
    } catch (e) {
      debugPrint("Error enrolling in course: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userMajor == null || _userMajor!.isEmpty) {
      return const Center(
        child: Text("Silakan pilih Program Studi di Dashboard terlebih dahulu"),
      );
    }

    return Column(
      children: [
        // Custom Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text("Pengambilan KRS",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
        // Semester Selector
        StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('majors')
                .where('name', isEqualTo: _userMajor)
                .limit(1)
                .snapshots(),
            builder: (context, majorSnapshot) {
              int semesterCount = 8;
              if (majorSnapshot.hasData &&
                  majorSnapshot.data!.docs.isNotEmpty) {
                final data = majorSnapshot.data!.docs.first.data()
                    as Map<String, dynamic>;
                semesterCount = data['semesterCount'] ?? 8;
              }

              return SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: semesterCount,
                  itemBuilder: (context, index) {
                    final semester = index + 1;
                    final isSelected = _selectedSemester == semester;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: ChoiceChip(
                        label: Text("Semester $semester"),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedSemester = semester);
                          }
                        },
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        backgroundColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        showCheckmark: false,
                      ),
                    );
                  },
                ),
              );
            }),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {}); // Force rebuild to refresh stream
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('courses')
                  .where('category', isEqualTo: _userMajor)
                  .where('semester', isEqualTo: _selectedSemester)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Belum ada mata kuliah untuk Prodi $_userMajor",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final tempCourses = snapshot.data!.docs;
                final courses = tempCourses
                    .where((doc) => !_enrolledCourseIds.contains(doc.id))
                    .toList();

                if (courses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 64, color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          "Semua mata kuliah prodi $_userMajor sudah diambil",
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (widget.onTabChange != null) {
                              widget.onTabChange!(1); // Go to Courses (Index 1)
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Silakan cek menu Kursus Saya")));
                            }
                          },
                          child: const Text("Lihat Kursus Saya"),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final courseDoc = courses[index];
                    final course = courseDoc.data() as Map<String, dynamic>;
                    final courseId = courseDoc.id;
                    // isEnrolled is always false here because we filtered

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.book_rounded,
                              color: Colors.grey,
                            ),
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
                                        course['title'] ?? "Mata Kuliah",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "${course['sks'] ?? 0} SKS",
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  course['teacherName'] ?? "Belum ditugaskan",
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${course['day']}, ${course['startTime']} - ${course['endTime']}",
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.7),
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              await _enrollInCourse(courseId, course['title']);
                              // Navigation happens via state update in parent or snackbar
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text("Ambil"),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
