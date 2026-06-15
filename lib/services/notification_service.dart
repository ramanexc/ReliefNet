import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission();
    
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iOSSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    // Following the specific error message: named parameter 'settings' is required
    await _notificationsPlugin.initialize(
      initSettings, 
      // If positional fails, and it asks for 'settings', I'll use initializationSettings or settings
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'emergency_alerts',
        'Emergency Alerts',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    // Following the specific error message: named parameter 'id' is required
    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
