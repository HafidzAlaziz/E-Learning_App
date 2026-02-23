import 'package:flutter/material.dart';
import 'package:e_learning_app/core/theme.dart';

class AdminAssignTeacherScreen extends StatefulWidget {
  const AdminAssignTeacherScreen({super.key});

  @override
  State<AdminAssignTeacherScreen> createState() =>
      _AdminAssignTeacherScreenState();
}

class _AdminAssignTeacherScreenState extends State<AdminAssignTeacherScreen> {
  String? selectedTeacher;
  String? selectedSubject;
  String? selectedClass;

  final List<String> teachers = [
    "Budi Raharjo, M.Kom",
    "Siti Aminah, S.Pd",
    "Dr. Fauzi Ahmad"
  ];
  final List<String> subjects = [
    "Flutter & Mobile Development",
    "UI/UX Design Masterclass",
    "Database System"
  ];
  final List<String> classes = ["XI-RPL-1", "XI-RPL-2", "XII-SI-1"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Penugasan Guru",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Buat Penugasan Baru",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Hubungkan guru dengan mata pelajaran dan kelas yang sesuai.",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            _buildDropdown(
              label: "Pilih Guru",
              value: selectedTeacher,
              items: teachers,
              onChanged: (val) => setState(() => selectedTeacher = val),
              icon: Icons.person_search_rounded,
            ),
            const SizedBox(height: 20),
            _buildDropdown(
              label: "Pilih Mata Pelajaran",
              value: selectedSubject,
              items: subjects,
              onChanged: (val) => setState(() => selectedSubject = val),
              icon: Icons.book_rounded,
            ),
            const SizedBox(height: 20),
            _buildDropdown(
              label: "Pilih Kelas",
              value: selectedClass,
              items: classes,
              onChanged: (val) => setState(() => selectedClass = val),
              icon: Icons.class_rounded,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (selectedTeacher != null &&
                        selectedSubject != null &&
                        selectedClass != null)
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text("Berhasil menugaskan $selectedTeacher"),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text("Simpan Penugasan"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: const Text("Pilih salah satu"),
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              items: items.map((String item) {
                return DropdownMenuItem(
                  value: item,
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        item,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
