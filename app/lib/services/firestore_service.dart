
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // This gets the unique ID of the person logged in (Gilang)
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // 1. Send Bike Metrics (Speed/Distance)
  Future<void> updateRideMetrics(double speed, double distance) async {
    if (_uid == null) return;

    try {
      await _db.collection('users').doc(_uid).collection('live_stats').doc('current_session').set({
        'speed': speed,
        'distance': distance,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Firestore Error: \$e');
    }
  }

  // 2. Log SOS Alerts
  Future<void> logSosAlert(bool isTriggered) async {
    if (_uid == null) return;

    await _db.collection('users').doc(_uid).collection('alerts').add({
      'type': 'SOS',
      'status': isTriggered ? 'active' : 'cleared',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}