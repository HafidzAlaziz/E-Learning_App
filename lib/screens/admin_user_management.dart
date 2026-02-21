import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_learning_app/widgets/user_avatar.dart';

class AdminUserManagementScreen extends StatefulWidget {
  final bool isView;
  const AdminUserManagementScreen({super.key, this.isView = false});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  String _selectedRole = 'All';
  late Stream<QuerySnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    _userStream = _selectedRole == 'All'
        ? FirebaseFirestore.instance.collection('users').snapshots()
        : FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: _selectedRole)
            .snapshots();
  }

  void _updateRoleFilter(String role) {
    setState(() {
      _selectedRole = role;
      _initStream();
    });
  }

  void _deleteUser(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Akun"),
        content: const Text("Apakah Anda yakin ingin menghapus akun ini?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Batal")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pengguna telah dihapus")),
        );
      }
    }
  }

  void _changeRole(String uid, String currentRole) async {
    String? newRole = await showDialog<String>(
      context: context,
      builder: (context) {
        String roleTemp = currentRole;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Ubah Peran"),
            content: DropdownButton<String>(
              value: roleTemp,
              isExpanded: true,
              items: ['admin', 'teacher', 'student']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setDialogState(() => roleTemp = val);
                }
              },
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal")),
              TextButton(
                  onPressed: () => Navigator.pop(context, roleTemp),
                  child: const Text("Simpan")),
            ],
          );
        });
      },
    );

    if (newRole != null && newRole != currentRole) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'role': newRole});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Peran diperbarui menjadi $newRole")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isView) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("Filter Peran:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    items: ['All', 'admin', 'teacher', 'student']
                        .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r[0].toUpperCase() + r.substring(1))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) _updateRoleFilter(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildUserList()),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Manajemen Pengguna",
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (val) => _updateRoleFilter(val),
            itemBuilder: (context) => ['All', 'admin', 'teacher', 'student']
                .map((r) => PopupMenuItem<String>(
                    value: r, child: Text(r[0].toUpperCase() + r.substring(1))))
                .toList(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Tidak ada pengguna ditemukan"));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final uid = users[index].id;
              final name = user['displayName'] ?? 'No Name';
              final email = user['email'] ?? 'No Email';
              final role = user['role'] ?? 'student';
              final photoUrl = user['photoURL'];

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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                        radius: 25,
                        uid: uid,
                        photoBase64: user['photoBase64'],
                        photoUrl: photoUrl,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "$name (${role[0].toUpperCase() + role.substring(1)})",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded,
                                          color: Colors.blue, size: 20),
                                      onPressed: () => _changeRole(uid, role),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_rounded,
                                          color: Colors.red, size: 20),
                                      onPressed: () => _deleteUser(uid),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
