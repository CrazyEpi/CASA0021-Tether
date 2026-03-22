import 'dart:async';
import 'package:gpp_fitness_tracker/services/ble_service.dart';
import 'package:gpp_fitness_tracker/services/firestore_service.dart';

class RideController {
  final BleService _ble = BleService();
  final FirestoreService _db = FirestoreService();
  
  StreamSubscription? _friendSubscription;

  // Lock friend ID to ensure only one friend is synced at a time
  String? _lockedFriendId;
  
  // Lock for initial connection pulse to prevent spamming animations
  bool _hasSentInitialPulse = false;
  
  double currentFriendDistance = 0.0;
  double currentFriendGoal = 10.0;

  // For receiving friend SOS alerts
  final StreamController<String> _friendSosController = StreamController<String>.broadcast();
  Stream<String> get friendSosStream => _friendSosController.stream;

  // Called when a friend joins
  void onFriendOnline(String friendUserId) {
    // Core logic: Ignore new friends if one is already locked
    if (_lockedFriendId != null && _lockedFriendId != friendUserId) {
      return; 
    }
    
    // 如果没有好友，或者正是锁定的好友刷新了，执行订阅
    _lockedFriendId = friendUserId;
    startSyncingFriendProgress(friendUserId);
  }

  // Proceed with subscription if no friend is locked or the locked friend reconnects
  void startSyncingFriendProgress(String friendUserId) {
    _friendSubscription?.cancel(); 
    
    // Reset the initial pulse lock on new syncs
    _hasSentInitialPulse = false;

    _friendSubscription = _db.streamFriendProgress(friendUserId).listen((data) {
      // Ignore real Firebase data streams if Developer Mode override is active
      if (_ble.devModeOverride) return;

      if (data.containsKey('distance')) {
        currentFriendDistance = data['distance']?.toDouble() ?? 0.0;
      }
      if (data.containsKey('goal')) {
        currentFriendGoal = data['goal']?.toDouble() ?? 10.0;
        if (currentFriendGoal <= 0) currentFriendGoal = 10.0;
      }

      // Listen for friend's SOS status and broadcast to UI
      if (data.containsKey('sosActive') && data['sosActive'] == true) {
        _friendSosController.add(friendUserId);
      }

      // Send the light effect command only once upon initial successful data fetch
      if (!_hasSentInitialPulse && _ble.isConnected) {
        _ble.writeNeoPixelSocialSignal();
        _hasSentInitialPulse = true; // Lock to prevent duplicate triggers during this ride
      }
    });
  }

  // Called when exiting a ride or disconnecting
  void stopSyncing() {
    _lockedFriendId = null;
    currentFriendDistance = 0.0;
    currentFriendGoal = 10.0;
    _hasSentInitialPulse = false;
    _friendSubscription?.cancel();
    _friendSubscription = null;
  }
}