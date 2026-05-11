import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/features/dashboard/add_appointment_screen.dart';
import 'package:healthconnect/models/appointment_model.dart';
import 'package:healthconnect/core/services/appointment_service.dart';
import 'package:healthconnect/utils/date_time_helper.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AppointmentService();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AddAppointmentScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Appointments", style: AppTextStyles.heading),

              const SizedBox(height: AppSpacing.xxl),

              Expanded(
                child: StreamBuilder<List<Appointment>>(
                  stream: service.getAppointments(),
                  builder: (context, snapshot) {

                    // ── Loading ──
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    // ── Error ──
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              "Error: ${snapshot.error}",
                              style: AppTextStyles.small,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final appointments = snapshot.data ?? [];

                    // ── Empty ──
                    if (appointments.isEmpty) {
                      return _emptyState();
                    }

                    // ── List ──
                    return ListView.builder(
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        final appt = appointments[index];
                        return _appointmentCard(context, appt);
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

  Widget _appointmentCard(BuildContext context, Appointment appt) {
    final isUpcoming = appt.dateTime.isAfter(DateTime.now());

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AddAppointmentScreen(existingAppointment: appt),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.light],
          border: isUpcoming
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            // ── Top row ──
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isUpcoming
                          ? AppColors.iconBg
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_hospital,
                      color: isUpcoming
                          ? AppColors.primary
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appt.doctorName,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(appt.hospitalName,
                            style: AppTextStyles.subtitle),
                      ],
                    ),
                  ),
                  // Upcoming badge
                  if (isUpcoming)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.iconBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Upcoming",
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("Past",
                          style: AppTextStyles.small
                              .copyWith(color: Colors.grey)),
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF0F0F0)),

            // ── Details row ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 10),
              child: Column(
                children: [
                  _detailRow(
                      Icons.calendar_today,
                      DateTimeHelper.format(appt.dateTime),
                      isUpcoming),
                  if (appt.reason.isNotEmpty)
                    _detailRow(
                        Icons.medical_information_outlined,
                        appt.reason,
                        false),
                  if (appt.reminder.isNotEmpty)
                    _detailRow(Icons.alarm, appt.reminder, false),
                  if (appt.notes.isNotEmpty)
                    _detailRow(Icons.notes, appt.notes, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text, bool highlight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: highlight ? AppColors.primary : AppColors.hint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.small.copyWith(
                color: highlight ? AppColors.primary : AppColors.hint,
                fontWeight:
                    highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.iconBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today_outlined,
                size: 40, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          Text("No Appointments Yet", style: AppTextStyles.body),
          const SizedBox(height: 8),
          Text("Tap + to add an appointment",
              style: AppTextStyles.small),
        ],
      ),
    );
  }
}