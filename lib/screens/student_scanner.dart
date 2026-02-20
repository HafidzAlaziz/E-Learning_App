import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class StudentScannerScreen extends StatefulWidget {
  const StudentScannerScreen({super.key});

  @override
  State<StudentScannerScreen> createState() => _StudentScannerScreenState();
}

class _StudentScannerScreenState extends State<StudentScannerScreen> {
  bool isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Scan Absensi",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (isScanning) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  debugPrint('Barcode found! ${barcode.rawValue}');
                  setState(() {
                    isScanning = false;
                  });
                  _onDetect(barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "Arahkan kamera ke QR Code Guru",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(String? code) async {
    if (code == null) return;

    try {
      final data = jsonDecode(code);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // 1. Validate Expiry
      if (data['timestamp'] != null) {
        try {
          final qrTime = DateTime.parse(data['timestamp']);
          final now = DateTime.now();
          // Allow 60 seconds validity
          if (now.difference(qrTime).inSeconds > 60) {
            _showErrorDialog("Barcode telah expired");
            return;
          }
        } catch (e) {
          debugPrint("Error parsing timestamp: $e");
          // Fallback if timestamp is invalid or missing -> proceed or fail?
          // Let's fail safe if we can't validate
          _showErrorDialog("Format QR Code tidak valid");
          return;
        }
      }

      // 2. Validate Session Status
      final meetingDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(data['courseId'])
          .collection('meetings')
          .doc(data['meetingId'])
          .get();

      if (!meetingDoc.exists) {
        _showErrorDialog("Pertemuan tidak ditemukan");
        return;
      }

      if (meetingDoc.data()?['isCompleted'] == true) {
        _showErrorDialog("Absen barcode ini telah ditutup");
        return;
      }

      // Check if already attended for this meeting to prevent duplicates
      final existing = await FirebaseFirestore.instance
          .collection('attendance')
          .where('meetingId', isEqualTo: data['meetingId'])
          .where('studentId', isEqualTo: uid)
          .get();

      if (existing.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('attendance').add({
          'courseId': data['courseId'],
          'meetingId': data['meetingId'],
          'studentId': uid,
          'timestamp': FieldValue.serverTimestamp(),
          'studentName':
              FirebaseAuth.instance.currentUser?.displayName ?? 'Student',
        });
      } else {
        _showErrorDialog("Anda sudah melakukan absensi untuk pertemuan ini");
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Absensi Berhasil"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Data Anda telah tercatat ke sistem."),
              const SizedBox(height: 12),
              Text("Waktu: ${DateTime.now().toString().split('.')[0]}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close scanner
              },
              child: const Text("Tutup"),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Error processing attendance: $e");
      if (mounted) {
        _showErrorDialog("Gagal memproses QR Code. Pastikan QR valid.");
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Gagal Absen"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => isScanning = true);
            },
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }
}
