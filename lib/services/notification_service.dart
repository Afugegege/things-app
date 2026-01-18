import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data; // [FIX] Separate alias
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // [FIX] Initialize timezones using the data alias
    tz_data.initializeTimeZones();
    
    // Android Settings
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher'); 

    // iOS Settings
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );

    const InitializationSettings settings = 
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(settings);
  }

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ Notification Permission
      final status = await Permission.notification.request();
      if (status.isPermanentlyDenied) {
        openAppSettings();
      }
      
      // Android 12+ Exact Alarm Permission (Optional but recommended for exact scheduling)
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();

    } else if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      // [FIX] Ensure proper TZDateTime conversion
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel', 
          'Task Reminders',
          channelDescription: 'Notifications for task timers',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // [FIX] These enums are correct for flutter_local_notifications ^17.0.0
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}