import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:e_learning_app/screens/admin_course_detail.dart';

class AdminCourseManagementScreen extends StatefulWidget {
  final bool isView;
  const AdminCourseManagementScreen({super.key, this.isView = false});

  @override
  State<AdminCourseManagementScreen> createState() =>
      _AdminCourseManagementScreenState();
}

class _AdminCourseManagementScreenState
    extends State<AdminCourseManagementScreen> {
  String? _selectedMajorId;
  String? _selectedMajorName;
  int? _selectedSemester;

  late Stream<QuerySnapshot> _prodiStream;
  late Stream<DocumentSnapshot> _majorDetailStream;
  late Stream<QuerySnapshot> _courseStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    _prodiStream = FirebaseFirestore.instance
        .collection('majors')
        .orderBy('name')
        .snapshots();

    if (_selectedMajorId != null) {
      _majorDetailStream = FirebaseFirestore.instance
          .collection('majors')
          .doc(_selectedMajorId)
          .snapshots();

      _courseStream = FirebaseFirestore.instance
          .collection('courses')
          .where('category', isEqualTo: _selectedMajorName)
          .where('semester', isEqualTo: _selectedSemester)
          .snapshots();
    }
  }

  void _updateMajorSelection(String id, String name) {
    setState(() {
      _selectedMajorId = id;
      _selectedMajorName = name;
      _selectedSemester = null;
      _majorDetailStream =
          FirebaseFirestore.instance.collection('majors').doc(id).snapshots();
      // Course stream will be updated when semester is selected
    });
  }

  void _updateSemesterSelection(int? semester) {
    setState(() {
      _selectedSemester = semester;
      if (semester != null) {
        _courseStream = FirebaseFirestore.instance
            .collection('courses')
            .where('category', isEqualTo: _selectedMajorName)
            .where('semester', isEqualTo: semester)
            .snapshots();
      }
    });
  }

  TimeOfDay _calculateEndTime(TimeOfDay start, int sks) {
    int totalMinutes = start.hour * 60 + start.minute + (sks * 30);
    return TimeOfDay(
        hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
  }

  Future<void> _generateSemesterMeetings(String courseId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
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
    } catch (e) {
      debugPrint('Error generating meetings: $e');
    }
  }

  void _showAddCourseDialog() {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    String? tempCategory = _selectedMajorName;
    int? selectedSemester = _selectedSemester;
    int selectedSKS = 3;
    String selectedDay = 'Senin';
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    String? selectedTeacherId;
    String selectedTeacherName = 'Belum Ditugaskan';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Tambah Mata Kuliah",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogFieldLabel("Informasi Umum"),
                  TextField(
                    controller: titleController,
                    decoration: AppTheme.inputDecoration(
                        context, "Nama Mata Kuliah", Icons.book_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: AppTheme.inputDecoration(context,
                        "Lokasi (Gedung/Ruang)", Icons.location_on_outlined),
                  ),
                  const SizedBox(height: 16),
                  _buildDialogFieldLabel("Jadwal & SKS"),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: selectedSKS,
                          decoration: AppTheme.inputDecoration(
                              context, "SKS", Icons.numbers_rounded),
                          items: [1, 2, 3, 4]
                              .map((sks) => DropdownMenuItem(
                                    value: sks,
                                    child: Text("$sks SKS",
                                        style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedSKS = val;
                                if (startTime != null) {
                                  endTime = _calculateEndTime(
                                      startTime!, selectedSKS);
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedDay,
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
                                        style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedDay = val);
                            }
                          },
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
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimePicker(
                          context,
                          "Selesai",
                          endTime,
                          (t) => setDialogState(() => endTime = t),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDialogFieldLabel("Prodi & Pengajar"),
                  StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('majors')
                          .snapshots(),
                      builder: (context, snapshot) {
                        List<DropdownMenuItem<String>> majorItems = [];
                        if (snapshot.hasData) {
                          majorItems = snapshot.data!.docs.map((doc) {
                            final name = doc['name'] as String;
                            return DropdownMenuItem(
                                value: name, child: Text(name));
                          }).toList();
                        }
                        return DropdownButtonFormField<String>(
                          value: tempCategory,
                          decoration: AppTheme.inputDecoration(
                              context, "Pilih Prodi", Icons.category_outlined),
                          items: majorItems,
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => tempCategory = val);
                            }
                          },
                        );
                      }),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedSemester,
                    decoration: AppTheme.inputDecoration(
                        context, "Semester", Icons.layers_outlined),
                    items: List.generate(8, (i) => i + 1)
                        .map((sem) => DropdownMenuItem(
                            value: sem, child: Text("Semester $sem")))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedSemester = val);
                      }
                    },
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
                          child: Text('Belum Ditugaskan'),
                        ),
                      ];

                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final teacherName =
                              data['displayName'] ?? 'Tidak ada nama';
                          final teacherId = doc.id;
                          teacherItems.add(DropdownMenuItem(
                              value: teacherId, child: Text(teacherName)));
                        }
                      }

                      // Safety check: ensure selectedTeacherId exists in teacherItems
                      final safeValue = teacherItems
                              .any((item) => item.value == selectedTeacherId)
                          ? selectedTeacherId
                          : null;

                      return DropdownButtonFormField<String>(
                        value: safeValue,
                        decoration: AppTheme.inputDecoration(
                            context, "Guru", Icons.person_outlined),
                        items: teacherItems,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedTeacherId = val;
                            if (val == null) {
                              selectedTeacherName = 'Belum Ditugaskan';
                            } else if (snapshot.hasData) {
                              final teacherDoc = snapshot.data!.docs
                                  .firstWhere((doc) => doc.id == val);
                              final data =
                                  teacherDoc.data() as Map<String, dynamic>;
                              selectedTeacherName =
                                  data['displayName'] ?? 'Tidak ada nama';
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
                    locationController.text.isNotEmpty &&
                    tempCategory != null &&
                    startTime != null &&
                    endTime != null) {
                  final docRef = await FirebaseFirestore.instance
                      .collection('courses')
                      .add({
                    'title': titleController.text.trim(),
                    'location': locationController.text.trim(),
                    'category': tempCategory,
                    'semester': selectedSemester,
                    'sks': selectedSKS,
                    'day': selectedDay,
                    'startTime': startTime!.format(context),
                    'endTime': endTime!.format(context),
                    'teacherName': selectedTeacherName,
                    'teacherId': selectedTeacherId,
                    'createdAt': FieldValue.serverTimestamp(),
                    'gradingScheme': {
                      'attendance': 0,
                      'assignment': 0,
                      'quiz': 0,
                      'uts': 0,
                      'uas': 0,
                    },
                  });

                  // Auto-generate 16 meetings
                  await _generateSemesterMeetings(docRef.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Mata kuliah berhasil ditambahkan")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Mohon lengkapi semua data")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.primaryColor)),
    );
  }

  Widget _buildTimePicker(BuildContext context, String label, TimeOfDay? time,
      Function(TimeOfDay) onSelect) {
    return InkWell(
      onTap: () async {
        final selected = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 8, minute: 0),
        );
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
    if (widget.isView) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            if (_selectedMajorId != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18),
                      onPressed: () {
                        if (_selectedSemester != null) {
                          _updateSemesterSelection(null);
                        } else {
                          setState(() {
                            _selectedMajorId = null;
                            _selectedMajorName = null;
                          });
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        _selectedSemester == null
                            ? _selectedMajorName!
                            : "$_selectedMajorName - Sem $_selectedSemester",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildMainContent()),
          ],
        ),
        floatingActionButton: _buildFAB(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
            _selectedMajorName == null
                ? "Manajemen Prodi"
                : (_selectedSemester == null
                    ? _selectedMajorName!
                    : "$_selectedMajorName - Sem $_selectedSemester"),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: _selectedMajorId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_selectedSemester != null) {
                    _updateSemesterSelection(null);
                  } else {
                    setState(() {
                      _selectedMajorId = null;
                      _selectedMajorName = null;
                    });
                  }
                },
              )
            : null,
      ),
      body: _buildMainContent(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: _selectedMajorId == null
          ? _buildProdiList()
          : (_selectedSemester == null
              ? _buildSemesterList()
              : _buildCourseList()),
    );
  }

  Widget? _buildFAB() {
    return _selectedMajorId == null
        ? FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/admin-majors'),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            icon: const Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 8, bottom: 4),
                  child: Icon(Icons.school_rounded, size: 24),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(Icons.add_rounded, size: 16, color: Colors.white),
                ),
              ],
            ),
            label: const Text("Tambah Prodi"),
          )
        : (_selectedSemester == null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: _removeSemester,
                    backgroundColor: Colors.redAccent,
                    elevation: 4,
                    heroTag: 'remove_sem',
                    child: const Icon(Icons.remove, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    onPressed: _addSemester,
                    backgroundColor: AppTheme.primaryColor,
                    elevation: 4,
                    heroTag: 'add_sem',
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              )
            : FloatingActionButton(
                onPressed: _showAddCourseDialog,
                backgroundColor: AppTheme.primaryColor,
                elevation: 4,
                child: const Icon(Icons.add, color: Colors.white),
              ));
  }

  Future<void> _addSemester() async {
    if (_selectedMajorId == null) return;
    try {
      final majorDoc = await FirebaseFirestore.instance
          .collection('majors')
          .doc(_selectedMajorId)
          .get();

      int currentCount = 8; // Default to 8
      if (majorDoc.exists) {
        final data = majorDoc.data() as Map<String, dynamic>;
        currentCount = data['semesterCount'] ?? 8;
      }

      await FirebaseFirestore.instance
          .collection('majors')
          .doc(_selectedMajorId)
          .update({
        'semesterCount': currentCount + 1,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Semester ${currentCount + 1} ditambahkan")),
        );
      }
    } catch (e) {
      debugPrint("Error adding semester: $e");
    }
  }

  Future<void> _removeSemester() async {
    if (_selectedMajorId == null) return;
    try {
      final majorDoc = await FirebaseFirestore.instance
          .collection('majors')
          .doc(_selectedMajorId)
          .get();

      int currentCount = 8;
      if (majorDoc.exists) {
        final data = majorDoc.data() as Map<String, dynamic>;
        currentCount = data['semesterCount'] ?? 8;
      }

      if (currentCount <= 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Minimal harus ada 1 semester")),
          );
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('majors')
          .doc(_selectedMajorId)
          .update({
        'semesterCount': currentCount - 1,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Semester $currentCount dihapus")),
        );
      }
    } catch (e) {
      debugPrint("Error removing semester: $e");
    }
  }

  Widget _buildProdiList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _prodiStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Belum ada data Prodi"));
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final name = doc['name'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.school, color: AppTheme.primaryColor),
                ),
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "${(doc.data() as Map<String, dynamic>?)?['semesterCount'] ?? 8} Semester"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _updateMajorSelection(doc.id, name),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSemesterList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _majorDetailStream,
      builder: (context, snapshot) {
        int semesterCount = 8;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          semesterCount = data['semesterCount'] ?? 8;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: semesterCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (context, index) {
            final semester = index + 1;
            return InkWell(
              onTap: () => _updateSemesterSelection(semester),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        semester.toString(),
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Semester $semester",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('courses')
                          .where('category', isEqualTo: _selectedMajorName)
                          .where('semester', isEqualTo: semester)
                          .snapshots(),
                      builder: (context, courseSnapshot) {
                        if (!courseSnapshot.hasData) {
                          return const Text("...",
                              style:
                                  TextStyle(fontSize: 10, color: Colors.grey));
                        }
                        final docs = courseSnapshot.data!.docs;
                        int totalSks = 0;
                        for (var d in docs) {
                          totalSks += (d['sks'] as int? ?? 0);
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${docs.length} Matkul • $totalSks SKS",
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCourseList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _courseStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text("Tidak ada mata kuliah di $_selectedMajorName"),
              ],
            ),
          );
        }

        final coursesDocs = snapshot.data!.docs;

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: coursesDocs.length,
          itemBuilder: (context, index) {
            final doc = coursesDocs[index];
            final course = doc.data() as Map<String, dynamic>;
            final title = course['title'] ?? 'No Title';
            final teacher = course['teacherName'] ?? 'Belum Ditugaskan';
            final location = course['location'] ?? 'Lokasi tidak diset';
            final sks = course['sks'] ?? 0;
            final day = course['day'] ?? '-';
            final startTime = course['startTime'] ?? '';
            final endTime = course['endTime'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.book_rounded,
                      color: AppTheme.primaryColor),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "$sks SKS",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Lokasi: $location",
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7)),
                    ),
                    Text(
                      "$day, $startTime - $endTime",
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              course['teacherId'] == null
                                  ? Icons.warning_amber_rounded
                                  : Icons.person_outline_rounded,
                              size: 14,
                              color: course['teacherId'] == null
                                  ? Colors.red
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Guru: $teacher",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: course['teacherId'] == null
                                    ? Colors.red
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "Semester ${course['semester'] ?? '-'}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminCourseDetailScreen(
                        courseId: doc.id,
                        courseData: course,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
