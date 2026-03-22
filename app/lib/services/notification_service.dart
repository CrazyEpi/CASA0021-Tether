import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // Initialize the local notification service and request system permissions
  static Future<void> init() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: initSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initSettings, 
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[Notification] Alert clicked');
      },
    );

    // Request notification permissions
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  // Trigger a high-priority local notification for incoming SOS alerts
  static Future<void> showSosNotification(String friendName) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sos_urgent_alerts_v2', // Change Channel ID to force Android to recreate a max-priority channel
      'Emergency SOS Alerts',
      channelDescription: 'High priority alerts when friends trigger SOS',
      importance: Importance.max, // Max importance for heads-up display
      priority: Priority.high,
      ticker: 'SOS Alert',
      color: Colors.red,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    // // Ensure ID is a positive integer
    int safeId = friendName.hashCode.abs() % 100000;

    await _notificationsPlugin.show(
      id: safeId,
      title: 'EMERGENCY: $friendName',
      body: '$friendName has triggered an SOS alert! Check on them immediately.',
      notificationDetails: platformDetails,
    );
  }
}