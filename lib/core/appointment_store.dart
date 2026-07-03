import 'package:Vitanex/models/appointment_model.dart';

class AppointmentStore {
  static List<Appointment> appointments = [];

  static void addAppointment(Appointment appointment) {
    appointments.add(appointment);
  }

  static void updateAppointment(Appointment updated) {
    final index =
        appointments.indexWhere((a) => a.id == updated.id);

    if (index != -1) {
      appointments[index] = updated;
    }
  }

  static void deleteAppointment(String id) {
    appointments.removeWhere((a) => a.id == id);
  }

  static List<Appointment> getUpcomingAppointments() {
  final now = DateTime.now();

  final upcoming = appointments
      .where((a) => a.dateTime.isAfter(now))
      .toList();

  upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));

  return upcoming;

}
}