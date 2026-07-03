// lib/features/notifications/notification_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Vitanex/theme/app_design_system.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────
              Padding(
                padding:
                    const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    AppBackButton(
                        onTap: () =>
                            Navigator.pop(context)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text("Notifications",
                          style: AppTextStyles.body
                          ),
                          ),
                    if (uid != null)
                      GestureDetector(
                        onTap: () =>
                            _markAllRead(uid),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.iconBg,
                            borderRadius:
                                BorderRadius.circular(
                                    20),
                          ),
                          child: Text(
                            "Mark all read",
                            style: AppTextStyles.small
                                .copyWith(
                              color: AppColors.primary,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── List ────────────────────────────
              Expanded(
                child: uid == null
                    ? _emptyState()
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore
                            .instance
                            .collection('notifications')
                            .where('userId',
                                isEqualTo: uid)
                            .limit(50)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child:
                                    CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            // ── Rule fix hint ──────
                            return Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(
                                        24),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    const Icon(
                                        Icons
                                            .lock_outline,
                                        color:
                                            Colors.red,
                                        size: 40),
                                    const SizedBox(
                                        height: 12),
                                    Text(
                                      "Firestore rule "
                                      "is blocking reads.\n"
                                      "Update rule for "
                                      "notifications:\n\n"
                                      "allow read: if "
                                      "isLoggedIn();",
                                      style: AppTextStyles
                                          .small,
                                      textAlign:
                                          TextAlign
                                              .center,
                                    ),
                                    const SizedBox(
                                        height: 8),
                                    Text(
                                      snapshot
                                          .error
                                          .toString(),
                                      style: AppTextStyles
                                          .small
                                          .copyWith(
                                              fontSize:
                                                  10),
                                      textAlign:
                                          TextAlign
                                              .center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final docs =
                              snapshot.data?.docs ?? [];

                          if (docs.isEmpty) {
                            return _emptyState();
                          }

                          // Sort newest first in memory
                          final sorted = List.of(docs);
                          sorted.sort((a, b) {
                            final aTs = (a.data()
                                    as Map<String,
                                        dynamic>)[
                                'createdAt'] as Timestamp?;
                            final bTs = (b.data()
                                    as Map<String,
                                        dynamic>)[
                                'createdAt'] as Timestamp?;
                            if (aTs == null) return 1;
                            if (bTs == null) return -1;
                            return bTs.compareTo(aTs);
                          });

                          return ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal:
                                        AppSpacing.lg),
                            itemCount: sorted.length,
                            itemBuilder: (context, i) {
                              final data = sorted[i]
                                  .data() as Map<String,
                                      dynamic>;
                              return _notifCard(
                                context,
                                data,
                                sorted[i].id,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notifCard(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final read = data['read'] as bool? ?? false;
    final type = data['type'] as String? ?? '';
    final ts = data['createdAt'] as Timestamp?;
    final time =
        ts != null ? _formatTime(ts.toDate()) : '';

    return GestureDetector(
      // ✅ Mark read only when user taps the CARD
      // not on screen open
      onTap: () => _markRead(docId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color:
              read ? AppColors.card : AppColors.iconBg,
          borderRadius:
              BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
          border: read
              ? null
              : Border.all(
                  color: AppColors.primary
                      .withValues(alpha: 0.3),
                  width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _typeColor(type)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _typeIcon(type),
                color: _typeColor(type),
                size: 18,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.body
                              .copyWith(
                            fontWeight: read
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      // Unread dot
                      if (!read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration:
                              const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body,
                      style: AppTextStyles.small),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: AppTextStyles.small
                        .copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _markRead(String docId) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'read': true});
  }

  void _markAllRead(String uid) {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get()
        .then((snap) {
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      batch.commit();
    });
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'dose_taken':
        return Colors.green;
      case 'missed_dose':
        return Colors.red;
      case 'low_stock':
      case 'restocked':
        return Colors.orange;
      case 'appointment_added':
      case 'appointment_reminder':
        return Colors.blue;
      case 'scan_saved':
        return Colors.purple;
      case 'location_started':
        return AppColors.primary;
      case 'emergency':
        return Colors.red;
      default:
        return AppColors.hint;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'dose_taken':
        return Icons.check_circle_outline;
      case 'missed_dose':
        return Icons.warning_amber_outlined;
      case 'low_stock':
      case 'restocked':
        return Icons.inventory_2_outlined;
      case 'appointment_added':
      case 'appointment_reminder':
        return Icons.calendar_today_outlined;
      case 'scan_saved':
        return Icons.document_scanner_outlined;
      case 'location_started':
        return Icons.location_on_outlined;
      case 'emergency':
        return Icons.emergency_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_outlined,
              size: 38,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("No Notifications",
              style: AppTextStyles.body),
          const SizedBox(height: 8),
          Text("You're all caught up!",
              style: AppTextStyles.small),
        ],
      ),
    );
  }
}