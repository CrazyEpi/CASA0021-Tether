import 'dart:async';
import 'package:gpp_fitness_tracker/services/ble_service.dart';
import 'package:gpp_fitness_tracker/services/firestore_service.dart';

class RideController {
  final BleService _ble = BleService();
  final FirestoreService _db = FirestoreService();
  
  StreamSubscription? _friendSubscription;

  // 社交“锁”逻辑：防抖动
  String? _lockedFriendId;
  
  // [新增] 初次连接光效锁，防止 Firebase 数据流频繁触发动画
  bool _hasSentInitialPulse = false;
  
  // 保存好友的绝对物理数据供 BLE 打包使用
  double currentFriendDistance = 0.0;
  double currentFriendGoal = 10.0;

  /// 当有好友加入骑行大厅时调用
  void onFriendOnline(String friendUserId) {
    // 核心逻辑：如果已经有锁定好友，直接忽略新好友的加入（第一优先级锁定）
    if (_lockedFriendId != null && _lockedFriendId != friendUserId) {
      return; 
    }
    
    // 如果没有好友，或者正是锁定的好友刷新了，执行订阅
    _lockedFriendId = friendUserId;
    startSyncingFriendProgress(friendUserId);
  }

  void startSyncingFriendProgress(String friendUserId) {
    _friendSubscription?.cancel(); 
    
    // 每次开启新同步时，重置初次提醒锁
    _hasSentInitialPulse = false;

    _friendSubscription = _db.streamFriendProgress(friendUserId).listen((data) {
      // 解析来自 Firebase 的绝对数值
      if (data.containsKey('distance')) {
        currentFriendDistance = data['distance'] ?? 0.0;
      }
      if (data.containsKey('goal')) {
        currentFriendGoal = data['goal'] ?? 10.0;
        if (currentFriendGoal <= 0) currentFriendGoal = 10.0; // 保护除 0 报错
      }

      // [核心修复] 只在初次成功获取到好友数据时，发送一次青色流水灯触发指令
      if (!_hasSentInitialPulse && _ble.isConnected) {
        _ble.writeNeoPixelSocialSignal();
        _hasSentInitialPulse = true; // 锁死，本次骑行不再重复触发
      }
    });
  }

  /// 退出骑行或断开连接时调用
  void stopSyncing() {
    _lockedFriendId = null;
    currentFriendDistance = 0.0;
    currentFriendGoal = 10.0;
    _hasSentInitialPulse = false;
    _friendSubscription?.cancel();
    _friendSubscription = null;
  }
}