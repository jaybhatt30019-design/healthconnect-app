class EmergencyContactEntry {
  final String name;
  final String phone;
  final String? fcmToken; // only for paired in-app contacts

  EmergencyContactEntry({
    required this.name,
    required this.phone,
    this.fcmToken,
  });

  factory EmergencyContactEntry.fromMap(Map<String, dynamic> data) {
    return EmergencyContactEntry(
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      fcmToken: data['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    if (fcmToken != null) 'fcmToken': fcmToken,
  };
}

class EmergencyContacts {
  final String uid;
  final EmergencyContactEntry? primary;   // paired person — auto-filled
  final EmergencyContactEntry? secondary;
  final EmergencyContactEntry? tertiary;

  EmergencyContacts({
    required this.uid,
    this.primary,
    this.secondary,
    this.tertiary,
  });

  factory EmergencyContacts.fromFirestore(Map<String, dynamic> data, String uid) {
    return EmergencyContacts(
      uid: uid,
      primary: data['primary'] != null
          ? EmergencyContactEntry.fromMap(data['primary'])
          : null,
      secondary: data['secondary'] != null
          ? EmergencyContactEntry.fromMap(data['secondary'])
          : null,
      tertiary: data['tertiary'] != null
          ? EmergencyContactEntry.fromMap(data['tertiary'])
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    if (primary != null) 'primary': primary!.toMap(),
    if (secondary != null) 'secondary': secondary!.toMap(),
    if (tertiary != null) 'tertiary': tertiary!.toMap(),
  };
}