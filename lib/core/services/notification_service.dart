// lib/core/services/notification_service.dart
// Fix #4/#14 — correct local timezone so reminders fire at right time
// Fix #11 — cancelAllNotifications() for logout

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Background handler ────────────────────────────────
@pragma('vm:entry-point')
void notificationTapBackground(
    NotificationResponse response) {
  final payload = response.payload ?? '';
  final actionId = response.actionId ?? '';
  if (actionId == 'TAKEN') {
    _markTakenAndCancelFollowUps(payload);
  }
}

Future<void> _markTakenAndCancelFollowUps(
    String payload) async {
  final parts = payload.split(':');
  if (parts.length < 2) return;
  final medicineId = parts[0];
  final index = int.tryParse(parts[1]);
  if (index == null) return;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('medicines')
        .doc(medicineId)
        .get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final takenStatus =
        List<bool>.from(data['takenStatus'] ?? []);
    if (index < takenStatus.length) {
      takenStatus[index] = true;
    }
    final stockCount =
        (data['stockCount'] as num?)?.toInt() ?? 0;
    final newStock =
        stockCount > 0 ? stockCount - 1 : 0;

    await FirebaseFirestore.instance
        .collection('medicines')
        .doc(medicineId)
        .update({
      'takenStatus': takenStatus,
      'stockCount': newStock,
    });

    final plugin = FlutterLocalNotificationsPlugin();
    final baseId = _computeMedNotifId(medicineId, index);
    for (int f = 1; f <= 6; f++) {
      await plugin.cancel(baseId + (f * 100));
    }
    await plugin.cancel(baseId + 9000);

    debugPrint(
        '[NotifBg] Marked taken: $medicineId[$index]');
  } catch (e) {
    debugPrint('[NotifBg] Error: $e');
  }
}

int _computeMedNotifId(String medicineId, int slot) {
  return (medicineId.hashCode.abs() % 10000) +
      (slot * 1000);
}

