import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Inisialisasi notifikasi dan timezone
  Future<void> initialize() async {
    if (_initialized) return;

    // Inisialisasi timezone
    tz.initializeTimeZones();

    // Set timezone ke Asia/Jakarta (WIB)
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (e) {
      if (kDebugMode) {
        print('Error setting timezone: $e');
      }
    }

    // Konfigurasi Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Konfigurasi iOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Inisialisasi plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permission untuk Android 13+
    await _requestPermissions();

    _initialized = true;
  }

  /// Request permission untuk Android 13+
  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Request permission untuk Android 13+
      await androidImplementation?.requestNotificationsPermission();

      // Request permission untuk exact alarm (Android 12+)
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  /// Handler ketika notifikasi diklik
  void _onNotificationTapped(NotificationResponse response) {
    // Bisa ditambahkan navigasi ke detail tugas jika diperlukan
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
  }

  /// Menjadwalkan notifikasi
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Pastikan waktu yang dijadwalkan di masa depan
    if (scheduledDate.isBefore(DateTime.now())) {
      if (kDebugMode) {
        print(
            'Scheduled date is in the past, notification will not be scheduled');
      }
      return;
    }

    // Konversi ke TZDateTime dengan timezone Asia/Jakarta
    final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
      scheduledDate,
      tz.getLocation('Asia/Jakarta'),
    );

    // Konfigurasi Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'task_reminder_channel',
      'Task Reminders',
      channelDescription: 'Notifikasi pengingat untuk tugas yang akan datang',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    // Konfigurasi iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Jadwalkan notifikasi
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTZ,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    if (kDebugMode) {
      print('Notification scheduled: ID=$id, Title=$title, Date=$scheduledTZ');
    }
  }

  /// Membatalkan notifikasi yang sudah dijadwalkan
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    if (kDebugMode) {
      print('Notification cancelled: ID=$id');
    }
  }

  /// Membatalkan semua notifikasi
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    if (kDebugMode) {
      print('All notifications cancelled');
    }
  }

  /// Mendapatkan daftar notifikasi yang sudah dijadwalkan (untuk Android)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
