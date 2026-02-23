import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';

// ─── Data model ──────────────────────────────────────────────────────────────
class _CourseGrade {
  final String courseId;
  final String courseTitle;
  final String teacherName;
  final int sks;
  final int semester;
  final double attendanceScore;
  final double assignmentScore;
  final double quizScore;
  final double utsScore;
  final double uasScore;
  final double finalGrade;
  final Map<String, double> gradingScheme;

  const _CourseGrade({
    required this.courseId,
    required this.courseTitle,
    required this.teacherName,
    required this.sks,
    required this.semester,
    required this.attendanceScore,
    required this.assignmentScore,
    required this.quizScore,
    required this.utsScore,
    required this.uasScore,
    required this.finalGrade,
    required this.gradingScheme,
  });

  /// Convert finalGrade -> mutu 0.0 – 4.0
  double get mutu {
    if (finalGrade >= 85) return 4.0;
    if (finalGrade >= 75) return 3.0;
    if (finalGrade >= 65) return 2.0;
    if (finalGrade >= 50) return 1.0;
    return 0.0;
  }

  String get letterGrade {
    if (finalGrade >= 85) return 'A';
    if (finalGrade >= 75) return 'B';
    if (finalGrade >= 65) return 'C';
    if (finalGrade >= 50) return 'D';
    return 'E';
  }

  Color get gradeColor {
    if (finalGrade >= 85) return Colors.green;
    if (finalGrade >= 75) return Colors.blue;
    if (finalGrade >= 65) return Colors.orange;
    if (finalGrade >= 50) return Colors.deepOrange;
    return Colors.red;
  }
}

// ─── Main Widget ─────────────────────────────────────────────────────────────
class StudentGradesView extends StatefulWidget {
  const StudentGradesView({super.key});

  @override
  State<StudentGradesView> createState() => _StudentGradesViewState();
}

class _StudentGradesViewState extends State<StudentGradesView> {
  bool _isLoading = true;
  List<_CourseGrade> _allGrades = [];
  int _selectedSemester = 1;

  @override
  void initState() {
    super.initState();
    _fetchAllGrades();
  }

  // ─── Data Fetching ─────────────────────────────────────────────────────────
  Future<void> _fetchAllGrades() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      // Fetch user's major (variable 'major' was unused, so removed)
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

      // Fetch enrolled courses
      final enrollmentsSnap = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .get();

      // Fetch all grades in parallel
      final gradesFutures = enrollmentsSnap.docs.map((enrollDoc) async {
        final courseId = enrollDoc['courseId'] as String;

        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .get();

        if (!courseDoc.exists) return null;
        final courseData = courseDoc.data()!;

        // Grading Scheme
        Map<String, double> gradingScheme = {
          'attendance': 10.0,
          'assignment': 20.0,
          'quiz': 20.0,
          'uts': 25.0,
          'uas': 25.0,
        };
        if (courseData.containsKey('gradingScheme')) {
          final scheme = courseData['gradingScheme'] as Map<String, dynamic>;
          gradingScheme =
              scheme.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }

        // Attendance
        final results = await Future.wait([
          FirebaseFirestore.instance
              .collection('attendance')
              .where('courseId', isEqualTo: courseId)
              .where('studentId', isEqualTo: uid)
              .get(),
          FirebaseFirestore.instance
              .collection('courses')
              .doc(courseId)
              .collection('meetings')
              .get(),
          FirebaseFirestore.instance
              .collectionGroup('submissions')
              .where('studentId', isEqualTo: uid)
              .get(),
        ]);

        final attendanceSnap = results[0] as QuerySnapshot;
        final meetingsSnap = results[1] as QuerySnapshot;
        final submissionsSnap = results[2] as QuerySnapshot;

        final presentCount = attendanceSnap.docs.length;
        final totalMeetings = meetingsSnap.docs.length;
        final attendanceScore = totalMeetings > 0
            ? (presentCount / totalMeetings * 100).clamp(0.0, 100.0)
            : 0.0;

        // Assignment scores by category
        final Map<String, List<double>> scores = {
          'assignment': [],
          'quiz': [],
          'uts': [],
          'uas': [],
        };

        for (var subDoc in submissionsSnap.docs) {
          if (!subDoc.reference.path.contains('courses/$courseId')) continue;
          final data = subDoc.data() as Map<String, dynamic>;
          final grade = data['grade'];
          if (grade == null) continue;

          final assignmentRef = subDoc.reference.parent.parent;
          if (assignmentRef == null) continue;
          final assignmentDoc = await assignmentRef.get();
          final category =
              (assignmentDoc.data() as Map<String, dynamic>?)?['category'] ??
                  'assignment';

          if (scores.containsKey(category)) {
            scores[category]!.add(grade);
          }
        }

        double getAvg(String key) {
          final list = scores[key];
          if (list == null || list.isEmpty) return 0.0;
          return list.reduce((a, b) => a + b) / list.length;
        }

        final avgAssignment = getAvg('assignment');
        final avgQuiz = getAvg('quiz');
        final avgUts = getAvg('uts');
        final avgUas = getAvg('uas');

        final finalGrade =
            (attendanceScore * (gradingScheme['attendance']! / 100)) +
                (avgAssignment * (gradingScheme['assignment']! / 100)) +
                (avgQuiz * (gradingScheme['quiz']! / 100)) +
                (avgUts * (gradingScheme['uts']! / 100)) +
                (avgUas * (gradingScheme['uas']! / 100));

        return _CourseGrade(
          courseId: courseId,
          courseTitle: courseData['title'] ?? 'Kursus',
          teacherName: courseData['teacherName'] ?? 'Pengajar',
          sks: (courseData['sks'] as num?)?.toInt() ?? 0,
          semester: (courseData['semester'] as num?)?.toInt() ?? 1,
          attendanceScore: attendanceScore,
          assignmentScore: avgAssignment,
          quizScore: avgQuiz,
          utsScore: avgUts,
          uasScore: avgUas,
          finalGrade: finalGrade,
          gradingScheme: gradingScheme,
        );
      });

