import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:e_learning_app/core/calendar_utils.dart';

class StudentHomeView extends StatefulWidget {
  final Function(int, {DateTime? initialDate}) onTabChange;

  const StudentHomeView({
    super.key,
    required this.onTabChange,
  });

  @override
  State<StudentHomeView> createState() => _StudentHomeViewState();
}

class _StudentHomeViewState extends State<StudentHomeView>
    with SingleTickerProviderStateMixin {
  int _courseCount = 0;
  int _totalSks = 0;
  double _ipk = 0.0;
  double _ips = 0.0;
  int _latestSemester = 1;
  String _major = "Mencari data...";
  String _currentTime = "";
  String _currentDate = "";
  String _nextClassMessage = "Mencari jadwal berikutnya...";
  DocumentSnapshot? _nextClassDoc;
  bool _isMajorValid = false;
  List<String> _enrolledCourseIds = [];
  late Timer _timer;
  Stream<QuerySnapshot>? _assignmentsStream;
  Stream<QuerySnapshot>? _gradesStream;
  Stream<QuerySnapshot>? _eventsStream;
  Map<String, String> _enrolledCourseNames = {};
  late AnimationController _bellAnimationController;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _fetchNextClass();
    _fetchUserInfo();
    _calculateIPK();
    _initStreams();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
      // Refresh next class info every minute
      if (DateTime.now().second == 0) {
        _fetchNextClass();
      }
    });

    _bellAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _initStreams() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _assignmentsStream =
        FirebaseFirestore.instance.collectionGroup('assignments').snapshots();

    _gradesStream = FirebaseFirestore.instance
        .collectionGroup('submissions')
        .where('studentId', isEqualTo: uid)
        .snapshots();

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    _eventsStream = FirebaseFirestore.instance
        .collection('academic_events')
        .where('endDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .orderBy('endDate')
        .limit(10)
        .snapshots();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer.cancel();
    _bellAnimationController.dispose();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm:ss').format(now);
        _currentDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
      });
    }
  }

  Future<void> _fetchUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Run both queries in parallel for faster loading
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance.collection('majors').get(),
      ]);

      final doc = results[0] as DocumentSnapshot;
      final majorsSnap = results[1] as QuerySnapshot;
      final major = doc.data() != null
          ? (doc.data() as Map<String, dynamic>)['major']
          : null;
      final majorNames =
          majorsSnap.docs.map((doc) => doc['name'] as String).toList();

      if (mounted) {
        setState(() {
          _major = major ?? "Belum memilih Prodi";
          _isMajorValid = majorNames.contains(_major);
        });

        if (!_isMajorValid) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _showEditProdiDialog(isMandatory: true);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user info: $e");
    }
  }

  Future<void> _fetchNextClass() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final now = DateTime.now();

      // 1. Get Enrollments (verified later)
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .get();

      final myCourseIds = enrollmentsSnapshot.docs
          .map((doc) => doc['courseId'] as String)
          .toList();

      if (mounted) {
        setState(() {
          _enrolledCourseIds = myCourseIds;
        });
      }

      if (myCourseIds.isEmpty) {
        if (mounted) {
          setState(() {
            _nextClassMessage = "Belum ada kursus yang diambil";
            _courseCount = 0;
            _totalSks = 0;
            _nextClassDoc = null;
          });
        }
        return;
      }

      // 3. Get All Classes from those Courses
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where(FieldPath.documentId, whereIn: myCourseIds)
          .get();

      int totalSksCount = 0;
      Map<String, String> courseNamesMap = {};
      for (var doc in coursesSnapshot.docs) {
        courseNamesMap[doc.id] = doc['title'] as String;
        totalSksCount += (doc['sks'] as num? ?? 0).toInt();
      }

      if (mounted) {
        setState(() {
          _courseCount = coursesSnapshot.docs.length;
          _enrolledCourseNames = courseNamesMap;
          _totalSks = totalSksCount;
          _enrolledCourseIds = coursesSnapshot.docs.map((d) => d.id).toList();
        });
      }

      if (coursesSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _nextClassMessage = "Tidak ada jadwal kelas";
            _nextClassDoc = null;
          });
        }
        return;
      }
      DocumentSnapshot? nextClass;
      int minDiffMinutes = 999999;

      final dayToIdx = {
        'Senin': 1,
        'Selasa': 2,
        'Rabu': 3,
        'Kamis': 4,
        'Jumat': 5,
        'Sabtu': 6,
        'Minggu': 7
      };

      for (var doc in coursesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dayStr = data['day'] as String;
        final startTime = data['startTime'] as String;
        final targetDayIdx = dayToIdx[dayStr] ?? 1;

        DateTime? classTimeNormalized;
        try {
          final parts = startTime.split(':');
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1].split(' ')[0]);
          classTimeNormalized = DateTime(now.year, now.month, now.day, h, m);

          if (startTime.toUpperCase().contains('PM') && h < 12) {
            classTimeNormalized =
                classTimeNormalized.add(const Duration(hours: 12));
          } else if (startTime.toUpperCase().contains('AM') && h == 12) {
            classTimeNormalized =
                classTimeNormalized.subtract(const Duration(hours: 12));
          }
        } catch (_) {
          classTimeNormalized = DateTime(now.year, now.month, now.day, 0, 0);
        }

        DateTime classDateTime = classTimeNormalized;

        int daysUntil = targetDayIdx - now.weekday;
        if (daysUntil < 0 || (daysUntil == 0 && classDateTime.isBefore(now))) {
          daysUntil += 7;
        }

        classDateTime = classDateTime.add(Duration(days: daysUntil));
        final diff = classDateTime.difference(now).inMinutes;

        if (diff >= 0 && diff < minDiffMinutes) {
          minDiffMinutes = diff;
          nextClass = doc;
        }
      }

      if (mounted) {
        setState(() {
          _nextClassDoc = nextClass;
          if (nextClass != null) {
            final data = nextClass.data() as Map<String, dynamic>;
            final dayStr = data['day'] as String;
            final startTime = data['startTime'] as String;

            if (minDiffMinutes < 60) {
              _nextClassMessage =
                  "$minDiffMinutes menit lagi kelas ${data['title']}";
            } else if (minDiffMinutes < 24 * 60 &&
                DateTime.now().weekday == dayToIdx[dayStr]) {
              final h = minDiffMinutes ~/ 60;
              final m = minDiffMinutes % 60;
              _nextClassMessage = "$h jam $m menit lagi kelas ${data['title']}";
            } else {
              final nowDay = DateTime(now.year, now.month, now.day);
              final classDay = nowDay.add(Duration(
                  days: (dayToIdx[dayStr]! - now.weekday + 7) % 7 == 0 &&
                          minDiffMinutes > 1440
                      ? 7
                      : (dayToIdx[dayStr]! - now.weekday + 7) % 7));

              final diffDays = classDay.difference(nowDay).inDays;

              String dayDisplay;
              if (diffDays == 1) {
                dayDisplay = "Besok";
              } else if (diffDays == 0) {
                dayDisplay = "Hari ini";
              } else {
                dayDisplay = dayStr;
              }

              _nextClassMessage =
                  "$dayDisplay pukul $startTime kelas ${data['title']}";
            }
          } else {
            _nextClassMessage = "Belum ada jadwal tersedia";
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching next class: $e");
    }
  }

  Future<void> _calculateIPK() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final enrollmentsSnap = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .get();

      if (enrollmentsSnap.docs.isEmpty) return;

      final courseIds =
          enrollmentsSnap.docs.map((d) => d['courseId'] as String).toList();

      // Fetch all course docs and submissions in parallel (not sequential)
      final futures = await Future.wait([
        // Fetch all courses at once (chunked if > 10)
        FirebaseFirestore.instance
            .collection('courses')
            .where(FieldPath.documentId, whereIn: courseIds.take(10).toList())
            .get(),
        // Fetch all submissions for this student at once
        FirebaseFirestore.instance
            .collectionGroup('submissions')
            .where('studentId', isEqualTo: uid)
            .get(),
      ]);

      final coursesSnap = futures[0] as QuerySnapshot;
      final allSubmissionsSnap = futures[1] as QuerySnapshot;

      // Separate IPK (all semesters) and IPS (latest semester only)
      // Build a map of courseId -> semester
      final Map<String, int> courseSemesterMap = {};
      for (var doc in coursesSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        courseSemesterMap[doc.id] = (data['semester'] as num?)?.toInt() ?? 1;
      }

      // Find the latest semester
      int latestSem = 1;
      if (courseSemesterMap.isNotEmpty) {
        latestSem = courseSemesterMap.values.reduce((a, b) => a > b ? a : b);
      }

      // IPS = only courses in latest semester
      double ipsPoints = 0;
      int ipsSks = 0;
      double ipkPoints = 0;
      int ipkSks = 0;

      // Re-calculate with semester split
      // We'll re-use collected per-course data from the parallel loop above
      // (totalPoints / totalSksCalc is IPK, already calculated above)
      // For IPS we do a lightweight re-scan of courseSemesterMap
      // Since we aggregated into totalPoints/totalSksCalc, we need to
      // accumulate separately per-semester. Use a fresh pass:
      final Map<String, double> courseGrades = {};
      final Map<String, int> courseSks = {};

      for (var doc in coursesSnap.docs) {
        final cData = doc.data() as Map<String, dynamic>;
        final cSks = (cData['sks'] as num? ?? 0).toInt();
        courseSks[doc.id] = cSks;

        // Find final grade for this course from submissions
        Map<String, double> scheme = {
          'attendance': 10.0,
          'assignment': 20.0,
          'quiz': 20.0,
          'uts': 25.0,
          'uas': 25.0,
        };
        if (cData.containsKey('gradingScheme')) {
          final s = cData['gradingScheme'] as Map<String, dynamic>;
          scheme = s.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }

        // Attendance
        final attSnap = await FirebaseFirestore.instance
            .collection('attendance')
            .where('courseId', isEqualTo: doc.id)
            .where('studentId', isEqualTo: uid)
            .get();
        final meetSnap = await FirebaseFirestore.instance
            .collection('courses')
            .doc(doc.id)
            .collection('meetings')
            .get();
        final pct = meetSnap.docs.isNotEmpty
            ? (attSnap.docs.length / meetSnap.docs.length * 100)
                .clamp(0.0, 100.0)
            : 0.0;

        Map<String, List<double>> sc = {
          'assignment': [],
          'quiz': [],
          'uts': [],
          'uas': []
        };
        for (var sub in allSubmissionsSnap.docs) {
          if (!sub.reference.path.contains('courses/${doc.id}')) continue;
          final sd = sub.data() as Map<String, dynamic>;
          if (sd['grade'] == null) continue;
          final ar = sub.reference.parent.parent;
          if (ar == null) continue;
          final ad = await ar.get();
          final cat = ad.data()?['category'] ?? 'assignment';
          if (sc.containsKey(cat)) {
            sc[cat]!.add(sd['grade']);
          }
        }

        double avg(String k) {
          final l = sc[k];
          return (l == null || l.isEmpty)
              ? 0.0
              : l.reduce((a, b) => a + b) / l.length;
        }

        final fg = (pct * scheme['attendance']! / 100) +
            (avg('assignment') * scheme['assignment']! / 100) +
            (avg('quiz') * scheme['quiz']! / 100) +
            (avg('uts') * scheme['uts']! / 100) +
            (avg('uas') * scheme['uas']! / 100);

        double mutu = 0.0;
        if (fg >= 85) {
          mutu = 4.0;
        } else if (fg >= 75) {
          mutu = 3.0;
        } else if (fg >= 65) {
          mutu = 2.0;
        } else if (fg >= 50) {
          mutu = 1.0;
        }

        courseGrades[doc.id] = mutu;
        ipkPoints += mutu * cSks;
        ipkSks += cSks;

        if ((courseSemesterMap[doc.id] ?? 1) == latestSem) {
          ipsPoints += mutu * cSks;
          ipsSks += cSks;
        }
      }

      if (mounted) {
        setState(() {
          _ipk = ipkSks > 0 ? ipkPoints / ipkSks : 0.0;
          _ips = ipsSks > 0 ? ipsPoints / ipsSks : 0.0;
          _latestSemester = latestSem;
        });
      }
    } catch (e) {
      debugPrint("Error calculating IPK: $e");
    }
  }

  /// Navigates to course detail and auto-opens the most relevant meeting for today.
  Future<void> _navigateToTodayMeeting(
      String courseId, String courseTitle) async {
    // Show loading snackbar
    if (!mounted) return;
    final nav = Navigator.of(context);

    String? targetMeetingId;
    try {
      // Query all meetings ordered by meetingNumber
      final meetingsSnap = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .collection('meetings')
          .orderBy('meetingNumber', descending: false)
          .get();

      if (meetingsSnap.docs.isNotEmpty) {
        final today = DateTime.now();
        // Try to find a meeting that has a date matching today
        for (var doc in meetingsSnap.docs) {
          final data = doc.data();
          // Check 'date' or 'startDate' fields
          Timestamp? ts =
              data['date'] as Timestamp? ?? data['startDate'] as Timestamp?;
          if (ts != null) {
            final meetingDate = ts.toDate();
            if (meetingDate.year == today.year &&
                meetingDate.month == today.month &&
                meetingDate.day == today.day) {
              targetMeetingId = doc.id;
              break;
            }
          }
        }

        targetMeetingId ??= meetingsSnap.docs.last.id;
      }
    } catch (e) {
      debugPrint('Error fetching meeting for today: $e');
    }

    if (!mounted) return;
    nav.pushNamed(
      '/student-course-detail',
      arguments: {
        'courseId': courseId,
        'courseTitle': courseTitle,
        'meetingId': targetMeetingId,
      },
    );
  }

  Future<void> _showEditProdiDialog({bool isMandatory = false}) {
    String? tempSelectedProdi = _isMajorValid ? _major : null;
    bool isSaving = false;

    return showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) => PopScope(
        canPop: !isMandatory,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
                isMandatory ? "Pilih Program Studi" : "Ganti Program Studi",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMandatory)
                  const Text(
                    "Silakan pilih program studi Anda untuk dapat menggunakan aplikasi.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "PERINGATAN: Mengubah Prodi akan mereset seluruh data kehadiran, nilai, dan kursus yang sudah diambil.",
                            style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                const Text("Pilih Prodi Baru:",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('majors')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    final majorNames =
                        docs.map((doc) => doc['name'] as String).toList();

                    if (tempSelectedProdi != null &&
                        !majorNames.contains(tempSelectedProdi)) {
                      tempSelectedProdi = null;
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: tempSelectedProdi,
                      isExpanded: true,
                      decoration: AppTheme.inputDecoration(
                          context, "Pilih Prodi", Icons.school_outlined),
                      items: majorNames.map((name) {
                        return DropdownMenuItem(value: name, child: Text(name));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => tempSelectedProdi = val);
                      },
                    );
                  },
                ),
              ],
            ),
            actions: [
              if (!isMandatory)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text("Batal", style: TextStyle(color: Colors.grey)),
                ),
              ElevatedButton(
                onPressed: isSaving ||
                        tempSelectedProdi == null ||
                        tempSelectedProdi == (_isMajorValid ? _major : "")
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        try {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({'major': tempSelectedProdi});

                            if (!isMandatory) {
                              final enrollments = await FirebaseFirestore
                                  .instance
                                  .collection('enrollments')
                                  .where('studentId', isEqualTo: uid)
                                  .get();

                              final batch = FirebaseFirestore.instance.batch();
                              for (var doc in enrollments.docs) {
                                batch.delete(doc.reference);
                              }
                              await batch.commit();
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              _fetchUserInfo();
                              _fetchNextClass();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(isMandatory
                                          ? "Prodi berhasil dipilih."
                                          : "Prodi berhasil diubah. Data kursus telah direset.")),
                                );
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint("Error updating major: $e");
                        } finally {
                          if (mounted) setDialogState(() => isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isMandatory ? "Simpan" : "Ganti & Reset"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Clock & Date Card (Green Gradient)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF004D40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004D40).withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _currentTime,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentDate,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () {
                    if (_nextClassDoc != null) {
                      final data =
                          _nextClassDoc!.data() as Map<String, dynamic>;
                      _navigateToTodayMeeting(
                          _nextClassDoc!.id, data['title'] ?? '');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8F00), // Solid Amber/Orange
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8F00).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Bell Icon
                        AnimatedBuilder(
                          animation: _bellAnimationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _bellAnimationController.value * 0.2 - 0.1,
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _nextClassMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Statistics Row
          Column(
            children: [
              Row(
                children: [
                  // Left Card: Kursus & SKS
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTabChange(1), // Go to Daftar MK
                      child: _buildStatCard(
                        icon: Icons.book_rounded,
                        value: "$_courseCount",
                        label: "Kursus",
                        badge: "$_totalSks SKS",
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right Card: Prodi
                  Expanded(
                    child: _buildMajorCard(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // IPK Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTabChange(3), // Go to Nilai
                      child: _buildStatCard(
                        icon: Icons.school_rounded,
                        value: _ipk.toStringAsFixed(2),
                        label: "IPK Kuliah",
                        badge: "IPK",
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // IPS Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTabChange(3), // Go to Nilai
                      child: _buildStatCard(
                        icon: Icons.trending_up_rounded,
                        value: _ips.toStringAsFixed(2),
                        label: "IPS Sem. $_latestSemester",
                        badge: "IPS",
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 3. Important Info
          _buildImportantInfoSection(),
          const SizedBox(height: 100), // Space for FAB/BottomBar
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required String badge,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMajorCard() {
    return GestureDetector(
      onTap: () => _showEditProdiDialog(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.orange, size: 20),
                ),
                const Icon(Icons.edit_rounded, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _major,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              "Program Studi",
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportantInfoSection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('enrollments')
            .where('studentId', isEqualTo: uid)
            .snapshots(),
        builder: (context, enrollmentSnap) {
          final enrolledCourseIds = enrollmentSnap.data?.docs
                  .map((d) => d['courseId'] as String)
                  .toList() ??
              [];

          return StreamBuilder<QuerySnapshot>(
              stream: _assignmentsStream,
              builder: (context, assignmentSnap) {
                return StreamBuilder<QuerySnapshot>(
                    stream: _eventsStream,
                    builder: (context, eventSnap) {
                      return StreamBuilder<QuerySnapshot>(
                          stream: _gradesStream,
                          builder: (context, gradeSnap) {
                            final today = DateTime.now();
                            final startOfToday =
                                DateTime(today.year, today.month, today.day);

                            // 2. Today's Classes
                            final currentDay = DateFormat('EEEE').format(today);
                            final daysId = {
                              'Monday': 'Senin',
                              'Tuesday': 'Selasa',
                              'Wednesday': 'Rabu',
                              'Thursday': 'Kamis',
                              'Friday': 'Jumat',
                              'Saturday': 'Sabtu',
                              'Sunday': 'Minggu',
                            };
                            final todayId = daysId[currentDay];

                            return StreamBuilder<QuerySnapshot>(
                                stream: enrolledCourseIds.isEmpty
                                    ? null
                                    : FirebaseFirestore.instance
                                        .collection('courses')
                                        .where(FieldPath.documentId,
                                            whereIn: enrolledCourseIds
                                                .take(30)
                                                .toList())
                                        .where('day', isEqualTo: todayId)
                                        .snapshots(),
                                builder: (context, courseSnap) {
                                  List<Map<String, dynamic>> allItems = [];

                                  // 1. Local Holidays
                                  for (var h in [
                                    ...IndonesiaHolidays.getEventsForDay(today),
                                    ...IndonesiaHolidays.getEventsForDay(
                                        today.add(const Duration(days: 1))),
                                  ]) {
                                    allItems.add({
                                      'title': h['title'],
                                      'subtitle': h['description'],
                                      'icon': Icons.calendar_today_rounded,
                                      'color': Colors.red,
                                      'date': startOfToday,
                                      'type': 'holiday',
                                      'onTap': () => widget.onTabChange(4),
                                    });
                                  }
                                  if (courseSnap.hasData) {
                                    for (var doc in courseSnap.data!.docs) {
                                      if (enrolledCourseIds.contains(doc.id)) {
                                        final cId = doc.id;
                                        final cTitle =
                                            doc['title'] as String? ?? '';
                                        allItems.add({
                                          'title': "Jadwal Hari Ini: $cTitle",
                                          'label': 'Jadwal Kelas',
                                          'subtitle':
                                              "Pukul ${doc['startTime']}",
                                          'icon': Icons.calendar_today_rounded,
                                          'color': Colors.blue,
                                          'date': startOfToday,
                                          'type': 'class',
                                          'onTap': () =>
                                              _navigateToTodayMeeting(
                                                  cId, cTitle),
                                        });
                                      }
                                    }
                                  }

                                  // 3. Assignments with Submission Status
                                  Map<String, Map<String, dynamic>>
                                      submissionMap = {};
                                  if (gradeSnap.hasData) {
                                    for (var doc in gradeSnap.data!.docs) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      // submission doc ID is the assignment ID?
                                      // Actually, sub-collection path is .../assignments/{assignmentId}/submissions/{studentId}
                                      // collectionGroup('submissions') will give us the doc.
                                      // We need to know which assignment this submission belongs to.
                                      // Let's assume the assignmentId is stored in the submission document or can be extracted from path.
                                      final pathParts =
                                          doc.reference.path.split('/');
                                      if (pathParts.length >= 6) {
                                        final assignmentId = pathParts[5];
                                        submissionMap[assignmentId] = data;
                                      }
                                    }
                                  }

                                  if (assignmentSnap.hasData) {
                                    for (var doc in assignmentSnap.data!.docs) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;

                                      final deadlineTs =
                                          data['deadline'] as Timestamp?;
                                      if (deadlineTs == null) continue;
                                      final deadline = deadlineTs.toDate();

                                      // Only show if not deadline has passed or if it's already graded/submitted
                                      final submission = submissionMap[doc.id];
                                      final isSubmitted = submission != null;
                                      final isGraded = submission != null &&
                                          submission['grade'] != null;

                                      if (!isSubmitted &&
                                          deadline.isBefore(startOfToday))
                                        continue;

                                      bool isMine = false;
                                      if (data['courseId'] != null) {
                                        isMine = enrolledCourseIds
                                            .contains(data['courseId']);
                                      } else {
                                        final pathParts =
                                            doc.reference.path.split('/');
                                        if (pathParts.length > 1) {
                                          isMine = enrolledCourseIds
                                              .contains(pathParts[1]);
                                        }
                                      }

                                      if (!isMine ||
                                          !_enrolledCourseIds.contains(
                                              data['courseId'])) continue;

                                      String title =
                                          data['title'] ?? 'Tugas Baru';
                                      String subtitle = "";
                                      IconData icon =
                                          Icons.assignment_late_rounded;
                                      Color color = Colors.orange;

                                      if (isGraded) {
                                        title =
                                            "Tugas Dinilai: ${data['title']}";
                                        subtitle =
                                            "Nilai Anda: ${submission['grade']}. Cek detail di menu Nilai.";
                                        icon = Icons.grade_rounded;
                                        color = Colors.green;
                                      } else if (isSubmitted) {
                                        title =
                                            "Tugas Terkirim: ${data['title']}";
                                        subtitle =
                                            "Berhasil dikirim, menunggu nilai dari guru.";
                                        icon =
                                            Icons.assignment_turned_in_rounded;
                                        color = Colors.blue;
                                      } else {
                                        final diff = deadline.difference(today);
                                        final timeLeft = diff.inDays > 0
                                            ? "${diff.inDays} hari lagi"
                                            : "${diff.inHours % 24} jam lagi";
                                        subtitle =
                                            "Deadline: ${DateFormat('d MMM, HH:mm').format(deadline)} ($timeLeft)";
                                      }

                                      allItems.add({
                                        'title': title,
                                        'label': 'Tugas Saya',
                                        'subtitle': subtitle,
                                        'icon': icon,
                                        'color': color,
                                        'date': isSubmitted
                                            ? (submission['submittedAt']
                                                        as Timestamp? ??
                                                    Timestamp.now())
                                                .toDate()
                                            : deadline,
                                        'type': isGraded
                                            ? 'grade'
                                            : (isSubmitted
                                                ? 'submission'
                                                : 'assignment'),
                                        'onTap': () {
                                          final courseId = data['courseId'] ??
                                              (doc.reference.path
                                                          .split('/')
                                                          .length >
                                                      1
                                                  ? doc.reference.path
                                                      .split('/')[1]
                                                  : null);
                                          if (courseId != null) {
                                            final courseTitle =
                                                _enrolledCourseNames[
                                                        courseId] ??
                                                    'Detail Mata Kuliah';
                                            Navigator.pushNamed(
                                              context,
                                              '/student-course-detail',
                                              arguments: {
                                                'courseId': courseId,
                                                'courseTitle': courseTitle,
                                                'assignmentId': doc.id,
                                              },
                                            );
                                          }
                                        },
                                      });
                                    }
                                  }

                                  // 4. Firestore Events
                                  if (eventSnap.hasData) {
                                    for (var doc in eventSnap.data!.docs) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      if (allItems.any(
                                          (it) => it['title'] == data['title']))
                                        continue;
                                      final startTs =
                                          data['startDate'] as Timestamp?;
                                      if (startTs == null) continue;
                                      final start = startTs.toDate();
                                      allItems.add({
                                        'title': data['title'],
                                        'label': data['type'] == 'holiday'
                                            ? 'Libur'
                                            : 'Event',
                                        'subtitle': data['description'] ?? '',
                                        'icon': data['type'] == 'holiday'
                                            ? Icons.calendar_today_rounded
                                            : Icons.event_note_rounded,
                                        'color': data['type'] == 'holiday'
                                            ? Colors.red
                                            : Colors.blue,
                                        'date': start,
                                        'type': data['type'] == 'holiday'
                                            ? 'holiday'
                                            : 'event',
                                        'onTap': () => widget.onTabChange(4,
                                            initialDate: start),
                                      });
                                    }
                                  }

                                  // Sort items
                                  Map<String, int> priority = {
                                    'class': 0,
                                    'assignment': 1,
                                    'grade': 2,
                                    'event': 3,
                                    'holiday': 10,
                                  };

                                  List<Map<String, dynamic>> sortedItems =
                                      List.from(allItems);
                                  sortedItems.sort((a, b) {
                                    int pA =
                                        priority[a['type'] ?? 'event'] ?? 2;
                                    int pB =
                                        priority[b['type'] ?? 'event'] ?? 2;
                                    if (pA != pB) return pA.compareTo(pB);
                                    return (a['date'] as DateTime)
                                        .compareTo(b['date'] as DateTime);
                                  });

                                  // Count notifications
                                  Map<String, int> typeCounts = {};

                                  for (var it in sortedItems) {
                                    String type = it['type'] ?? 'event';
                                    typeCounts[type] =
                                        (typeCounts[type] ?? 0) + 1;
                                  }

                                  if (sortedItems.isEmpty) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Informasi Penting",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 32, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).cardColor,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.03),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons
                                                    .notifications_none_rounded,
                                                size: 48,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                "Belum ada informasi penting saat ini.",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.grey.shade500,
                                                  fontStyle: FontStyle.italic,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "Informasi Penting",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      ...sortedItems.take(5).map((it) {
                                        return _buildNotificationItem(
                                          title: it['title'],
                                          label: it['label'],
                                          subtitle: it['subtitle'],
                                          icon: it['icon'],
                                          color: it['color'],
                                          onTap: it['onTap'],
                                        );
                                      }).toList(),
                                    ],
                                  );
                                });
                          });
                    });
              });
        });
  }

  Widget _buildNotificationItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (label != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }
}
