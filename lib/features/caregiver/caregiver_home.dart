import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/models/medicine_model.dart';

class CaregiverHome extends StatefulWidget {
  const CaregiverHome({super.key});

  @override
  State<CaregiverHome> createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {

  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 🔝 HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(getGreeting(), style: AppTextStyles.small),
                      const SizedBox(height: 4),
                      Text(
                        "Jay Bhatt",
                        style: AppTextStyles.heading,
                      ),
                    ],
                  ),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      boxShadow: [AppShadows.medium],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications_none,
                        color: AppColors.primary,
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              /// 👤 PATIENT CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [AppShadows.light],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 30,
                            color: AppColors.primary,
                          ),
                        ),

                        const SizedBox(width: AppSpacing.sm),

                        Text(
                          "Parent Name",
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(
                          icon: Icons.videocam,
                          label: "VIDEO SOS",
                          isPrimary: true,
                          onTap: () {},
                        ),
                        _buildActionButton(
                          icon: Icons.phone_android,
                          label: "CALL HELP",
                          isPrimary: false,
                          onTap: () {},
                        ),
                        _buildActionButton(
                          icon: Icons.local_hospital,
                          label: "EMERGENCY 108",
                          isPrimary: false,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              /// 🏥 TITLE
              Text("Health Summary", style: AppTextStyles.heading),

              const SizedBox(height: AppSpacing.md),

              /// 🔥 REALTIME MEDICINE DATA
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('medicines')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No data available",
                          style: AppTextStyles.body,
                        ),
                      );
                    }

                    List<Medicine> medicines = docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      List<TimeOfDay> times =
                          (data['times'] as List? ?? []).map((t) {
                        final parts = t.split(":");
                        return TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1]),
                        );
                      }).toList();

                      List<bool> takenStatus =
                          List<bool>.from(data['takenStatus'] ?? []);

                      if (takenStatus.length < times.length) {
                        takenStatus =
                            List.filled(times.length, false);
                      }

                      return Medicine(
                        id: doc.id,
                        name: data['name'] ?? "",
                        dosage: data['dosage'] ?? "",
                        times: times,
                        takenStatus: takenStatus,
                      );
                    }).toList();

                    return Column(
                      children: [
                        _buildTodayMedicationCard(medicines),
                        const SizedBox(height: 10),
                        _buildMissedDoseCard(medicines),
                      ],
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

  /// 🔘 ACTION BUTTON
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isPrimary
                    ? AppColors.darkPrimary
                    : AppColors.iconBg,
                shape: BoxShape.circle,
                boxShadow: [AppShadows.light],
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : AppColors.darkPrimary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.small.copyWith(
              color: AppColors.darkPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 📊 TODAY MEDICATION
  Widget _buildTodayMedicationCard(List<Medicine> medicines) {
    int total = 0;
    int taken = 0;

    for (var med in medicines) {
      total += med.takenStatus.length;
      taken += med.takenStatus.where((e) => e).length;
    }

    double progress = total == 0 ? 0 : taken / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Medication", style: AppTextStyles.body),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text("$taken / $total taken"),
        ],
      ),
    );
  }

  /// ⚠️ MISSED DOSE
  Widget _buildMissedDoseCard(List<Medicine> medicines) {
    final now = TimeOfDay.now();
    String? missed;

    for (var med in medicines) {
      for (int i = 0; i < med.times.length; i++) {
        final t = med.times[i];

        final isPassed =
            (t.hour < now.hour) ||
            (t.hour == now.hour && t.minute < now.minute);

        if (isPassed && !med.takenStatus[i]) {
          missed = med.name;
          break;
        }
      }
    }

    if (missed == null) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text("Missed: $missed"),
    );
  }
}