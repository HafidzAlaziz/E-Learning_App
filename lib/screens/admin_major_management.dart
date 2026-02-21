import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_learning_app/core/theme.dart';

class AdminMajorManagementScreen extends StatefulWidget {
  const AdminMajorManagementScreen({super.key});

  @override
  State<AdminMajorManagementScreen> createState() =>
      _AdminMajorManagementScreenState();
}

class _AdminMajorManagementScreenState
    extends State<AdminMajorManagementScreen> {
  final TextEditingController _majorController = TextEditingController();
  late Stream<QuerySnapshot> _majorStream;

  @override
  void initState() {
    super.initState();
    _majorStream = FirebaseFirestore.instance
        .collection('majors')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _showAddMajorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah Jurusan"),
        content: TextField(
          controller: _majorController,
          decoration: AppTheme.inputDecoration(
              context, "Nama Jurusan", Icons.school_outlined),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_majorController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('majors').add({
                  'name': _majorController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  _majorController.clear();
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  void _deleteMajor(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Jurusan?"),
        content: const Text(
            "Mengahpus jurusan ini mungkin berdampak pada data mahasiswa yang sudah memilihnya."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('majors')
                  .doc(id)
                  .delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Prodi",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _majorStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Belum ada data jurusan"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.school, color: Colors.white, size: 20),
                  ),
                  title: Text(doc['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteMajor(doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMajorDialog,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Tambah Jurusan"),
      ),
    );
  }
}
