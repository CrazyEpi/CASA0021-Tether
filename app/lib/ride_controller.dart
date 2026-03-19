import 'dart:async';
import 'ble_service.dart';
import 'firestore_service.dart';

class RideController {
  final BleService _ble = BleService();
  final FirestoreService _db = FirestoreService();
  
  // This subscription keeps the "ear" open to Firebase changes
  StreamSubscription? _friendSubscription;

  // Call this when you start a ride with a friend
  void startSyncingFriendProgress(String friendUserId) {
    _friendSubscription?.cancel(); // Clean up any old listeners

    _friendSubscription = _db.streamFriendProgress(friendUserId).listen((data) {
      if (data.containsKey('progressPercentage')) {
        double progress = data['progressPercentage'] ?? 0.0;
        
        // Push the update to the physical bike hardware
        if (_ble.isConnected) {
          _ble.writeProgressToHardware(progress);
        }
      }
    });
  }

  // Call this when the ride ends to save battery/data
  void stopSyncing() {
    _friendSubscription?.cancel();
    _friendSubscription = null;
  }
}