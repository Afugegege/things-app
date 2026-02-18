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

    final initializationSettings = InitializationSettings(
      android: androidSettings, 
      iOS: iosSettings
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle action button clicks here if needed beyond just dismissal
        if (response.actionId == 'dismiss_event') {
          await _notifications.cancel(response.id ?? 0);
        }
      },
    );
  }

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ Notification Permission
      await _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      
      // Android 12+ Exact Alarm
      await _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();

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

  // [NEW] persistent event notification
  static Future<void> scheduleEventNotification({
    required int id,
    required String title,
    required String location,
    required DateTime scheduledTime,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      location.isNotEmpty ? "At $location" : "Happening now!",
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'event_channel',
          'Event Reminders',
          channelDescription: 'Persistent notifications for events',
          importance: Importance.max,
          priority: Priority.high,
          ongoing: true, // Makes it persistent (cant be swiped away easily)
          autoCancel: false, // Tapping doesnt dismiss
          actions: [
            AndroidNotificationAction(
              'dismiss_event', 
              'End',
              showsUserInterface: false,
              cancelNotification: true, // Clicking this specific button cancels it
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'event_category', 
           // iOS handles actions via categories, simpler setup for now:
           presentAlert: true,
           presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}