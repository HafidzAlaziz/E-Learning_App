import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:e_learning_app/widgets/user_avatar.dart';

class TeacherGradesScreen extends StatefulWidget {
  final bool isView;
  const TeacherGradesScreen({super.key, this.isView = false});

  @override
  State<TeacherGradesScreen> createState() => _TeacherGradesScreenState();
}

class _TeacherGradesScreenState extends State<TeacherGradesScreen> {
  String? selectedCourseId;
  List<Map<String, dynamic>> teacherCourses = [];
  List<Map<String, dynamic>> studentsGrades = [];
  bool isLoadingCourses = true;
  bool isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: uid)
          .get();

      setState(() {
        teacherCourses = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'title': doc['title'],
                })
            .toList();
        isLoadingCourses = false;
        if (teacherCourses.isNotEmpty) {
          selectedCourseId = teacherCourses[0]['id'];
          _fetchGradesData();
        }
      });
    } catch (e) {
      debugPrint("Error fetching courses: $e");
      setState(() => isLoadingCourses = false);
    }
  }

  Future<void> _fetchGradesData() async {
    if (selectedCourseId == null) return;
    setState(() => isLoadingData = true);

    try {
      // 1. Fetch Students
      final enrollments = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('courseId', isEqualTo: selectedCourseId)
          .get();

      // Fetch Course to get Grading Scheme
      final courseDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(selectedCourseId)
          .get();

      Map<String, double> gradingScheme = {
        'attendance': 10.0,
        'assignment': 20.0,
        'quiz': 20.0,
        'uts': 25.0,
        'uas': 25.0,
      };

      if (courseDoc.exists && courseDoc.data()!.containsKey('gradingScheme')) {
        final scheme =
            courseDoc.data()!['gradingScheme'] as Map<String, dynamic>;
        gradingScheme = scheme
            .map((key, value) => MapEntry(key, (value as num).toDouble()));
      }

      List<Map<String, dynamic>> students = [];
      for (var doc in enrollments.docs) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(doc['studentId'])
            .get();
        // Even if userDoc doesn't exist, we should show the student (maybe with fallback name)
        // because they are enrolled.
        // if (userDoc.exists) { <-- Removed strict check
        String name = 'Siswa (Tanpa Data)';
        String? photoBase64;
        String? photoUrl;

        if (userDoc.exists) {
          final data = userDoc.data();
          name = data?['displayName'] ?? 'Unknown';
          photoBase64 = data?['photoBase64'];
          photoUrl = data?['photoUrl'];
        }

        students.add({
          'uid': doc['studentId'],
          'name': name,
          'photoBase64': photoBase64,
          'photoUrl': photoUrl,
          'attendanceCount': 0,
          'scores': {
            'assignment': <double>[],
            'quiz': <double>[],
            'uts': <double>[],
            'uas': <double>[],
          },
          'gradingScheme': gradingScheme,
        });
        // }
      }

      // 2. Fetch Meetings (for attendance)
      final meetingsSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(selectedCourseId)
          .collection('meetings')
          .get();

      final totalMeetings = meetingsSnapshot.docs.length;

      // 3. For each student, fetch attendance and assignment grades
      for (var student in students) {
        // Attendance
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('courseId', isEqualTo: selectedCourseId)
            .where('studentId', isEqualTo: student['uid'])
            .get();
        student['attendanceCount'] = attendanceSnapshot.docs.length;
        student['totalMeetings'] = totalMeetings;

        // Assignments & Quizzes via collectionGroup for efficiency
        final submissionsSnapshot = await FirebaseFirestore.instance
            .collectionGroup('submissions')
            .where('studentId', isEqualTo: student['uid'])
            .get();

        final scores = student['scores'] as Map<String, List<double>>;

        for (var subDoc in submissionsSnapshot.docs) {
          if (subDoc.reference.path.contains('courses/$selectedCourseId')) {
            final data = subDoc.data();
            final grade = data['grade'];

            final assignmentRef = subDoc.reference.parent.parent;
            if (assignmentRef != null) {
              final assignmentDoc = await assignmentRef.get();
              final category =
                  assignmentDoc.data()?['category'] ?? 'assignment';

              if (grade != null && scores.containsKey(category)) {
                scores[category]!.add((grade as num).toDouble());
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          studentsGrades = students;
          isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching grades: $e");
      if (mounted) {
        setState(() => isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("Error: $e", style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = isLoadingCourses
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildCourseSelector(),
              Expanded(
                child: isLoadingData
                    ? const Center(child: CircularProgressIndicator())
                    : _buildGradesList(),
              ),
            ],
          );

    if (widget.isView) return content;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Nilai Siswa",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: content,
    );
  }

  Widget _buildCourseSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: DropdownButtonFormField<String>(
        value: selectedCourseId,
        decoration: AppTheme.inputDecoration(
            context, "Pilih Mata Kuliah", Icons.class_rounded),
        items: teacherCourses
            .map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(
                  value: c['id'] as String,
                  child: Text(c['title']),
                ))
            .toList(),
        onChanged: (val) {
          setState(() {
            selectedCourseId = val;
            _fetchGradesData();
          });
        },
      ),
    );
  }

  Widget _buildGradesList() {
    if (studentsGrades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("Belum ada siswa terdaftar",
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: studentsGrades.length,
      itemBuilder: (context, index) {
        final student = studentsGrades[index];
        final gradingScheme = student['gradingScheme'] as Map<String, double>;
        final scores = student['scores'] as Map<String, List<double>>;
        final totalMeetings = student['totalMeetings'] ?? 16;

        // Calculate Averages
        double getAvg(String key) {
          final list = scores[key]!;
          if (list.isEmpty) return 0.0;
          return list.reduce((a, b) => a + b) / list.length;
        }

        final avgAssignment = getAvg('assignment');
        final avgQuiz = getAvg('quiz');
        final avgUts = getAvg('uts');
        final avgUas = getAvg('uas');

        // Attendance Percentage
        final attendanceRate = totalMeetings > 0
            ? (student['attendanceCount'] / totalMeetings * 100)
                .clamp(0, 100)
                .toInt()
            : 0;

        // Final Grade Calculation
        final finalGrade =
            (attendanceRate * (gradingScheme['attendance']! / 100)) +
                (avgAssignment * (gradingScheme['assignment']! / 100)) +
                (avgQuiz * (gradingScheme['quiz']! / 100)) +
                (avgUts * (gradingScheme['uts']! / 100)) +
                (avgUas * (gradingScheme['uas']! / 100));

        // Color helper
        Color getGradeColor(double val) {
          if (val >= 85) return Colors.green;
          if (val >= 75) return Colors.blue;
          if (val >= 60) return Colors.orange;
          return Colors.red;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            leading: UserAvatar(
              radius: 20,
              uid: student['uid'],
              photoBase64: student['photoBase64'],
              photoUrl: student['photoUrl'],
            ),
            title: Text(student['name'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Nilai Akhir: ${finalGrade.toStringAsFixed(1)}"),
            trailing: _buildGradeBadge(finalGrade),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildGradeRow(
                        "Kehadiran (${gradingScheme['attendance']!.toInt()}%)",
                        "$attendanceRate%",
                        getGradeColor(attendanceRate.toDouble())),
                    _buildGradeRow(
                        "Tugas (${gradingScheme['assignment']!.toInt()}%)",
                        avgAssignment.toStringAsFixed(1),
                        getGradeColor(avgAssignment)),
                    _buildGradeRow("Kuis (${gradingScheme['quiz']!.toInt()}%)",
                        avgQuiz.toStringAsFixed(1), getGradeColor(avgQuiz)),
                    _buildGradeRow("UTS (${gradingScheme['uts']!.toInt()}%)",
                        avgUts.toStringAsFixed(1), getGradeColor(avgUts)),
                    _buildGradeRow("UAS (${gradingScheme['uas']!.toInt()}%)",
                        avgUas.toStringAsFixed(1), getGradeColor(avgUas)),
                    const Divider(),
                    _buildGradeRow("Nilai Akhir", finalGrade.toStringAsFixed(1),
                        getGradeColor(finalGrade),
                        isBold: true),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildGradeBadge(double grade) {
    String label = "E";
    Color color = Colors.red;
    if (grade >= 85) {
      label = "A";
      color = Colors.green;
    } else if (grade >= 75) {
      label = "B";
      color = Colors.blue;
    } else if (grade >= 65) {
      label = "C";
      color = Colors.orange;
    } else if (grade >= 50) {
      label = "D";
      color = Colors.deepOrange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGradeRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
