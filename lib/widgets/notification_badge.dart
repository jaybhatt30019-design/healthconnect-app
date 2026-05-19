// lib/widgets/notification_badge.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/features/notifications/notification_screen.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              NotificationScreen(),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          boxShadow: [AppShadows.medium],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none,
              color: AppColors.primary,
              size: 24,
            ),
            if (uid != null)
              StreamBuilder<QuerySnapshot>(
                // ✅ FIXED: only userId filter
                // No compound query = no index needed
                // Count unread docs in memory
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId',
                        isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  // Count unread in memory
                  final unreadCount = snapshot
                      .data!.docs
                      .where((doc) {
                    final data = doc.data()
                        as Map<String, dynamic>;
                    return data['read'] == false;
                  }).length;

                  if (unreadCount == 0) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 9
                              ? '9+'
                              : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}