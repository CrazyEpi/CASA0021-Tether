import 'package:flutter_background/flutter_background.dart';
import 'package:flutter/material.dart';

class BackgroundServiceManager {
  // Initializes and starts the foreground service to prevent OS suspension
  static Future<void> start() async {
    // Prevent duplicate starts
    if (FlutterBackground.isBackgroundExecutionEnabled) return;

    // Configure Android notification styles
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "TetherGPP Active",
      notificationText: "Cycling tracker is running in the background",
      notificationImportance: AndroidNotificationImportance.normal,
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'), 
    );

    bool hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);
    
    if (hasPermissions) {
      // Escalate to foreground service to keep CPU awake
      await FlutterBackground.enableBackgroundExecution();
      debugPrint('[Background] Foreground service started successfully.');
    } else {
      debugPrint('[Background] Failed to get background permissions.');
    }
  }

  // Stops the foreground service, allowing the OS to sleep normally
  static Future<void> stop() async {
    if (FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
      debugPrint('[Background] Foreground service stopped.');
    }
  }
}