import 'package:flutter_background/flutter_background.dart';
import 'package:flutter/material.dart';

class BackgroundServiceManager {
  /// 初始化并启动前台服务（在屏幕顶部显示常驻通知）
  static Future<void> start() async {
    // 检查是否已经开启，防止重复启动
    if (FlutterBackground.isBackgroundExecutionEnabled) return;

    // 配置 Android 通知栏的样式
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "TetherGPP Active",
      notificationText: "Cycling tracker is running in the background",
      notificationImportance: AndroidNotificationImportance.normal,
      // 使用 Flutter 默认的图标，如果是你们自己的图标可以改成对应的 drawable 名字
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'), 
    );

    // 初始化配置
    bool hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);
    
    if (hasPermissions) {
      // 正式提升为前台服务，保持 CPU 唤醒
      await FlutterBackground.enableBackgroundExecution();
      debugPrint('[Background] Foreground service started successfully.');
    } else {
      debugPrint('[Background] Failed to get background permissions.');
    }
  }

  /// 结束骑行时调用，关闭前台服务，让手机恢复正常休眠
  static Future<void> stop() async {
    if (FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
      debugPrint('[Background] Foreground service stopped.');
    }
  }
}