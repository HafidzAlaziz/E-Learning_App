import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';
import 'package:e_learning_app/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class ProfileSettingsView extends StatefulWidget {
  const ProfileSettingsView({super.key});

  @override
  State<ProfileSettingsView> createState() => _ProfileSettingsViewState();
}

class _ProfileSettingsViewState extends State<ProfileSettingsView> {
  String? role;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRole = await AuthService().getUserRole(user.uid);
      if (mounted) {
        setState(() {
          role = userRole;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    // Kompresi cukup kuat agar size kecil (max 512px, quality 50%)
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 50,
    );

    if (image != null) {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          debugPrint("Mulai memproses gambar...");

          final bytes = await image.readAsBytes();
          final String base64Image = base64Encode(bytes);

          debugPrint(
              "Gambar berhasil dikonversi ke Base64 via dart:convert. Mengirim ke Firestore...");

          // Simpan ke Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'photoBase64': base64Image,
          }, SetOptions(merge: true));

          debugPrint("Berhasil disimpan ke Firestore!");

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Foto profil berhasil diperbarui")),
            );
          }
        }
      } catch (e) {
        debugPrint("Error uploading image: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Gagal: ${e.toString()}"),
                duration: const Duration(seconds: 4)),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _deleteProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Foto Profil"),
        content:
            const Text("Apakah Anda yakin ingin menghapus foto profil ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) setState(() => isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'photoBase64': FieldValue.delete(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Foto profil berhasil dihapus")),
          );
        }
      } catch (e) {
        debugPrint("Error deleting photo: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal menghapus: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  Widget _buildUpcomingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 0.5),
      ),
      child: const Text(
        "Fitur Mendatang",
        style: TextStyle(
            color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showEditProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    final nameController = TextEditingController(text: user?.displayName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profil"),
        content: TextField(
          controller: nameController,
          decoration: AppTheme.inputDecoration(
              context, "Nama Lengkap", Icons.person_outline),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await user?.updateDisplayName(nameController.text.trim());
                if (mounted) {
                  setState(() {});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profil berhasil diperbarui")),
                  );
                }
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile Section
                Center(
                  child: Column(
                    children: [
                      StreamBuilder<DocumentSnapshot>(
                        stream: user != null
                            ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .snapshots()
                            : null,
                        builder: (context, snapshot) {
                          ImageProvider? imageProvider;
                          bool hasBase64 = false;

                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            if (data != null &&
                                data.containsKey('photoBase64')) {
                              hasBase64 = true;
                              try {
                                imageProvider = MemoryImage(
                                  base64Decode(data['photoBase64']),
                                );
                              } catch (e) {
                                debugPrint("Error decoding base64: $e");
                              }
                            }
                          }

                          // Fallback to Google photoURL or default if no Base64
                          if (imageProvider == null && user?.photoURL != null) {
                            imageProvider = NetworkImage(user!.photoURL!);
                          }

                          return Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                backgroundImage: imageProvider,
                                child: imageProvider == null
                                    ? const Icon(Icons.person_rounded,
                                        size: 60, color: AppTheme.primaryColor)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        debugPrint("Camera icon tapped");
                                        _pickAndUploadImage();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: 20),
                                      ),
                                    ),
                                    if (hasBase64) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _deleteProfilePhoto(),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.delete_rounded,
                                              color: Colors.white,
                                              size: 20),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.displayName ?? "User Name",
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? "email@example.com",
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      if (!isLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            role?.toUpperCase() ?? "USER",
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Settings Section
                _buildSectionTitle("Pengaturan Aplikasi"),
                const SizedBox(height: 16),
                _buildSettingCard([
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppTheme.themeNotifier,
                    builder: (context, currentMode, _) {
                      return _buildSettingRow(
                        Icons.dark_mode_rounded,
                        "Tema Gelap",
                        trailing: Switch(
                          value: currentMode == ThemeMode.dark,
                          onChanged: (val) {
                            AppTheme.themeNotifier.value =
                                val ? ThemeMode.dark : ThemeMode.light;
                          },
                          activeThumbColor: AppTheme.primaryColor,
                          activeTrackColor:
                              AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      );
                    },
                  ),
                  _buildSettingRow(
                    Icons.notifications_outlined,
                    "Notifikasi",
                    trailing: _buildUpcomingBadge(),
                  ),
                  _buildSettingRow(
                    Icons.language_rounded,
                    "Bahasa",
                    value: "Bahasa Indonesia",
                    trailing: _buildUpcomingBadge(),
                  ),
                ]),

                const SizedBox(height: 24),
                _buildSectionTitle("Akun"),
                const SizedBox(height: 16),
                _buildSettingCard([
                  _buildSettingRow(
                    Icons.person_outline_rounded,
                    "Edit Profil",
                    onTap: () => _showEditProfileDialog(),
                  ),
                  _buildSettingRow(
                    Icons.logout_rounded,
                    "Keluar",
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () async {
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    },
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
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
                    const Divider(height: 1, thickness: 0.5, indent: 55)
                ])
            .toList(),
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String title,
      {String? value,
      Widget? trailing,
      Color? textColor,
      Color? iconColor,
      VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? AppTheme.primaryColor),
      title: Text(title,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: textColor)),
      subtitle: value != null
          ? Text(value, style: const TextStyle(fontSize: 12))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}
