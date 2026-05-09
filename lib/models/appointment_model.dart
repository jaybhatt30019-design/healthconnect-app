class Appointment {
  final String id;
  final String doctorName;
  final String hospitalName;
  final DateTime dateTime; // ✅ NEW
  final String reason;

  Appointment({
    required this.id,
    required this.doctorName,
    required this.hospitalName,
    required this.dateTime,
    required this.reason,
  });
}