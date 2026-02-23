import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:e_learning_app/widgets/user_avatar.dart';

class TeacherAssignmentDetailScreen extends StatefulWidget {
  final String courseId;
  final String meetingId;
  final String assignmentId;
  final Map<String, dynamic> assignmentData;
  final int initialTab;

  const TeacherAssignmentDetailScreen({
    super.key,
    required this.courseId,
    required this.meetingId,
    required this.assignmentId,
    required this.assignmentData,
    this.initialTab = 0,
  });

  @override
  State<TeacherAssignmentDetailScreen> createState() =>
      _TeacherAssignmentDetailScreenState();
}

class _TeacherAssignmentDetailScreenState
    extends State<TeacherAssignmentDetailScreen> {
  // List of all students enrolled in the course
  List<Map<String, dynamic>> enrolledStudents = [];

  // Map of studentId -> Submission Data
  Map<String, Map<String, dynamic>> submissions = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch Enrolled Students
      // In a real app with 'enrollments' collection:
      final enrollments = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('courseId', isEqualTo: widget.courseId)
          .get();

      // Mocking student data if enrollments are empty/incomplete
      // For now, we'll try to fetch user details for each enrollment
      List<Map<String, dynamic>> students = [];
      for (var doc in enrollments.docs) {
        final studentId = doc['studentId'];
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();
        final data = userDoc.data();

        students.add({
          'uid': studentId,
          'name': data?['displayName'] ?? 'Siswa (Tanpa Data)',
          'email': data?['email'] ?? '-',
          'photoBase64': data?['photoBase64'],
          'photoUrl': data?['photoUrl'],
        });
      }

      // If no real enrollments found (dev mode), add some mocks if needed or just empty
      if (students.isEmpty) {
        // Optional: Add mock students for demonstration if db is empty
        // students = [
        //   {'uid': 'mock1', 'name': 'Ahmad Siswa', 'email': 'ahmad@test.com'},
        //   {'uid': 'mock2', 'name': 'Budi Belajar', 'email': 'budi@test.com'},
        // ];
      }

      // 2. Fetch Submissions for this assignment
      final submissionSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('meetings')
          .doc(widget.meetingId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .get();

      Map<String, Map<String, dynamic>> subs = {};
      for (var doc in submissionSnapshot.docs) {
        subs[doc.id] = doc.data(); // doc.id should be studentId
      }

      if (mounted) {
        setState(() {
          enrolledStudents = students;
          submissions = subs;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.trim().isEmpty) return;

    String formattedUrl = urlString.trim();
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    final Uri url = Uri.parse(formattedUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch URL')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal membuka link. Pastikan format link benar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Categorize students
    final submitted = enrolledStudents
        .where((s) => submissions.containsKey(s['uid']))
        .toList();
    final notSubmitted = enrolledStudents
        .where((s) => !submissions.containsKey(s['uid']))
        .toList();

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Detail Tugas",
              style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Belum Mengumpulkan"),
              Tab(text: "Sudah Mengumpulkan"),
            ],
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.assignmentData['title'] ?? 'Tugas',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.assignmentData['description'] ??
                        'Tidak ada deskripsi',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSummaryChip("Total Siswa",
                          enrolledStudents.length.toString(), Colors.blue),
                      const SizedBox(width: 8),
                      _buildSummaryChip(
                          "Sudah", submitted.length.toString(), Colors.green),
                      const SizedBox(width: 8),
                      _buildSummaryChip("Belum", notSubmitted.length.toString(),
                          Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildStudentList(notSubmitted, false),
                        _buildStudentList(submitted, true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, Color color) {
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
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(
      List<Map<String, dynamic>> students, bool isSubmitted) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSubmitted
                  ? Icons.assignment_turned_in_outlined
                  : Icons.pending_actions_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isSubmitted
                  ? "Belum ada yang mengumpulkan"
                  : "Semua sudah mengumpulkan!",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final submission = submissions[student['uid']];

        // Helper for grade color
        Color getGradeColor(double val) {
          if (val >= 85) return Colors.green;
          if (val >= 75) return Colors.blue;
          if (val >= 60) return Colors.orange;
          return Colors.red;
        }

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: UserAvatar(
              radius: 24,
              uid: student['uid'],
              photoBase64: student['photoBase64'],
              photoUrl: student['photoUrl'],
            ),
            title: Text(student['name'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: isSubmitted
                ? Text(
                    "Dikirim: ${submission?['submittedAt'] != null ? (submission!['submittedAt'] as Timestamp).toDate().toString().substring(0, 16) : '-'}",
                    style:
                        TextStyle(color: Colors.green.shade700, fontSize: 12),
                  )
                : Text("Belum mengumpulkan",
                    style:
                        TextStyle(color: Colors.orange.shade700, fontSize: 12)),
            trailing: isSubmitted
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (submission?['grade'] != null) ...[
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 20),
                        Text(
                          "${submission!['grade']}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: getGradeColor(
                                  (submission['grade'] as num).toDouble()),
                              fontSize: 12),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            "BELUM DINILAI",
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            onTap: isSubmitted
                ? () => _showGradeDialog(student['uid'], submission)
                : null,
          ),
        );
      },
    );
  }

  void _showGradeDialog(String studentId, Map<String, dynamic>? submission) {
    if (submission == null) return;

    final gradeController =
        TextEditingController(text: submission['grade']?.toString() ?? "");
    final feedbackController =
        TextEditingController(text: submission['feedback'] ?? "");
    final String content =
        submission['content'] ?? "Tidak ada lampiran teks/link.";
    final bool isLink = content.startsWith('http');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Beri Nilai"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Jawaban Siswa:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (content.isNotEmpty) ...[
                      Text(content, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                    ],
                    if (submission['link'] != null &&
                        submission['link'].toString().isNotEmpty) ...[
                      const Text("Link Lampiran:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.blue)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _launchURL(submission['link']),
                        child: Text(
                          submission['link'],
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _launchURL(submission['link']),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text("Buka Link Jawaban"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ] else if (isLink) ...[
                      // Fallback for older submissions where link was in content
                      ElevatedButton.icon(
                        onPressed: () => _launchURL(content),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text("Buka Link"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              TextField(
                controller: gradeController,
                keyboardType: TextInputType.number,
                decoration: AppTheme.inputDecoration(
                    context, "Nilai (0-100)", Icons.score),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                maxLines: 2,
                decoration: AppTheme.inputDecoration(
                    context, "Feedback (Opsional)", Icons.comment),
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
              final gradeStr = gradeController.text.trim();
              if (gradeStr.isEmpty) return;
              final grade = double.tryParse(gradeStr);
              if (grade == null) return;

              await FirebaseFirestore.instance
                  .collection('courses')
                  .doc(widget.courseId)
                  .collection('meetings')
                  .doc(widget.meetingId)
                  .collection('assignments')
                  .doc(widget.assignmentId)
                  .collection('submissions')
                  .doc(studentId)
                  .update({
                'grade': grade,
                'feedback': feedbackController.text.trim(),
                'gradedAt': FieldValue.serverTimestamp(),
              });

              if (context.mounted) {
                Navigator.pop(context);
                _fetchData();
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }
}
