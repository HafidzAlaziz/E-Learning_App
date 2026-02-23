import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_learning_app/core/theme.dart';

class UserAvatar extends StatefulWidget {
  final double radius;
  final String? uid;
  final String? photoBase64;
  final String? photoUrl;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.radius = 20,
    this.uid,
    this.photoBase64,
    this.photoUrl,
    this.onTap,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  ImageProvider? _cachedImageProvider;
  String? _lastBase64;
  String? _lastUrl;

  @override
  void initState() {
    super.initState();
    _updateImageProvider();
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photoBase64 != oldWidget.photoBase64 ||
        widget.photoUrl != oldWidget.photoUrl) {
      _updateImageProvider();
    }
  }

  void _updateImageProvider() {
    if (widget.photoBase64 != null) {
      if (widget.photoBase64 != _lastBase64) {
        try {
          _cachedImageProvider = MemoryImage(base64Decode(widget.photoBase64!));
          _lastBase64 = widget.photoBase64;
          _lastUrl = null;
        } catch (e) {
          debugPrint("Error decoding base64: $e");
          _cachedImageProvider = null;
        }
      }
    } else if (widget.photoUrl != null) {
      if (widget.photoUrl != _lastUrl) {
        _cachedImageProvider = NetworkImage(widget.photoUrl!);
        _lastUrl = widget.photoUrl;
        _lastBase64 = null;
      }
    } else {
      _cachedImageProvider = null;
      _lastBase64 = null;
      _lastUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Prioritize Direct Data (Cache used)
    if (widget.photoBase64 != null || widget.photoUrl != null) {
      return _buildAvatarImage(_cachedImageProvider);
    }

    final targetUid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;

    if (targetUid == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey.shade300,
        child: Icon(Icons.person,
            size: widget.radius, color: Colors.grey.shade600),
      );
    }

    // 2. Fallback to Stream if no direct data
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .snapshots(),
      builder: (context, snapshot) {
        ImageProvider? streamImageProvider;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('photoBase64')) {
            try {
              // Note: In stream mode, we don't cache as aggressively
              // because the stream itself should be stable unless data changes.
              // But strictly speaking, we could. For now, rely on direct data for lists.
              streamImageProvider = MemoryImage(
                base64Decode(data['photoBase64']),
              );
            } catch (e) {
              debugPrint("Error decoding base64: $e");
            }
          }
        }

        // Fallback to Google photoURL
        if (streamImageProvider == null) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && user.uid == targetUid && user.photoURL != null) {
            streamImageProvider = NetworkImage(user.photoURL!);
          }
        }

        return _buildAvatarImage(streamImageProvider);
      },
    );
  }

  Widget _buildAvatarImage(ImageProvider? imageProvider) {
    Widget avatarContent = CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(Icons.person_rounded,
              size: widget.radius * 1.2, color: AppTheme.primaryColor)
          : null,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: avatarContent,
      );
    }

    return avatarContent;
  }
}