// ── NotificationService ───────────────────────────────
class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _medicineChannelId =
      'medicine_reminders';
  static const _appointmentChannelId =
      'appointment_reminders';
  static const _alertChannelId = 'health_alerts';

  // ── Initialize ─────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    // ✅ FIX #4/#14 — set correct local timezone
    // Without this, reminders fire at UTC time
    // not the user's local time
    tz.initializeTimeZones();
    try {
      final String localTimezone =
          await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(
          tz.getLocation(localTimezone));
      debugPrint(
          '[NotifService] Timezone: $localTimezone');
    } catch (e) {
      debugPrint(
          '[NotifService] Timezone error: $e — '
          'falling back to UTC');
    }

    const android = AndroidInitializationSettings(
        '@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackground,
    );

    await _createChannels();
    await _requestPermissions();
    _initialized = true;
    debugPrint('[NotifService] Initialized ✅');
  }

  Future<void> _createChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _medicineChannelId,
        'Medicine Reminders',
        description: 'Daily reminders to take medicines',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _appointmentChannelId,
        'Appointment Reminders',
        description: 'Doctor appointment alerts',
        importance: Importance.high,
        playSound: true,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannelId,
        'Health Alerts',
        description: 'Low stock and health alerts',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(
        alert: true, badge: true, sound: true);
  }

  void _onTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    final actionId = response.actionId ?? '';

    if (actionId == 'TAKEN') {
      _markTakenAndCancelFollowUps(payload);
    }
    if (actionId == 'REMIND_LATER') {
      final parts = payload.split(':');
      if (parts.length >= 3) {
        _scheduleRemindLater(
          medicineId: parts[0],
          slotIndex: int.tryParse(parts[1]) ?? 0,
          medicineName: parts[2],
        );
      }
    }
  }

  // ── SCHEDULE MEDICINE REMINDERS ───────────────────
  Future<void> scheduleMedicineReminders({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> times,
  }) async {
    if (kIsWeb) return;
    await initialize();

    for (int i = 0; i < times.length; i++) {
      final time = times[i];
      final baseId = _medNotifId(medicineId, i);
      final slotLabel = i == 0
          ? 'Morning'
          : i == 1
              ? 'Afternoon'
              : 'Night';

      await _plugin.zonedSchedule(
        baseId,
        '💊 Time for your medicine',
        '$medicineName $dosage — $slotLabel dose',
        _nextInstance(time),
        _medicineNotifDetails(
          payload: '$medicineId:$i:$medicineName',
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation
                .absoluteTime,
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '$medicineId:$i:$medicineName',
      );

      debugPrint(
          '[NotifService] Scheduled: $medicineName '
          'slot $i at ${time.hour}:'
          '${time.minute.toString().padLeft(2, '0')}');

      // Follow-up reminders (1h–6h after)
      final baseDateTime = _nextInstance(time);
      for (int f = 1; f <= 6; f++) {
        final followUpTime =
            baseDateTime.add(Duration(hours: f));
        final followUpId = baseId + (f * 100);
        final now = tz.TZDateTime.now(tz.local);
        if (followUpTime.isAfter(now)) {
          await _plugin.zonedSchedule(
            followUpId,
            '⏰ Medicine not taken yet',
            '$medicineName $dosage — '
                'You missed your $slotLabel dose',
            followUpTime,
            _medicineNotifDetails(
              payload: '$medicineId:$i:$medicineName',
              isFollowUp: true,
            ),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation
                    .absoluteTime,
            androidScheduleMode:
                AndroidScheduleMode.exactAllowWhileIdle,
            payload: '$medicineId:$i:$medicineName',
          );
        }
      }
    }
  }

  Future<void> rescheduleFollowUpsIfNeeded({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> times,
    required List<bool> takenStatus,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < times.length; i++) {
      if (i < takenStatus.length && takenStatus[i]) {
        continue;
      }
      final time = times[i];
      final baseId = _medNotifId(medicineId, i);
      final slotToday = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      if (slotToday.isBefore(now)) {
        final hoursPassed =
            now.difference(slotToday).inHours;
        for (int f = hoursPassed + 1; f <= 6; f++) {
          final followUpTime =
              slotToday.add(Duration(hours: f));
          final followUpId = baseId + (f * 100);
          if (followUpTime.isAfter(now)) {
            await _plugin.zonedSchedule(
              followUpId,
              '⏰ Medicine not taken yet',
              '$medicineName $dosage — '
                  'Please take your dose now',
              followUpTime,
              _medicineNotifDetails(
                payload:
                    '$medicineId:$i:$medicineName',
                isFollowUp: true,
              ),
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation
                      .absoluteTime,
              androidScheduleMode:
                  AndroidScheduleMode.exactAllowWhileIdle,
              payload: '$medicineId:$i:$medicineName',
            );
          }
        }
      }
    }
  }

  Future<void> cancelMedicineReminders(
      String medicineId, int slotCount) async {
    if (kIsWeb) return;
    for (int i = 0; i < slotCount; i++) {
      final baseId = _medNotifId(medicineId, i);
      await _plugin.cancel(baseId);
      for (int f = 1; f <= 6; f++) {
        await _plugin.cancel(baseId + (f * 100));
      }
      await _plugin.cancel(baseId + 9000);
    }
  }

  Future<void> cancelSlotFollowUps(
      String medicineId, int slotIndex) async {
    if (kIsWeb) return;
    final baseId = _medNotifId(medicineId, slotIndex);
    for (int f = 1; f <= 6; f++) {
      await _plugin.cancel(baseId + (f * 100));
    }
    await _plugin.cancel(baseId + 9000);
  }

  // ✅ FIX #11 — cancel ALL notifications on logout
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
    debugPrint(
        '[NotifService] All notifications cancelled '
        '(logout)');
  }

  Future<void> _scheduleRemindLater({
    required String medicineId,
    required int slotIndex,
    required String medicineName,
  }) async {
    if (kIsWeb) return;
    await initialize();
    final in30 = tz.TZDateTime.now(tz.local)
        .add(const Duration(minutes: 30));
    final baseId = _medNotifId(medicineId, slotIndex);
    await _plugin.zonedSchedule(
      baseId + 9000,
      '⏰ Reminder — Take your medicine',
      '$medicineName — you asked to be reminded',
      in30,
      _medicineNotifDetails(
        payload:
            '$medicineId:$slotIndex:$medicineName',
        isFollowUp: true,
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation
              .absoluteTime,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      payload: '$medicineId:$slotIndex:$medicineName',
    );
  }

  Future<void> remindLater({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required int slotIndex,
  }) async {
    await _scheduleRemindLater(
      medicineId: medicineId,
      slotIndex: slotIndex,
      medicineName: medicineName,
    );
  }

  NotificationDetails _medicineNotifDetails({
    required String payload,
    bool isFollowUp = false,
  }) {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _medicineChannelId,
        'Medicine Reminders',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            'TAKEN',
            '✅ Mark as Taken',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'REMIND_LATER',
            '⏰ Remind in 30 min',
            cancelNotification: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'MEDICINE_CATEGORY',
      ),
    );
  }

  Future<void> scheduleAppointmentReminders({
    required String appointmentId,
    required String doctorName,
    required String hospitalName,
    required DateTime appointmentTime,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final now = DateTime.now();

    final dayBefore =
        appointmentTime.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        _apptId(appointmentId, 0),
        '🏥 Appointment Tomorrow',
        'Dr. $doctorName at $hospitalName — '
            '${_fmtTime(appointmentTime)}',
        tz.TZDateTime.from(dayBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _appointmentChannelId,
            'Appointment Reminders',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation
                .absoluteTime,
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'appointment:$appointmentId',
      );
    }

    final hourBefore =
        appointmentTime.subtract(const Duration(hours: 1));
    if (hourBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        _apptId(appointmentId, 1),
        '🏥 Appointment in 1 Hour',
        'Dr. $doctorName at $hospitalName',
        tz.TZDateTime.from(hourBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _appointmentChannelId,
            'Appointment Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation
                .absoluteTime,
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'appointment:$appointmentId',
      );
    }
  }

  Future<void> cancelAppointmentReminders(
      String appointmentId) async {
    if (kIsWeb) return;
    await _plugin.cancel(_apptId(appointmentId, 0));
    await _plugin.cancel(_apptId(appointmentId, 1));
  }

  Future<void> showAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId,
          'Health Alerts',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // ── Test helpers ──────────────────────────────────
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  Future<void> scheduleTestIn5Seconds({
    required String title,
    required String body,
    required String channelId,
    List<AndroidNotificationAction> actions = const [],
  }) async {
    await initialize();
    final in5 = tz.TZDateTime.now(tz.local)
        .add(const Duration(seconds: 5));
    await _plugin.zonedSchedule(
      99991,
      title,
      body,
      in5,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance: Importance.high,
          priority: Priority.high,
          actions: actions,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    await initialize();
    return await _plugin.pendingNotificationRequests();
  }

  // ── ID helpers ────────────────────────────────────
  int _medNotifId(String id, int slot) =>
      (id.hashCode.abs() % 10000) + (slot * 1000);

  int _apptId(String id, int type) =>
      (id.hashCode.abs() % 10000) + 20000 + type;

  tz.TZDateTime _nextInstance(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled =
          scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $p';
  }
}