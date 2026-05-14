import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus {
  ringing,
  accepted,
  rejected,
  ended,
  missed,
}

enum CallerRole { parent, child }

class EmergencyCall {
  final String id;
  final String callerId;
  final String callerName;
  final CallerRole callerRole;
  final String receiverId;
  final String caregiverId;
  final CallStatus status;
  final String agoraChannel;
  final String agoraToken;
  final int fallbackAttempt; // 0=primary, 1=secondary, 2=tertiary
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  EmergencyCall({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.callerRole,
    required this.receiverId,
    required this.caregiverId,
    required this.status,
    required this.agoraChannel,
    required this.agoraToken,
    required this.fallbackAttempt,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  factory EmergencyCall.fromFirestore(Map<String, dynamic> data, String id) {
    return EmergencyCall(
      id: id,
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      callerRole: data['callerRole'] == 'parent'
          ? CallerRole.parent
          : CallerRole.child,
      receiverId: data['receiverId'] ?? '',
      caregiverId: data['caregiverId'] ?? '',
      status: _parseStatus(data['status']),
      agoraChannel: data['agoraChannel'] ?? '',
      agoraToken: data['agoraToken'] ?? '',
      fallbackAttempt: data['fallbackAttempt'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      answeredAt: (data['answeredAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerRole': callerRole == CallerRole.parent ? 'parent' : 'child',
      'receiverId': receiverId,
      'caregiverId': caregiverId,
      'status': status.name,
      'agoraChannel': agoraChannel,
      'agoraToken': agoraToken,
      'fallbackAttempt': fallbackAttempt,
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }

  EmergencyCall copyWith({CallStatus? status, DateTime? answeredAt, DateTime? endedAt, int? fallbackAttempt}) {
    return EmergencyCall(
      id: id,
      callerId: callerId,
      callerName: callerName,
      callerRole: callerRole,
      receiverId: receiverId,
      caregiverId: caregiverId,
      status: status ?? this.status,
      agoraChannel: agoraChannel,
      agoraToken: agoraToken,
      fallbackAttempt: fallbackAttempt ?? this.fallbackAttempt,
      createdAt: createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  static CallStatus _parseStatus(String? s) {
    switch (s) {
      case 'ringing': return CallStatus.ringing;
      case 'accepted': return CallStatus.accepted;
      case 'rejected': return CallStatus.rejected;
      case 'ended': return CallStatus.ended;
      case 'missed': return CallStatus.missed;
      default: return CallStatus.ringing;
    }
  }
}