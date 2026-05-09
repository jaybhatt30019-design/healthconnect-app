import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/features/dashboard/add_appointment_screen.dart';
import 'package:healthconnect/core/appointment_store.dart';
import 'package:healthconnect/utils/date_time_helper.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() =>
      _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  @override
  Widget build(BuildContext context) {
    final appointments = AppointmentStore.appointments;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddAppointmentScreen(),
            ),
          );

          if (result != null) {
            setState(() {});
          }
        },
        child: const Icon(Icons.add),
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
                child: appointments.isEmpty
                    ? Center(
                        child: Text(
                          "No Appointments Yet",
                          style: AppTextStyles.body,
                        ),
                      )
                    : ListView.builder(
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final appt = appointments[index];

                          return GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddAppointmentScreen(
                                    existingAppointment: appt,
                                  ),
                                ),
                              );

                              if (result != null) {
                                setState(() {});
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius:
                                    BorderRadius.circular(
                                        AppRadius.md),
                                boxShadow: [AppShadows.light],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appt.doctorName,
                                    style: AppTextStyles.body
                                        .copyWith(
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    appt.hospitalName,
                                    style:
                                        AppTextStyles.subtitle,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    appt.reason,
                                    style: AppTextStyles.small,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateTimeHelper.format(appt.dateTime),
                                    style: AppTextStyles.small,
                                  ),
                                  
                                ],
                              ),
                            ),
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
}