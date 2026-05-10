import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data'; // Import needed for Int32List

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
        // Handle notification tap
      },
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'order_timer_channel_alarm', // ID Channel Beda biar setting baru ngefek
      'Order Timer Alarm',
      channelDescription: 'Alarm notifications for expired orders',
      importance: Importance.max,
      priority: Priority.max, // MAX PRIORITY
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
      // insistent: true, // Error: Parameter not found. Ganti pakai flag manual:
      additionalFlags: Int32List.fromList(<int>[4]), // 4 = FLAG_INSISTENT
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      
      // BIAR GAK BISA DI-SWIPE / DICLOSE USER:
      ongoing: true, 
      autoCancel: false, 
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
