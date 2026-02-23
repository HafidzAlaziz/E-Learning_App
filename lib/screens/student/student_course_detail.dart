import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentCourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String? assignmentId;
  final String? meetingId;

  const StudentCourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.assignmentId,
    this.meetingId,
  });

  @override
  State<StudentCourseDetailScreen> createState() =>
      _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState extends State<StudentCourseDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _meetings = [];
  late String _displayTitle;

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.courseTitle;
    _fetchMeetings();
    if (_displayTitle == 'Detail Mata Kuliah' ||
        _displayTitle == 'Mata Kuliah' ||
        _displayTitle.isEmpty) {
      _fetchCourseTitle();
    }
  }

  Future<void> _fetchCourseTitle() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _displayTitle = doc.data()?['title'] ?? 'Detail Mata Kuliah';
        });
      }
    } catch (e) {
      debugPrint("Error fetching course title: $e");
    }
  }

  Future<void> _fetchMeetings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final meetingsSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('meetings')
          .orderBy('meetingNumber', descending: false)
          .get();

      // Parallelize fetching for ALL meetings
      final meetings = await Future.wait(meetingsSnapshot.docs.map((doc) async {
        final meetingData = doc.data();
        meetingData['id'] = doc.id;

        // Parallelize sub-data for EACH meeting
        final results = await Future.wait([
          doc.reference.collection('assignments').get(),
          doc.reference.collection('materials').get(),
          FirebaseFirestore.instance
              .collection('attendance')
              .where('meetingId', isEqualTo: doc.id)
              .where('studentId', isEqualTo: uid)
              .limit(1)
              .get(),
        ]);

        final assignmentsSnapshot = results[0] as QuerySnapshot;
        final materialsSnapshot = results[1] as QuerySnapshot;
        final attendanceSnap = results[2] as QuerySnapshot;

        // Parallelize submission check for assignments
        final List<Map<String, dynamic>> assignments = await Future.wait(
          assignmentsSnapshot.docs.map((assignDoc) async {
            final assignData = assignDoc.data() as Map<String, dynamic>;
            assignData['id'] = assignDoc.id;

            final submissionDoc = await assignDoc.reference
                .collection('submissions')
                .doc(uid)
                .get();

            return {
              ...assignData,
              'submission': submissionDoc.exists ? submissionDoc.data() : null,
            };
          }),
        );

        meetingData['assignments'] = assignments;
        meetingData['materials'] = materialsSnapshot.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          data['id'] = d.id;
          return data;
        }).toList();
        meetingData['attendance'] = attendanceSnap.docs.isNotEmpty
            ? attendanceSnap.docs.first.data()
            : null;

        return meetingData;
      }));

      if (mounted) {
        setState(() {
          _meetings = meetings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching course details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_displayTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchMeetings,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _meetings.length,
                    itemBuilder: (context, index) {
                      final meeting = _meetings[index];
                      return _buildMeetingCard(meeting, index + 1);
                    },
                  ),
                ),
    );
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
          SnackBar(
              content: Text('Gagal membuka link. Pastikan format link benar.')),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "Belum ada pertemuan atau tugas",
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting, int index) {
    final assignments =
        (meeting['assignments'] as List).cast<Map<String, dynamic>>();
    final materials =
        (meeting['materials'] as List? ?? []).cast<Map<String, dynamic>>();
    final attendance = meeting['attendance'] as Map<String, dynamic>?;

    // Check if this meeting matches the target meetingId or contains target assignmentId
    bool hasTarget = false;
    if (widget.meetingId != null) {
      hasTarget = meeting['id'] == widget.meetingId;
    } else if (widget.assignmentId != null) {
      hasTarget = assignments.any((a) => a['id'] == widget.assignmentId);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasTarget && widget.meetingId != null
              ? Colors.blue.withOpacity(0.4)
              : Colors.grey.withOpacity(0.1),
          width: hasTarget && widget.meetingId != null ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: hasTarget,
        leading: Icon(
          attendance != null
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: attendance != null ? Colors.green : Colors.grey,
        ),
        title: Text(
          meeting['title'] ?? "Pertemuan $index",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            if (attendance != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  attendance['timestamp'] != null
                      ? "Hadir: ${DateFormat('HH:mm').format((attendance['timestamp'] as Timestamp).toDate())}"
                      : "Hadir",
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ] else ...[
              Text(
                "Belum Absen",
                style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        children: [
          // Materials Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.book_outlined, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Text("Materi Kuliah",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue)),
              ],
            ),
          ),
          if (materials.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text("Belum ada materi untuk pertemuan ini",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...materials.map((m) => _buildMaterialItem(m)),

          const Divider(height: 24, indent: 16, endIndent: 16),

          // Assignments Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Text("Tugas & Evaluasi",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.orange)),
              ],
            ),
          ),
          if (assignments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Tidak ada tugas untuk pertemuan ini",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...assignments
                .map((assignment) => _buildAssignmentItem(assignment)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMaterialItem(Map<String, dynamic> material) {
    return InkWell(
      onTap: () {
        if (material['url'] != null) {
          _launchURL(material['url']);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.link, color: Colors.blue, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                material['name'] ?? "Materi",
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentItem(Map<String, dynamic> assignment) {
    final submission = assignment['submission'];
    final isSubmitted = submission != null;
    final grade = submission?['grade'];
    final category = assignment['category'] ?? 'Tugas';
    final isTarget = widget.assignmentId == assignment['id'];

    DateTime? deadline;
    if (assignment['deadline'] != null && assignment['deadline'] is Timestamp) {
      deadline = (assignment['deadline'] as Timestamp).toDate();
    }

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (grade != null) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = "Nilai: $grade";
    } else if (isSubmitted) {
      statusColor = Colors.blue;
      statusIcon = Icons.access_time_filled;
      statusText = "Menunggu";
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
      statusText = "Belum Ada";
    }

    return InkWell(
      onTap: () => _showSubmissionDialog(assignment),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isTarget
              ? statusColor.withOpacity(0.05)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTarget ? statusColor : Colors.grey.withOpacity(0.2),
            width: isTarget ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  category.toLowerCase().contains('uis')
                      ? Icons.quiz_outlined
                      : Icons.assignment_outlined,
                  color: statusColor,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment['title'] ?? "Tugas",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(category,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ),
                      if (deadline != null)
                        Text(
                          "Exp: ${DateFormat('d MMM', 'id_ID').format(deadline)}",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 10),
                        ),
                    ],
                  ),
                  if (assignment['url'] != null &&
                      assignment['url'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _launchURL(assignment['url']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: statusColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              "Buka Link",
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmissionDialog(Map<String, dynamic> assignment) {
    final submission = assignment['submission'];
    final bool isSubmitted = submission != null;
    final bool isGraded = submission?['grade'] != null;

    if (isGraded) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Tugas Dinilai"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Nilai: ${submission['grade']}",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              const SizedBox(height: 8),
              Text(
                  "Feedback: ${submission['feedback'] ?? 'Tidak ada feedback'}",
                  style: TextStyle(color: Colors.grey[700])),
              const Divider(),
              const SizedBox(height: 8),
              const Text("Jawaban Anda:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              if (submission['content'] != null &&
                  submission['content'].toString().isNotEmpty) ...[
                Text(submission['content'],
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
              ],
              if (submission['link'] != null &&
                  submission['link'].toString().isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => _launchURL(submission['link']),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text("Lihat Link Jawaban Saya"),
                ),
              ] else if (submission['content'] != null &&
                  submission['content'].toString().contains('http')) ...[
                // Fallback for old submissions
                OutlinedButton.icon(
                  onPressed: () {
                    final content = submission['content'] as String;
                    final words = content.split(RegExp(r'\s+'));
                    final url = words.firstWhere((w) => w.startsWith('http'),
                        orElse: () => "");
                    if (url.isNotEmpty) _launchURL(url);
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text("Lihat Jawaban (Link)"),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Tutup")),
          ],
        ),
      );
      return;
    }

    final contentController =
        TextEditingController(text: submission?['content'] ?? "");
    final linkController =
        TextEditingController(text: submission?['link'] ?? "");
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isSubmitted ? "Edit Pengumpulan" : "Kumpulkan Tugas"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(assignment['title'] ?? 'Tugas',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  assignment['description'] ??
                      'Silakan lampirkan jawaban Anda.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: AppTheme.inputDecoration(
                    context, "Jawaban Teks", Icons.description_outlined),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkController,
                decoration: AppTheme.inputDecoration(
                    context, "Link Jawaban (Opsional)", Icons.link),
              ),
              if (assignment['url'] != null &&
                  assignment['url'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _launchURL(assignment['url']),
                  icon: const Icon(Icons.attachment, size: 16),
                  label: const Text("Buka Link Lampiran Tugas",
                      style: TextStyle(fontSize: 12)),
                ),
              ],
              if (isSubmitted &&
                  submission['link'] != null &&
                  submission['link'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _launchURL(submission['link']),
                  icon: const Icon(Icons.assignment_turned_in, size: 16),
                  label: const Text("Cek Link Jawaban Saya",
                      style: TextStyle(fontSize: 12, color: Colors.green)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Batal")),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (contentController.text.trim().isEmpty) return;

                      setDialogState(() => isSaving = true);
                      try {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        final name =
                            FirebaseAuth.instance.currentUser?.displayName;

                        // Path: courses/{courseId}/meetings/{meetingId}/assignments/{assignmentId}/submissions/{studentId}
                        // Need IDs from context... but we only have assignment Map.
                        // Let's find IDs from the _meetings list.
                        String? meetingId;
                        for (var m in _meetings) {
                          final assigns = m['assignments'] as List;
                          if (assigns.any((a) => a['id'] == assignment['id'])) {
                            meetingId = m['id'];
                            break;
                          }
                        }

                        if (meetingId != null && uid != null) {
                          await FirebaseFirestore.instance
                              .collection('courses')
                              .doc(widget.courseId)
                              .collection('meetings')
                              .doc(meetingId)
                              .collection('assignments')
                              .doc(assignment['id'])
                              .collection('submissions')
                              .doc(uid)
                              .set({
                            'content': contentController.text.trim(),
                            'link': linkController.text.trim(),
                            'submittedAt': FieldValue.serverTimestamp(),
                            'studentName': name ?? 'Siswa',
                            'studentId': uid,
                          }, SetOptions(merge: true));

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchMeetings();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Tugas berhasil dikirim!")),
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint("Error submitting assignment: $e");
                      } finally {
                        if (mounted) setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isSubmitted ? "Update" : "Kirim"),
            ),
          ],
        ),
      ),
    );
  }
}
