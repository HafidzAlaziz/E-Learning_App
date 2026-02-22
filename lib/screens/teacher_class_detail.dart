import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:e_learning_app/screens/teacher_attendance_qr.dart';
import 'package:e_learning_app/screens/teacher_assignment_detail.dart';

class TeacherClassDetailScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const TeacherClassDetailScreen({
    super.key,
    required this.courseId,
    required this.courseData,
  });

  @override
  State<TeacherClassDetailScreen> createState() =>
      _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState extends State<TeacherClassDetailScreen> {
  // Mock enrollment count for now, real implementation would query 'enrollments' collection
  int enrollmentCount = 0;
  bool _isGeneratingMeetings = false;

  @override
  void initState() {
    super.initState();
    _fetchEnrollmentCount();
  }

  Future<void> _fetchEnrollmentCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('courseId', isEqualTo: widget.courseId)
          .count()
          .get();

      if (mounted) {
        setState(() => enrollmentCount = snapshot.count ?? 0);
      }
    } catch (e) {
      debugPrint("Error fetching enrollment: $e");
    }
  }

  Future<void> _toggleMeetingStatus(
      String meetingId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('meetings')
          .doc(meetingId)
          .update({'isCompleted': !currentStatus});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
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
          SnackBar(
              content: Text('Gagal membuka link. Pastikan format link benar.')),
        );
      }
    }
  }

  Future<void> _generateSemesterMeetings({bool silent = false}) async {
    if (_isGeneratingMeetings) return;
    _isGeneratingMeetings = true;

    if (!silent) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('meetings');

      for (int i = 1; i <= 16; i++) {
        final docRef = collection.doc();
        batch.set(docRef, {
          'title': 'Pertemuan $i',
          'type': 'Offline',
          'date': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'meetingNumber': i,
        });
      }

      await batch.commit();
      _isGeneratingMeetings = false;
      if (!silent && mounted) Navigator.pop(context); // Close loader
    } catch (e) {
      _isGeneratingMeetings = false;
      if (!silent && mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showAddMeetingDialog() {
    final titleController = TextEditingController();
    String type = 'Offline';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Tambah Pertemuan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: AppTheme.inputDecoration(
                    context, "Judul Pertemuan (mis: Pertemuan 1)", Icons.title),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type,
                decoration: AppTheme.inputDecoration(
                    context, "Tipe Pertemuan", Icons.laptop_chromebook),
                items: ['Online', 'Offline']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setDialogState(() => type = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  // Get current meeting count for ordering
                  final query = await FirebaseFirestore.instance
                      .collection('courses')
                      .doc(widget.courseId)
                      .collection('meetings')
                      .count()
                      .get();

                  final newNumber = (query.count ?? 0) + 1;

                  await FirebaseFirestore.instance
                      .collection('courses')
                      .doc(widget.courseId)
                      .collection('meetings')
                      .add({
                    'title': titleController.text,
                    'type': type,
                    'date': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                    'meetingNumber': newNumber,
                  });
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaterialDialog(String meetingId,
      {String? materialId, Map<String, dynamic>? initialData}) {
    final nameController =
        TextEditingController(text: initialData?['name'] ?? '');
    final urlController =
        TextEditingController(text: initialData?['url'] ?? '');
    bool showErrors = false;
    bool isEditing = materialId != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? "Edit Materi" : "Tambah Materi"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: AppTheme.inputDecoration(
                  context,
                  "Nama Materi",
                  Icons.description,
                ).copyWith(
                  errorText: showErrors && nameController.text.isEmpty
                      ? "Nama materi wajib diisi"
                      : null,
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: AppTheme.inputDecoration(
                  context,
                  "Link URL (GDrive/YouTube)",
                  Icons.link,
                ).copyWith(
                  errorText: showErrors && urlController.text.isEmpty
                      ? "Link URL wajib diisi"
                      : null,
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    urlController.text.isNotEmpty) {
                  final data = {
                    'name': nameController.text,
                    'url': urlController.text,
                    'type': 'link',
                  };

                  final collection = FirebaseFirestore.instance
                      .collection('courses')
                      .doc(widget.courseId)
                      .collection('meetings')
                      .doc(meetingId)
                      .collection('materials');

                  if (isEditing) {
                    await collection.doc(materialId).update(data);
                  } else {
                    await collection.add(data);
                  }
                  if (mounted) Navigator.pop(context);
                } else {
                  setDialogState(() => showErrors = true);
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMeeting(String meetingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Pertemuan?"),
        content: const Text(
            "Semua materi dan tugas di dalamnya akan ikut terhapus."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('meetings')
            .doc(meetingId)
            .delete();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showAssignmentDialog(String meetingId,
      {String? assignmentId, Map<String, dynamic>? initialData}) {
    final titleController =
        TextEditingController(text: initialData?['title'] ?? '');
    final descController =
        TextEditingController(text: initialData?['description'] ?? '');
    final urlController =
        TextEditingController(text: initialData?['url'] ?? '');

    DateTime selectedDeadline = DateTime.now().add(const Duration(days: 7));
    if (initialData != null && initialData['deadline'] != null) {
      if (initialData['deadline'] != null &&
          initialData['deadline'] is Timestamp) {
        selectedDeadline = (initialData['deadline'] as Timestamp).toDate();
      }
    }

    String selectedCategory = initialData?['category'] ?? 'assignment';
    bool showErrors = false;
    bool isEditing = assignmentId != null;

    final categories = [
      {'val': 'assignment', 'label': 'Tugas / PR'},
      {'val': 'quiz', 'label': 'Kuis'},
      {'val': 'uts', 'label': 'UTS (Ujian Tengah Semester)'},
      {'val': 'uas', 'label': 'UAS (Ujian Akhir Semester)'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? "Edit Tugas" : "Buat Tugas / Evaluasi"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true, // Fix for overflow
                  decoration: AppTheme.inputDecoration(
                      context, "Kategori Penilaian", Icons.category),
                  items: categories.map((c) {
                    return DropdownMenuItem(
                      value: c['val'],
                      child: Text(
                        c['label']!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: AppTheme.inputDecoration(
                    context,
                    "Judul",
                    Icons.assignment,
                  ).copyWith(
                    errorText: showErrors && titleController.text.isEmpty
                        ? "Judul wajib diisi"
                        : null,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: AppTheme.inputDecoration(
                    context,
                    "Deskripsi Singkat",
                    Icons.description_outlined,
                  ).copyWith(
                    errorText: showErrors && descController.text.isEmpty
                        ? "Deskripsi wajib diisi"
                        : null,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: AppTheme.inputDecoration(
                    context,
                    "Link Tambahan (Opsional)",
                    Icons.link,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDeadline,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDeadline),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDeadline = DateTime(date.year, date.month,
                              date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 20, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Deadline Pengumpulan",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              Text(
                                "${selectedDeadline.day}/${selectedDeadline.month}/${selectedDeadline.year} - ${selectedDeadline.hour}:${selectedDeadline.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    descController.text.isNotEmpty) {
                  final data = {
                    'title': titleController.text,
                    'description': descController.text,
                    'url': urlController.text.trim(),
                    'category': selectedCategory,

                    'deadline': Timestamp.fromDate(selectedDeadline),
                    'courseId':
                        widget.courseId, // Added for cross-course querying
                    'createdAt': FieldValue.serverTimestamp(),
                  };

                  final collection = FirebaseFirestore.instance
                      .collection('courses')
                      .doc(widget.courseId)
                      .collection('meetings')
                      .doc(meetingId)
                      .collection('assignments');

                  if (isEditing) {
                    // Don't overwrite createdAt on edit
                    data.remove('createdAt');
                    await collection.doc(assignmentId).update(data);
                  } else {
                    await collection.add(data);
                  }
                  if (mounted) Navigator.pop(context);
                } else {
                  setDialogState(() => showErrors = true);
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasGradingConfigured(Map<String, dynamic> data) {
    if (data['gradingScheme'] == null) return false;

    Map<String, dynamic> scheme =
        Map<String, dynamic>.from(data['gradingScheme']);
    int total = (scheme['attendance'] ?? 0) +
        (scheme['assignment'] ?? 0) +
        (scheme['quiz'] ?? 0) +
        (scheme['uts'] ?? 0) +
        (scheme['uas'] ?? 0);

    return total == 100;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .snapshots(),
      builder: (context, courseSnapshot) {
        if (!courseSnapshot.hasData || !courseSnapshot.data!.exists) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final courseDoc = courseSnapshot.data!.data() as Map<String, dynamic>;
        // Keep initial data updated for legacy dialogs if needed
        widget.courseData.addAll(courseDoc);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Row(
              children: [
                Expanded(
                  child: Text(courseDoc['title'] ?? "Detail Kelas",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${courseDoc['sks'] ?? 0} SKS",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_suggest_outlined),
                tooltip: "Atur Bobot Penilaian",
                onPressed: _showGradingConfigDialog,
              ),
            ],
          ),
          // Removed FloatingActionButton per user request
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(context),
                if (!_hasGradingConfigured(courseDoc)) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                          width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Bobot Penilaian Belum Diset",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Silakan atur bobot penilaian untuk kelas ini.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _showGradingConfigDialog,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text(
                            "Atur",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  "Daftar Pertemuan",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('courses')
                      .doc(widget.courseId)
                      .collection('meetings')
                      .orderBy('meetingNumber', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.docs.isEmpty) {
                      // Safety Net: Auto-trigger meeting generation if empty
                      if (!_isGeneratingMeetings) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _generateSemesterMeetings(silent: true);
                        });
                      }
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_month_outlined,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                "Belum ada agenda pertemuan",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => _generateSemesterMeetings(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                                child: const Text(
                                    "Buat Pertemuan 1 Semester (16)"),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildMeetingCard(context, doc.id, data);
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 80), // Space for FAB
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGradingConfigDialog() {
    // Default values if not set
    Map<String, dynamic> gradingScheme =
        widget.courseData['gradingScheme'] != null
            ? Map<String, dynamic>.from(widget.courseData['gradingScheme'])
            : {
                'attendance': 0,
                'assignment': 0,
                'quiz': 0,
                'uts': 0,
                'uas': 0,
              };

    final controllers = {
      'attendance':
          TextEditingController(text: gradingScheme['attendance'].toString()),
      'assignment':
          TextEditingController(text: gradingScheme['assignment'].toString()),
      'quiz': TextEditingController(text: gradingScheme['quiz'].toString()),
      'uts': TextEditingController(text: gradingScheme['uts'].toString()),
      'uas': TextEditingController(text: gradingScheme['uas'].toString()),
    };

    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Pengaturan Bobot Penilaian"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Total bobot harus 100%",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                _buildWeightInput(
                    context, "Kehadiran (%)", controllers['attendance']!),
                _buildWeightInput(
                    context, "Tugas (%)", controllers['assignment']!),
                _buildWeightInput(context, "Kuis (%)", controllers['quiz']!),
                _buildWeightInput(context, "UTS (%)", controllers['uts']!),
                _buildWeightInput(context, "UAS (%)", controllers['uas']!),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(errorMessage!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                int total = 0;
                Map<String, int> newScheme = {};

                try {
                  controllers.forEach((key, controller) {
                    int val = int.tryParse(controller.text) ?? 0;
                    newScheme[key] = val;
                    total += val;
                  });

                  if (total != 100) {
                    setDialogState(() => errorMessage =
                        "Total bobot saat ini: $total%. Harus 100%.");
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection('courses')
                      .doc(widget.courseId)
                      .update({'gradingScheme': newScheme});

                  // Update local state if needed, or rely on parent rebuild
                  widget.courseData['gradingScheme'] = newScheme;

                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text("Pengaturan penilaian berhasil disimpan")),
                  );
                } catch (e) {
                  setDialogState(() => errorMessage = "Error: $e");
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightInput(
      BuildContext context, String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: AppTheme.inputDecoration(context, label, Icons.percent)
            .copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.courseData['category'] ?? 'Umum',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              Text(
                "${widget.courseData['sks'] ?? 0} SKS",
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(widget.courseData['title'] ?? 'Tanpa Judul',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_filled_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                "${widget.courseData['day'] ?? '-'}, ${widget.courseData['startTime'] ?? '-'} - ${widget.courseData['endTime'] ?? '-'}",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.people_alt_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                "$enrollmentCount Mahasiswa Mengambil",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(
      BuildContext context, String meetingId, Map<String, dynamic> data) {
    bool isOnline = data['type'] == 'Online';
    bool isCompleted = data['isCompleted'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: isCompleted ? Colors.grey.shade100 : Theme.of(context).cardColor,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: Border.all(color: Colors.transparent),
        collapsedShape: Border.all(color: Colors.transparent),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.grey
                : (isOnline
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1)),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted
                ? Icons.check_circle_outline
                : (isOnline ? Icons.laptop_chromebook : Icons.people_rounded),
            color: isCompleted
                ? Colors.white
                : (isOnline ? Colors.blue : Colors.green),
            size: 24,
          ),
        ),
        title: Text(
          data['title'] ?? 'Pertemuan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isCompleted ? Colors.grey : null,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          isCompleted
              ? "Kelas Selesai"
              : (isOnline ? "Online Class" : "Offline / Tatap Muka"),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildSectionHeader("Materi Pembelajaran", () {
                  _showMaterialDialog(meetingId);
                }),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('courses')
                      .doc(widget.courseId)
                      .collection('meetings')
                      .doc(meetingId)
                      .collection('materials')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Belum ada materi",
                          style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        final mData = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          onTap: () {
                            if (mData['url'] != null) {
                              _launchURL(mData['url']);
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.link, color: Colors.blue),
                          title: Text(mData['name'] ?? 'Materi'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.open_in_new,
                                  size: 14, color: Colors.blue),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: Colors.blue),
                                onPressed: () {
                                  _showMaterialDialog(meetingId,
                                      materialId: doc.id, initialData: mData);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('courses')
                                      .doc(widget.courseId)
                                      .collection('meetings')
                                      .doc(meetingId)
                                      .collection('materials')
                                      .doc(doc.id)
                                      .delete();
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildSectionHeader("Tugas", () {
                  _showAssignmentDialog(meetingId);
                }),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('courses')
                      .doc(widget.courseId)
                      .collection('meetings')
                      .doc(meetingId)
                      .collection('assignments')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Belum ada tugas",
                          style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        final aData = doc.data() as Map<String, dynamic>;
                        final deadline = aData['deadline'] as Timestamp?;
                        final deadlineStr = deadline != null
                            ? "${deadline.toDate().day}/${deadline.toDate().month} ${deadline.toDate().hour}:${deadline.toDate().minute.toString().padLeft(2, '0')}"
                            : '-';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.assignment_outlined,
                              color: Colors.orange),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  aData['title'] ?? 'Tugas',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (aData['category'] == 'quiz'
                                          ? Colors.orange
                                          : (aData['category'] == 'uts' ||
                                                  aData['category'] == 'uas')
                                              ? Colors.red
                                              : Colors.blue)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (aData['category'] ?? 'Tugas').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: (aData['category'] == 'quiz'
                                        ? Colors.orange
                                        : (aData['category'] == 'uts' ||
                                                aData['category'] == 'uas')
                                            ? Colors.red
                                            : Colors.blue),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Deadline: $deadlineStr\n${aData['description'] ?? '-'}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (aData['url'] != null &&
                                  aData['url'].toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _launchURL(aData['url']),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.blue
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.link,
                                            size: 14, color: Colors.blue),
                                        SizedBox(width: 4),
                                        Text(
                                          "Buka Link",
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 11,
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
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TeacherAssignmentDetailScreen(
                                  courseId: widget.courseId,
                                  meetingId: meetingId,
                                  assignmentId: doc.id,
                                  assignmentData: aData,
                                ),
                              ),
                            );
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: Colors.blue),
                                onPressed: () {
                                  _showAssignmentDialog(meetingId,
                                      assignmentId: doc.id, initialData: aData);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('courses')
                                      .doc(widget.courseId)
                                      .collection('meetings')
                                      .doc(meetingId)
                                      .collection('assignments')
                                      .doc(doc.id)
                                      .delete();
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/teacher-qr',
                            arguments: {
                              'courseId': widget.courseId,
                              'meetingId': meetingId,
                              'courseName': widget.courseData['title'],
                              'meetingName': data['title'],
                            },
                          );
                        },
                        icon: const Icon(Icons.qr_code_rounded, size: 18),
                        label: const Text("QR Code",
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAttendanceList(meetingId),
                        icon: const Icon(Icons.people_alt_rounded, size: 18),
                        label: const Text("Kehadiran",
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _toggleMeetingStatus(meetingId, isCompleted),
                        icon: Icon(
                          isCompleted
                              ? Icons.undo_rounded
                              : Icons.check_circle_outline,
                          size: 18,
                          color: isCompleted ? Colors.orange : Colors.green,
                        ),
                        label: Text(
                          isCompleted ? "Buka" : "Selesai",
                          style: TextStyle(
                            fontSize: 12,
                            color: isCompleted ? Colors.orange : Colors.green,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color:
                                  isCompleted ? Colors.orange : Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAttendanceList(String meetingId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Daftar Kehadiran Siswa",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('attendance')
                        .where('meetingId', isEqualTo: meetingId)
                        .snapshots(),
                    builder: (context, attendanceSnapshot) {
                      if (!attendanceSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('enrollments')
                            .where('courseId', isEqualTo: widget.courseId)
                            .get(),
                        builder: (context, enrollSnapshot) {
                          if (!enrollSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (enrollSnapshot.data!.docs.isEmpty) {
                            return const Center(
                                child: Text(
                                    "Belum ada siswa terdaftar di kelas ini"));
                          }

                          final attendanceDocs = attendanceSnapshot.data!.docs;
                          Map<String, Map<String, dynamic>> attendanceMap = {};
                          for (var doc in attendanceDocs) {
                            attendanceMap[doc['studentId']] =
                                doc.data() as Map<String, dynamic>;
                          }

                          return FutureBuilder<List<Map<String, dynamic>>>(
                            future: _mergeStudentData(
                                enrollSnapshot.data!.docs, attendanceMap),
                            builder: (context, studentsSnapshot) {
                              if (!studentsSnapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final students = studentsSnapshot.data!;
                              final presentCount =
                                  students.where((s) => s['isPresent']).length;

                              return Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    color: Colors.grey.shade50,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Hadir: $presentCount / ${students.length}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      controller: scrollController,
                                      itemCount: students.length,
                                      itemBuilder: (context, index) {
                                        final student = students[index];
                                        final isPresent =
                                            student['isPresent'] as bool;
                                        final time = student['time'] as String?;

                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isPresent
                                                ? Colors.green
                                                    .withValues(alpha: 0.1)
                                                : Colors.red
                                                    .withValues(alpha: 0.1),
                                            child: Icon(
                                              isPresent
                                                  ? Icons.check
                                                  : Icons.close,
                                              color: isPresent
                                                  ? Colors.green
                                                  : Colors.red,
                                              size: 16,
                                            ),
                                          ),
                                          title: Text(
                                              student['name'] ?? 'Nama Siswa',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isPresent
                                                    ? null
                                                    : Colors.grey,
                                              )),
                                          subtitle: Text(
                                            isPresent
                                                ? "Hadir pukul $time"
                                                : "Belum absen",
                                            style: TextStyle(
                                              color: isPresent
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _mergeStudentData(
      List<DocumentSnapshot> enrollmentDocs,
      Map<String, Map<String, dynamic>> attendanceMap) async {
    List<Map<String, dynamic>> results = [];

    for (var doc in enrollmentDocs) {
      final studentId = doc['studentId'];
      final isPresent = attendanceMap.containsKey(studentId);
      String? timeStr;

      if (isPresent) {
        final timestamp = attendanceMap[studentId]!['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final dt = timestamp.toDate();
          timeStr = "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
        }
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();

      final studentName = userDoc.data()?['displayName'] ?? 'Siswa';

      results.add({
        'id': studentId,
        'name': studentName,
        'isPresent': isPresent,
        'time': timeStr,
      });
    }

    return results;
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline,
              color: AppTheme.primaryColor, size: 20),
          tooltip: "Tambah",
        ),
      ],
    );
  }
}
