import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_learning_app/core/theme.dart';

class AdminCourseDetailScreen extends StatelessWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const AdminCourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseData,
  });

  TimeOfDay _calculateEndTime(TimeOfDay start, int sks) {
    int totalMinutes = start.hour * 60 + start.minute + (sks * 30);
    return TimeOfDay(
        hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
  }

  Future<void> _deleteCourse(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Mata Kuliah"),
        content:
            const Text("Apakah Anda yakin ingin menghapus mata kuliah ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .delete();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mata kuliah berhasil dihapus")),
        );
      }
    }
  }

  void _showEditCourseDialog(BuildContext context, Map<String, dynamic> data) {
    final titleController = TextEditingController(text: data['title']);
    final codeController =
        TextEditingController(text: data['courseCode']); // Added codeController
    final locationController = TextEditingController(text: data['location']);
    int selectedSKS = data['sks'] ?? 3;
    String selectedDay = data['day'] ?? 'Senin';
    String tempCategory = data['category'] ?? 'Teknik Informatika';
    String? selectedTeacherId = data['teacherId'];
    String selectedTeacherName = data['teacherName'] ?? 'Belum Ditugaskan';

    // Parse time strings back to TimeOfDay
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    try {
      if (data['startTime'] != null) {
        final parts = data['startTime'].split(":");
        startTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (data['endTime'] != null) {
        final parts = data['endTime'].split(":");
        endTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Edit Mata Kuliah",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: AppTheme.inputDecoration(
                        context, "Kode Mata Kuliah", Icons.vpn_key_outlined),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: AppTheme.inputDecoration(
                        context, "Nama Mata Kuliah", Icons.book_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: AppTheme.inputDecoration(
                        context, "Lokasi", Icons.location_on_outlined),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: selectedSKS,
                          decoration: AppTheme.inputDecoration(
                              context, "SKS", Icons.numbers_rounded),
                          items: [1, 2, 3, 4]
                              .map((sks) => DropdownMenuItem(
                                  value: sks,
                                  child: Text("$sks SKS",
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) => setDialogState(() {
                            selectedSKS = val!;
                            if (startTime != null) {
                              endTime =
                                  _calculateEndTime(startTime!, selectedSKS);
                            }
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedDay,
                          decoration: AppTheme.inputDecoration(
                              context, "Hari", Icons.calendar_today_rounded),
                          items: [
                            'Senin',
                            'Selasa',
                            'Rabu',
                            'Kamis',
                            'Jumat',
                            'Sabtu'
                          ]
                              .map((day) => DropdownMenuItem(
                                  value: day,
                                  child: Text(day,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) =>
                              setDialogState(() => selectedDay = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _buildTimePicker(
                              context,
                              "Mulai",
                              startTime,
                              (t) => setDialogState(() {
                                    startTime = t;
                                    endTime = _calculateEndTime(t, selectedSKS);
                                  }))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildTimePicker(context, "Selesai", endTime,
                              (t) => setDialogState(() => endTime = t))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSectionTitle(context, "Kategori & Pengajar",
                      small: true),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: tempCategory,
                    decoration: AppTheme.inputDecoration(
                        context, "Kategori", Icons.category_rounded),
                    items: ['Teknik Informatika', 'Sistem Informasi']
                        .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat,
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => tempCategory = val!),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'teacher')
                        .snapshots(),
                    builder: (context, snapshot) {
                      List<DropdownMenuItem<String>> teacherItems = [
                        const DropdownMenuItem(
                            value: null,
                            child: Text('Belum Ditugaskan',
                                style: TextStyle(fontSize: 13))),
                      ];
                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          final tData = doc.data() as Map<String, dynamic>;
                          teacherItems.add(DropdownMenuItem(
                              value: doc.id,
                              child: Text(tData['displayName'] ?? 'No Name',
                                  style: const TextStyle(fontSize: 13))));
                        }
                      }
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedTeacherId,
                        decoration: AppTheme.inputDecoration(
                            context, "Guru Pengajar", Icons.person_rounded),
                        items: teacherItems,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedTeacherId = val;
                            if (val == null) {
                              selectedTeacherName = 'Belum Ditugaskan';
                            } else if (snapshot.hasData) {
                              final teacherDoc = snapshot.data!.docs
                                  .firstWhere((doc) => doc.id == val);
                              final tData =
                                  teacherDoc.data() as Map<String, dynamic>;
                              selectedTeacherName =
                                  tData['displayName'] ?? 'Tidak ada nama';
                            }
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text("Batal", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    startTime != null &&
                    endTime != null) {
                  await FirebaseFirestore.instance
                      .collection('courses')
                      .doc(courseId)
                      .update({
                    'courseCode': codeController.text.toUpperCase().trim(),
                    'title': titleController.text.trim(),
                    'location': locationController.text.trim(),
                    'category': tempCategory,
                    'sks': selectedSKS,
                    'day': selectedDay,
                    'startTime': startTime!.format(context),
                    'endTime': endTime!.format(context),
                    'teacherId': selectedTeacherId,
                    'teacherName': selectedTeacherName,
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Mata kuliah berhasil diperbarui")));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor),
              child: const Text("Simpan Perubahan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context, String label, TimeOfDay? time,
      Function(TimeOfDay) onSelect) {
    return InkWell(
      onTap: () async {
        final selected = await showTimePicker(
            context: context,
            initialTime: time ?? const TimeOfDay(hour: 8, minute: 0));
        if (selected != null) onSelect(selected);
      },
      child: InputDecorator(
        decoration:
            AppTheme.inputDecoration(context, label, Icons.access_time_rounded),
        child: Text(time?.format(context) ?? "--:--",
            style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text("Mata kuliah tidak ditemukan")));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final title = data['title'] ?? 'No Title';
        final courseCode = data['courseCode'] ?? 'CS101'; // Added courseCode
        final category = data['category'] ?? 'General';
        final teacher = data['teacherName'] ?? 'Belum Ditugaskan';
        final location = data['location'] ?? '-';
        final sks = data['sks'] ?? 0;
        final day = data['day'] ?? '-';
        final startTime = data['startTime'] ?? '';
        final endTime = data['endTime'] ?? '';

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Row(
              children: [
                const Expanded(
                  child: Text("Detail Mata Kuliah",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$sks SKS",
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
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditCourseDialog(context, data),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteCourse(context),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, Color(0xFF0D6E5D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                              "$category | $courseCode", // Added courseCode to badge
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        const SizedBox(height: 16),
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Text(location,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, "Informasi Jadwal"),
                  _buildInfoCard(context, [
                    _buildInfoRow(
                        context, Icons.calendar_today_rounded, "Hari", day),
                    _buildInfoRow(context, Icons.access_time_rounded, "Waktu",
                        "$startTime - $endTime"),
                    _buildInfoRow(context, Icons.numbers_rounded, "Beban Studi",
                        "$sks SKS"),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, "Pengajar"),
                  _buildInfoCard(context, [
                    _buildInfoRow(
                      context,
                      Icons.person_outline_rounded,
                      "Nama Guru",
                      teacher,
                      isWarning: teacher == 'Belum Ditugaskan',
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title,
      {bool small = false}) {
    return Padding(
      padding:
          EdgeInsets.only(left: 4, bottom: small ? 8 : 12, top: small ? 8 : 0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: small ? 14 : 18,
          fontWeight: FontWeight.bold,
          color: small
              ? AppTheme.primaryColor
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children
            .expand((w) => [
                  w,
                  if (w != children.last)
                    const Divider(height: 24, thickness: 0.5)
                ])
            .toList(),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value,
      {bool isWarning = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isWarning
                ? Colors.red.withValues(alpha: 0.1)
                : AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isWarning ? Icons.warning_amber_rounded : icon,
            color: isWarning ? Colors.red : AppTheme.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12)),
              Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isWarning
                          ? Colors.red
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (isWarning) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.close_rounded,
                        size: 16, color: Colors.red),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
