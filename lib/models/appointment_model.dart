class Appointment {
  final String id;
  final String doctorName;
  final String hospitalName;
  final DateTime dateTime;
  final String reason;
  final String reminder;
  final String notes;

  Appointment({
    required this.id,
    required this.doctorName,
    required this.hospitalName,
    required this.dateTime,
    this.reason = '',
    this.reminder = '1 hour before',
    this.notes = '',
  });

  /// 🔥 FROM FIRESTORE
  factory Appointment.fromFirestore(Map<String, dynamic> data, String id) {
    return Appointment(
      id: id,
      doctorName: data['doctorName'] ?? '',
      hospitalName: data['hospitalName'] ?? '',
      dateTime: DateTime.parse(data['dateTime']),
      reason: data['reason'] ?? '',
      reminder: data['reminder'] ?? '1 hour before',
      notes: data['notes'] ?? '',
    );
  }

  /// 🔥 TO FIRESTORE
  Map<String, dynamic> toMap(String caregiverId) {
    return {
      'caregiverId': caregiverId,
      'doctorName': doctorName,
      'hospitalName': hospitalName,
      'dateTime': dateTime.toIso8601String(),
      'reason': reason,
      'reminder': reminder,
      'notes': notes,
    };
  }
}