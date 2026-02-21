import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:e_learning_app/screens/teacher_class_detail.dart';

class TeacherClassesScreen extends StatelessWidget {
  final bool isView;
  const TeacherClassesScreen({super.key, this.isView = false});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    Widget content = RefreshIndicator(
      onRefresh: () async {
        // Force rebuild to refresh stream
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .where('teacherId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.class_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada kelas yang ditugaskan",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeacherClassDetailScreen(
                          courseId: doc.id,
                          courseData: data,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                data['category'] ?? 'Umum',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${data['sks'] ?? 0} SKS",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['title'] ?? 'Tanpa Judul',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              "${data['day'] ?? '-'}, ${data['startTime'] ?? '-'} - ${data['endTime'] ?? '-'}",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.location_on_outlined,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              data['location'] ?? '-',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "Semester ${data['semester'] ?? '-'}",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    if (isView) return content;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Kelas Saya",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: content,
    );
  }
}