      final results = await Future.wait(gradesFutures);
      final allGrades = results.whereType<_CourseGrade>().toList();

      // Sort by semester then title
      allGrades.sort((a, b) {
        final semCmp = a.semester.compareTo(b.semester);
        return semCmp != 0 ? semCmp : a.courseTitle.compareTo(b.courseTitle);
      });

      // Set initial selected semester to the highest semester the student has
      int initialSemester = 1;
      if (allGrades.isNotEmpty) {
        initialSemester =
            allGrades.map((g) => g.semester).reduce((a, b) => a > b ? a : b);
      }

      if (mounted) {
        setState(() {
          _allGrades = allGrades;
          _isLoading = false;
          _selectedSemester = initialSemester;
        });
      }
    } catch (e) {
      debugPrint("Error fetching grades: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  List<int> get _availableSemesters {
    final sems = _allGrades.map((g) => g.semester).toSet().toList();
    sems.sort();
    return sems;
  }

  List<_CourseGrade> get _semesterGrades =>
      _allGrades.where((g) => g.semester == _selectedSemester).toList();

  /// IPS untuk semester tertentu
  double _calcIPS(List<_CourseGrade> grades) {
    double totalPoints = 0;
    int totalSks = 0;
    for (var g in grades) {
      totalPoints += g.mutu * g.sks;
      totalSks += g.sks;
    }
    return totalSks > 0 ? totalPoints / totalSks : 0.0;
  }

  /// IPK dari semua grade
  double get _ipk => _calcIPS(_allGrades);

  /// Semester terbaru (nilai tertinggi)

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        if (!_isLoading && _allGrades.isNotEmpty) _buildSemesterChips(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allGrades.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchAllGrades,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _buildSemesterSummaryCard(),
                          const SizedBox(height: 16),
                          ..._semesterGrades.map(_buildGradeCard),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text('Riwayat Nilai',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          if (!_isLoading && _allGrades.isNotEmpty)
            _buildBadge(
              Icons.school,
              'IPK: ${_ipk.toStringAsFixed(2)}',
              AppTheme.primaryColor,
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ─── Semester Chips ───────────────────────────────────────────────────────
  Widget _buildSemesterChips() {
    final semesters = _availableSemesters;

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: semesters.length,
        itemBuilder: (ctx, i) {
          final sem = semesters[i];
          final isSelected = _selectedSemester == sem;
          final semGrades = _allGrades.where((g) => g.semester == sem).toList();
          _calcIPS(semGrades);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: GestureDetector(
              onTap: () => setState(() => _selectedSemester = sem),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey.withOpacity(0.3),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  'Sem $sem',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Semester Summary Card ────────────────────────────────────────────────
  Widget _buildSemesterSummaryCard() {
    final semGrades = _semesterGrades;
    final ips = _calcIPS(semGrades);
    final semTotalSks = semGrades.fold(0, (totalSks, g) => totalSks + g.sks);

    Color ipsColor = Colors.red;
    if (ips >= 3.5) {
      ipsColor = Colors.green;
    } else if (ips >= 3.0) {
      ipsColor = Colors.blue;
    } else if (ips >= 2.5) {
      ipsColor = Colors.orange;
    } else if (ips >= 2.0) {
      ipsColor = Colors.deepOrange;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.08),
            AppTheme.primaryColor.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Semester $_selectedSemester',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${semGrades.length} Matkul • $semTotalSks SKS',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStat(
                  'IPS Semester',
                  ips.toStringAsFixed(2),
                  ipsColor,
                  Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStat(
                  'Total SKS',
                  '$semTotalSks SKS',
                  Colors.teal,
                  Icons.book_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ─── Grade Card ───────────────────────────────────────────────────────────
  Widget _buildGradeCard(_CourseGrade grade) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 1.5,
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          grade.courseTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${grade.teacherName} • ${grade.sks} SKS',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: _buildGradeBadge(grade),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(),
                _buildScoreRow(
                  'Kehadiran (${grade.gradingScheme['attendance']!.toInt()}%)',
                  grade.attendanceScore,
                  Colors.blue,
                ),
                _buildScoreRow(
                  'Tugas (${grade.gradingScheme['assignment']!.toInt()}%)',
                  grade.assignmentScore,
                  Colors.green,
                ),
                _buildScoreRow(
                  'Kuis (${grade.gradingScheme['quiz']!.toInt()}%)',
                  grade.quizScore,
                  Colors.orange,
                ),
                _buildScoreRow(
                  'UTS (${grade.gradingScheme['uts']!.toInt()}%)',
                  grade.utsScore,
                  Colors.purple,
                ),
                _buildScoreRow(
                  'UAS (${grade.gradingScheme['uas']!.toInt()}%)',
                  grade.uasScore,
                  Colors.redAccent,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: grade.gradeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nilai Akhir',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: grade.gradeColor,
                        ),
                      ),
                      Text(
                        grade.finalGrade.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: grade.gradeColor,
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

  Widget _buildGradeBadge(_CourseGrade grade) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: grade.gradeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: grade.gradeColor.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            grade.letterGrade,
            style: TextStyle(
              color: grade.gradeColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            grade.finalGrade.toStringAsFixed(1),
            style: TextStyle(
              color: grade.gradeColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
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
            'Belum ada nilai yang tersedia',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
