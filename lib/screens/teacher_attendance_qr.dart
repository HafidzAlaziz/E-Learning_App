import 'package:flutter/material.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherAttendanceQrScreen extends StatefulWidget {
  const TeacherAttendanceQrScreen({super.key});

  @override
  State<TeacherAttendanceQrScreen> createState() =>
      _TeacherAttendanceQrScreenState();
}

class _TeacherAttendanceQrScreenState extends State<TeacherAttendanceQrScreen> {
  String qrData = "";
  late Timer timer;
  int remainingSeconds = 60;
  Map<String, dynamic>? args;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (args == null) {
      args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _generateNewQr();
      _updateSessionStatus(true);
    }
  }

  Future<void> _updateSessionStatus(bool isActive) async {
    if (args == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(args!['courseId'])
          .collection('meetings')
          .doc(args!['meetingId'])
          .update({
        'isAttendanceActive': isActive,
        'courseId': args!['courseId'],
        'courseName': args!['courseName'],
      });
    } catch (e) {
      debugPrint("Error updating session status: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (remainingSeconds > 0) {
            remainingSeconds--;
          } else {
            _generateNewQr();
          }
        });
      }
    });
  }

  void _generateNewQr() {
    if (args == null) return;

    // Generate QR data based on timestamp + course identifier + meeting identifier
    final now = DateTime.now();
    final timestamp = now.toIso8601String();

    // FORMAT: COURSE_ID:MEETING_ID:TIMESTAMP:HASH
    final rawData = "${args!['courseId']}:${args!['meetingId']}:$timestamp";
    final hash = sha256.convert(utf8.encode(rawData)).toString();

    // We embed the raw data structure so the scanner can parse it easily
    // In a real app, you might only send the hash and verify on server
    // For this prototype, we'll send a structured string
    final qrContent = jsonEncode({
      'courseId': args!['courseId'],
      'meetingId': args!['meetingId'],
      'timestamp': timestamp,
      'hash': hash
    });

    setState(() {
      qrData = qrContent;
      remainingSeconds = 60;
    });
  }

  @override
  void dispose() {
    _updateSessionStatus(false);
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Absensi Dibuka",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Scan untuk Absen",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Mata Kuliah: ${args?['courseName'] ?? 'Unknown'}\n${args?['meetingName'] ?? ''}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 250.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppTheme.primaryColor,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  "Kode akan berubah dalam:",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  "$remainingSeconds detik",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      "3 Siswa Terdaftar | 1 Telah Absen",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
