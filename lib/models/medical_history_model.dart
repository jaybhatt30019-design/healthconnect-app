// lib/models/medical_history_model.dart

enum Severity { mild, moderate, severe }

class Illness {
  final String id;
  final String name;
  final String? diagnosedDate;    // "2020-03" or "2020"
  final String? recoveredDate;    // null = ongoing
  final Severity severity;
  final String? doctor;
  final String? notes;

  Illness({
    required this.id,
    required this.name,
    this.diagnosedDate,
    this.recoveredDate,
    required this.severity,
    this.doctor,
    this.notes,
  });

  bool get isOngoing => recoveredDate == null || recoveredDate!.isEmpty;

  factory Illness.fromMap(Map<String, dynamic> data) {
    return Illness(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      diagnosedDate: data['diagnosedDate'],
      recoveredDate: data['recoveredDate'],
      severity: _parseSeverity(data['severity']),
      doctor: data['doctor'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'diagnosedDate': diagnosedDate ?? '',
    'recoveredDate': recoveredDate ?? '',
    'severity': severity.name,
    'doctor': doctor ?? '',
    'notes': notes ?? '',
  };

  static Severity _parseSeverity(String? s) {
    switch (s) {
      case 'moderate': return Severity.moderate;
      case 'severe': return Severity.severe;
      default: return Severity.mild;
    }
  }

  Illness copyWith({
    String? name,
    String? diagnosedDate,
    String? recoveredDate,
    Severity? severity,
    String? doctor,
    String? notes,
  }) {
    return Illness(
      id: id,
      name: name ?? this.name,
      diagnosedDate: diagnosedDate ?? this.diagnosedDate,
      recoveredDate: recoveredDate ?? this.recoveredDate,
      severity: severity ?? this.severity,
      doctor: doctor ?? this.doctor,
      notes: notes ?? this.notes,
    );
  }
}

class Surgery {
  final String id;
  final String name;
  final String? date;             // "2019-06-15"
  final String? hospital;
  final String? surgeon;
  final String? notes;

  Surgery({
    required this.id,
    required this.name,
    this.date,
    this.hospital,
    this.surgeon,
    this.notes,
  });

  factory Surgery.fromMap(Map<String, dynamic> data) {
    return Surgery(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      date: data['date'],
      hospital: data['hospital'],
      surgeon: data['surgeon'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'date': date ?? '',
    'hospital': hospital ?? '',
    'surgeon': surgeon ?? '',
    'notes': notes ?? '',
  };

  Surgery copyWith({
    String? name,
    String? date,
    String? hospital,
    String? surgeon,
    String? notes,
  }) {
    return Surgery(
      id: id,
      name: name ?? this.name,
      date: date ?? this.date,
      hospital: hospital ?? this.hospital,
      surgeon: surgeon ?? this.surgeon,
      notes: notes ?? this.notes,
    );
  }
}

class MedicalHistory {
  final String caregiverId;
  final List<Illness> illnesses;
  final List<Surgery> surgeries;

  MedicalHistory({
    required this.caregiverId,
    required this.illnesses,
    required this.surgeries,
  });

  factory MedicalHistory.empty(String caregiverId) {
    return MedicalHistory(
      caregiverId: caregiverId,
      illnesses: [],
      surgeries: [],
    );
  }

  factory MedicalHistory.fromFirestore(Map<String, dynamic> data) {
    return MedicalHistory(
      caregiverId: data['caregiverId'] ?? '',
      illnesses: (data['illnesses'] as List? ?? [])
          .map((e) => Illness.fromMap(e as Map<String, dynamic>))
          .toList(),
      surgeries: (data['surgeries'] as List? ?? [])
          .map((e) => Surgery.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'caregiverId': caregiverId,
    'illnesses': illnesses.map((e) => e.toMap()).toList(),
    'surgeries': surgeries.map((e) => e.toMap()).toList(),
  };
}