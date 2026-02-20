import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';

class StudentGradesView extends StatefulWidget {
  const StudentGradesView({super.key});

  @override
  State<StudentGradesView> createState() => _StudentGradesViewState();
}

class _StudentGradesViewState extends State<StudentGradesView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _courseGrades = [];
  double _totalIPK = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchGrades();
  }

  Future<void> _fetchGrades() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Fetch Enrolled Courses
      final enrollmentsSnap = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .get();

      List<Map<String, dynamic>> gradesList = [];
      int index = 0;

      for (var enrollDoc in enrollmentsSnap.docs) {
        final courseId = enrollDoc['courseId'];

        // Fetch Course Details
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get();

        if (!courseDoc.exists) continue;
        final courseData = courseDoc.data()!;

        // Get Grading Scheme
        Map<String, double> gradingScheme = {
          'attendance': 10.0,
          'assignment': 20.0,
          'quiz': 20.0,
          'uts': 25.0,
          'uas': 25.0,
        };

        if (courseData.containsKey('gradingScheme')) {
          final scheme = courseData['gradingScheme'] as Map<String, dynamic>;
          gradingScheme = scheme
              .map((key, value) => MapEntry(key, (value as num).toDouble()));
        }

        // 2. Calculate Attendance
        final attendanceSnap = await FirebaseFirestore.instance
            .collection('attendance')
            .where('courseId', isEqualTo: courseId)
            .where('studentId', isEqualTo: uid)
            .get();

        final meetingsSnap = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .collection('meetings')
            .get();

        int presentCount = attendanceSnap.docs.length;
        int totalMeetings = meetingsSnap.docs.length;
        double attendanceScore = totalMeetings > 0
            ? (presentCount / totalMeetings * 100).clamp(0, 100)
            : 0;

        // 3. Calculate Assignment Grades
        final submissionsSnap = await FirebaseFirestore.instance
            .collectionGroup('submissions')
            .where('studentId', isEqualTo: uid)
            .get();

        Map<String, List<double>> scores = {
          'assignment': [],
          'quiz': [],
          'uts': [],
          'uas': [],
        };

        for (var subDoc in submissionsSnap.docs) {
          if (subDoc.reference.path.contains('courses/$courseId')) {
            final data = subDoc.data();
            final grade = data['grade'];

            if (grade != null) {
              // Determine category
              final assignmentRef = subDoc.reference.parent.parent;
              if (assignmentRef != null) {
                final assignmentDoc = await assignmentRef.get();
                final category =
                    assignmentDoc.data()?['category'] ?? 'assignment';

                if (scores.containsKey(category)) {
                  scores[category]!.add((grade as num).toDouble());
                }
              }
            }
          }
        }

        // Helper to calculate average
        double getAvg(String key) {
          final list = scores[key];
          if (list == null || list.isEmpty) return 0.0;
          return list.reduce((a, b) => a + b) / list.length;
        }

        final avgAssignment = getAvg('assignment');
        final avgQuiz = getAvg('quiz');
        final avgUts = getAvg('uts');
        final avgUas = getAvg('uas');

        double finalGrade =
            (attendanceScore * (gradingScheme['attendance']! / 100)) +
                (avgAssignment * (gradingScheme['assignment']! / 100)) +
                (avgQuiz * (gradingScheme['quiz']! / 100)) +
                (avgUts * (gradingScheme['uts']! / 100)) +
                (avgUas * (gradingScheme['uas']! / 100));

        gradesList.add({
          'courseTitle': courseData['title'] ?? 'Kursus',
          'teacherName': courseData['teacherName'] ?? 'Pengajar',
          'attendanceScore': attendanceScore,
          'assignmentScore': avgAssignment,
          'quizScore': avgQuiz,
          'utsScore': avgUts,
          'uasScore': avgUas,
          'finalGrade': finalGrade,
          'sks': courseData['sks'] ?? 0,
          'gradingScheme': gradingScheme,
        });

        index++; // Increment for dummy variation
      }

      // Calculate Total IPK
      double totalPoints = 0;
      int totalSksCalc = 0;

      for (var grade in gradesList) {
        double finalGrade = grade['finalGrade'];
        int sks = grade['sks'];

        double point = 0.0;
        if (finalGrade >= 85)
          point = 4.0;
        else if (finalGrade >= 75)
          point = 3.0;
        else if (finalGrade >= 65)
          point = 2.0;
        else if (finalGrade >= 50) point = 1.0;

        totalPoints += (point * sks);
        totalSksCalc += sks;
      }

      double calculatedIPK =
          totalSksCalc > 0 ? totalPoints / totalSksCalc : 0.0;

      if (mounted) {
        setState(() {
          _courseGrades = gradesList;
          _totalIPK = calculatedIPK;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching grades: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text('Riwayat Nilai',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              if (!_isLoading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school,
                          size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'IPK: ${_totalIPK.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _courseGrades.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchGrades,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _courseGrades.length,
                        itemBuilder: (context, index) {
                          final grade = _courseGrades[index];
                          return _buildGradeCard(grade);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_outlined,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "Belum ada nilai yang tersedia",
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeCard(Map<String, dynamic> grade) {
    final finalGrade = grade['finalGrade'] as double;
    final gradingScheme = grade['gradingScheme'] as Map<String, double>;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          grade['courseTitle'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          "${grade['teacherName']} • ${grade['sks']} SKS",
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: _buildGradeBadge(finalGrade),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(),
                _buildScoreRow(
                    "Kehadiran (${gradingScheme['attendance']!.toInt()}%)",
                    grade['attendanceScore'],
                    Colors.blue),
                _buildScoreRow(
                    "Tugas (${gradingScheme['assignment']!.toInt()}%)",
                    grade['assignmentScore'],
                    Colors.green),
                _buildScoreRow("Kuis (${gradingScheme['quiz']!.toInt()}%)",
                    grade['quizScore'], Colors.orange),
                _buildScoreRow("UTS (${gradingScheme['uts']!.toInt()}%)",
                    grade['utsScore'], Colors.purple),
                _buildScoreRow("UAS (${gradingScheme['uas']!.toInt()}%)",
                    grade['uasScore'], Colors.redAccent),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Rata-rata",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor),
                      ),
                      Text(
                        finalGrade.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeBadge(double grade) {
    String label = "E";
    double point = 0.0;
    Color color = Colors.red;
    if (grade >= 85) {
      label = "A";
      point = 4.0;
      color = Colors.green;
    } else if (grade >= 75) {
      label = "B";
      point = 3.0;
      color = Colors.blue;
    } else if (grade >= 65) {
      label = "C";
      point = 2.0;
      color = Colors.orange;
    } else if (grade >= 50) {
      label = "D";
      point = 1.0;
      color = Colors.deepOrange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$point",
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            "($label)",
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
