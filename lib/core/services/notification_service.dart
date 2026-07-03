// lib/core/services/notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// ── Background handler ────────────────────────────────
@pragma('vm:entry-point')
Future<void> notificationTapBackground(
    NotificationResponse response) async {
  final payload = response.payload ?? '';
  final actionId = response.actionId ?? '';
  if (actionId == 'TAKEN') {
    await _markTakenAndCancelFollowUps(payload);
  } else if (actionId == 'REMIND_LATER') {
    await _remindLaterBackground(payload);
  }
}

// Initialise timezone + plugin for the background isolate.
// Each background isolate starts with a fresh singleton — call
// this before any show / cancel / zonedSchedule in that isolate.
Future<FlutterLocalNotificationsPlugin> _initBgPlugin() async {
  tz.initializeTimeZones();
  try {
    const Map<String, String> tzAliases = {
      'Asia/Calcutta': 'Asia/Kolkata',
      'Asia/Ulaanbaatar': 'Asia/Ulan_Bator',
      'America/Buenos_Aires':
          'America/Argentina/Buenos_Aires',
      'Atlantic/Faeroe': 'Atlantic/Faroe',
      'Pacific/Samoa': 'Pacific/Pago_Pago',
    };
    final localTz =
        await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(
        tz.getLocation(tzAliases[localTz] ?? localTz));
  } catch (_) {
    try {
      tz.setLocalLocation(
          tz.getLocation('Asia/Kolkata'));
    } catch (_) {}
  }
  final plugin = FlutterLocalNotificationsPlugin();
  const android =
      AndroidInitializationSettings('@drawable/logovitanex.png');
  const ios = DarwinInitializationSettings();
  await plugin.initialize(
    const InitializationSettings(
        android: android, iOS: ios),
  );
  return plugin;
}

Future<void> _markTakenAndCancelFollowUps(
    String payload) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[NotifBg] Firebase init: $e');
  }

  final parts = payload.split(':');
  if (parts.length < 2) return;
  final medicineId = parts[0];
  final index = int.tryParse(parts[1]) ?? -1;
  final medicineName =
      parts.length >= 3 ? parts[2] : 'Medicine';
  if (index == -1) return;

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
      // Keep lastResetDate in sync so Medicine.fromFirestore
      // does not override the taken flag on the next snapshot
      'lastResetDate': DateTime.now().toIso8601String(),
    });

    // Initialise the background-isolate plugin singleton
    // before calling cancel / show — the singleton starts
    // uninitialised in every new isolate.
    final plugin = await _initBgPlugin();
    final baseId =
        _computeMedNotifId(medicineId, index);
    for (int f = 1; f <= 3; f++) {
      await plugin.cancel(baseId + (f * 100));
    }
    await plugin.cancel(baseId + 9000);

    await plugin.show(
      99998,
      '✅ Dose Marked as Taken',
      '$medicineName — recorded successfully. Great job!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          timeoutAfter: 4000,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

    debugPrint(
        '[NotifBg] Marked taken: $medicineId[$index]');
  } catch (e) {
    debugPrint('[NotifBg] Error: $e');
  }
}

// Handle "Remind in 15 min" from background / killed state.
Future<void> _remindLaterBackground(
    String payload) async {
  final parts = payload.split(':');
  if (parts.length < 3) return;

  final medicineId = parts[0];
  final slotIndex = int.tryParse(parts[1]) ?? 0;
  final medicineName = parts[2];

  try {
    final plugin = await _initBgPlugin();
    final baseId =
        _computeMedNotifId(medicineId, slotIndex);
    final in15 = tz.TZDateTime.now(tz.local)
        .add(const Duration(minutes: 15));

    await plugin.zonedSchedule(
      baseId + 9000,
      '⏰ Reminder — Take your medicine',
      '$medicineName — you asked to be reminded',
      in15,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
          AndroidNotificationAction(
            'TAKEN',
            'Mark as Taken',
            cancelNotification: true,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'REMIND_LATER',
            'Remind in 15 min',
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'MEDICINE_CATEGORY',
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation
              .absoluteTime,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    await plugin.show(
      99997,
      '⏰ Reminder Set',
      '$medicineName — reminded in 15 minutes',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          importance: Importance.defaultImportance,
          autoCancel: true,
          timeoutAfter: 4000,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

    debugPrint(
        '[NotifBg] Remind later scheduled: '
        '$medicineId[$slotIndex]');
  } catch (e) {
    debugPrint('[NotifBg] Remind later error: $e');
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

  // ── Initialize ────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();
    try {
      String localTimezone =
          await FlutterTimezone.getLocalTimezone();

      const Map<String, String> tzAliases = {
        'Asia/Calcutta': 'Asia/Kolkata',
        'Asia/Ulaanbaatar': 'Asia/Ulan_Bator',
        'America/Buenos_Aires':
            'America/Argentina/Buenos_Aires',
        'Atlantic/Faeroe': 'Atlantic/Faroe',
        'Pacific/Samoa': 'Pacific/Pago_Pago',
      };

      if (tzAliases.containsKey(localTimezone)) {
        debugPrint(
            '[NotifService] Timezone alias: '
            '$localTimezone → ${tzAliases[localTimezone]}');
        localTimezone = tzAliases[localTimezone]!;
      }

      tz.setLocalLocation(
          tz.getLocation(localTimezone));
      debugPrint(
          '[NotifService] Timezone set: $localTimezone');
    } catch (e) {
      try {
        tz.setLocalLocation(
            tz.getLocation('Asia/Kolkata'));
        debugPrint(
            '[NotifService] Timezone fallback: Asia/Kolkata');
      } catch (_) {
        debugPrint(
            '[NotifService] Timezone failed — using UTC');
      }
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

    // ✅ Handle action button tap that launched the app
    // When showsUserInterface:true, the action comes through
    // launch details on cold start, NOT through _onTap
    final launchDetails = await _plugin
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails!.notificationResponse;
      if (response != null) {
        debugPrint(
            '[NotifService] Launched from notification '
            'action=${response.actionId}');
        // Delay so Firebase + navigator are ready
        Future.delayed(const Duration(milliseconds: 500),
            () => _onTap(response));
      }
    }

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
        description:
            'Daily reminders to take medicines',
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
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
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

void _onTap(NotificationResponse response) async {
    final payload = response.payload ?? '';
    final actionId = response.actionId ?? '';

    if (actionId == 'TAKEN') {
      await _markTakenAndCancelFollowUps(payload);
      // _markTakenAndCancelFollowUps already shows
      // the "✅ Dose Marked as Taken" confirmation
    }

    if (actionId == 'REMIND_LATER') {
      final parts = payload.split(':');
      if (parts.length >= 3) {
        await _scheduleRemindLater(
          medicineId: parts[0],
          slotIndex: int.tryParse(parts[1]) ?? 0,
          medicineName: parts[2],
        );
        await _plugin.show(
          99997,
          '⏰ Reminder Set',
          '${parts[2]} — reminded in 15 minutes',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'medicine_reminders',
              'Medicine Reminders',
              importance: Importance.high,
              autoCancel: true,
              timeoutAfter: 4000,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    }
  }

  // ── Schedule medicine reminders ───────────────────
  Future<void> scheduleMedicineReminders({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> times,
    DateTime? endDate,
  }) async {
    if (kIsWeb) return;
    await initialize();

    // ✅ Skip entirely if medicine already expired
    // endDate null means Ongoing — always schedule
    if (endDate != null &&
        DateTime.now().isAfter(endDate)) {
      debugPrint(
          '[NotifService] $medicineName expired '
          '(endDate=${endDate.toIso8601String()}) '
          '— skipping all reminders');
      // Cancel any existing notifications for this med
      await cancelMedicineReminders(
          medicineId, times.length);
      return;
    }

    for (int i = 0; i < times.length; i++) {
      final time = times[i];
      final baseId = _medNotifId(medicineId, i);
  final hour = times[i].hour;
final slotLabel = hour < 12
    ? 'Morning'
    : hour < 17
        ? 'Afternoon'
        : 'Night';

      await _plugin.zonedSchedule(
        baseId,
        '💊 Time for your medicine',
        '$medicineName $dosage — $slotLabel dose',
        _nextInstance(time, endDate: endDate),
        _medicineNotifDetails(
          payload: '$medicineId:$i:$medicineName',
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation
                .absoluteTime,
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents:
            // ✅ If endDate set, do NOT repeat daily
            // Schedule as one-time only per day
            // and let auth_gate reschedule each login
            endDate != null
                ? null
                : DateTimeComponents.time,
        payload: '$medicineId:$i:$medicineName',
      );

      debugPrint(
          '[NotifService] Scheduled: $medicineName '
          'slot $i at ${time.hour}:'
          '${time.minute.toString().padLeft(2, '0')} '
          'endDate=${endDate?.toIso8601String() ?? 'Ongoing'}');

      // Follow-up reminders (1h–6h after)
      final baseDateTime =
          _nextInstance(time, endDate: endDate);
      for (int f = 1; f <= 6; f++) {
        final followUpTime =
            baseDateTime.add(Duration(hours: f));

        // ✅ Stop follow-ups after endDate
        if (endDate != null &&
            followUpTime.toLocal().isAfter(endDate)) {
          debugPrint(
              '[NotifService] Follow-up $f for '
              '$medicineName past endDate — stopping');
          { break; }
        }

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

  Future<void> rescheduleFollowUpsIfNeeded({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required List<TimeOfDay> times,
    required List<bool> takenStatus,
    DateTime? endDate,
  }) async {
    if (kIsWeb) return;
    await initialize();

    // ✅ Skip if expired
    if (endDate != null &&
        DateTime.now().isAfter(endDate)) { return; }

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

          // ✅ Stop after endDate
          if (endDate != null &&
              followUpTime
                  .toLocal()
                  .isAfter(endDate)) { break; }

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
                  AndroidScheduleMode
                      .exactAllowWhileIdle,
              payload:
                  '$medicineId:$i:$medicineName',
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
    final baseId =
        _medNotifId(medicineId, slotIndex);
    for (int f = 1; f <= 6; f++) {
      await _plugin.cancel(baseId + (f * 100));
    }
    await _plugin.cancel(baseId + 9000);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
    debugPrint(
        '[NotifService] All notifications cancelled (logout)');
  }

  Future<void> _scheduleRemindLater({
    required String medicineId,
    required int slotIndex,
    required String medicineName,
  }) async {
    if (kIsWeb) return;
    await initialize();
    final in15 = tz.TZDateTime.now(tz.local)
        .add(const Duration(minutes: 15));
    final baseId = _medNotifId(medicineId, slotIndex);
    await _plugin.zonedSchedule(
      baseId + 9000,
      '⏰ Reminder — Take your medicine',
      '$medicineName — you asked to be reminded',
      in15,
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
        // ✅ No action buttons — tapping opens the app
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

    final dayBefore = appointmentTime
        .subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        _apptId(appointmentId, 0),
        '🏥 Appointment Tomorrow',
        '$doctorName at $hospitalName — '
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



   final hour3Before = appointmentTime
        .subtract(const Duration(hours: 3));
    if (hour3Before.isAfter(now)) {
      await _plugin.zonedSchedule(
        _apptId(appointmentId, 2),
        '🏥 Appointment in 3 Hour',
        '$doctorName at $hospitalName',
        tz.TZDateTime.from(hour3Before, tz.local),
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

    final hourBefore = appointmentTime
        .subtract(const Duration(hours: 1));
    if (hourBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        _apptId(appointmentId, 1),
        '🏥 Appointment in 1 Hour',
        '$doctorName at $hospitalName',
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
     await _plugin.cancel(_apptId(appointmentId, 2));
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
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // ── Test helper ───────────────────────────────────
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  Future<void> scheduleTestIn5Seconds({
    required String title,
    required String body,
    required String channelId,
    List<AndroidNotificationAction> actions =
        const [],
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
          UILocalNotificationDateInterpretation
              .absoluteTime,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    await initialize();
    return await _plugin.pendingNotificationRequests();
  }

Future<void> showSystemNotification({
  required String title,
  required String body,
  String channelId = 'health_alerts',
}) async {
  if (kIsWeb) return;
  await initialize();
  await _plugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        icon:'logovitanex',
        channelId,
        channelId == 'health_alerts'
            ? 'Health Alerts'
            : channelId == 'appointment_reminders'
                ? 'Appointment Reminders'
                : 'Medicine Reminders',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );
}

  // ── ID helpers ────────────────────────────────────
  int _medNotifId(String id, int slot) =>
      (id.hashCode.abs() % 10000) + (slot * 1000);

  int _apptId(String id, int type) =>
      (id.hashCode.abs() % 10000) + 20000 + type;

  // ✅ _nextInstance respects endDate
  // If endDate is tomorrow and time is tomorrow,
  // do not schedule at all
  tz.TZDateTime _nextInstance(TimeOfDay time,
      {DateTime? endDate}) {
    final now = tz.TZDateTime.now(tz.local);

    final scheduledToday = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Future today — fire at exact time
    if (scheduledToday.isAfter(now)) {
      return scheduledToday;
    }

    // Passed within last 60 min — fire in 10 seconds
    final minutesPassed =
        now.difference(scheduledToday).inMinutes;
    if (minutesPassed <= 60) {
      debugPrint(
          '[NotifService] Time passed ${minutesPassed}m ago'
          ' — firing in 10 sec');
      return now.add(const Duration(seconds: 10));
    }

    // Passed more than 60 min ago — tomorrow
    return scheduledToday
        .add(const Duration(days: 1));
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $p';
  }
}