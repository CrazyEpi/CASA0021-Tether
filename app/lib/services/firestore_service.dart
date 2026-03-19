import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Mengambil unique ID (UID) dari user yang sedang login (Gilang)
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── 1. Update Metrics & Ride Progress ──────────────────────────────────────
  
  /// Fungsi ini mengirim data kecepatan, jarak, dan menghitung progres
  /// [speed] dalam km/h, [distance] dalam meter, [goal] dalam meter.
  Future<void> updateRideMetrics(double speed, double distance, double goal) async {
    if (_uid == null) return;

    try {
      // Hitung persentase progres (0.0 sampai 1.0)
      // Contoh: Jarak 5km / Goal 10km = 0.5 (50%)
      double progress = (distance / goal).clamp(0.0, 1.0);

      // Simpan di root collection 'rides' agar mudah di-stream oleh teman
      await _db.collection('rides').doc(_uid).set({
        'currentSpeed': speed,
        'totalDistance': distance,
        'progressPercentage': progress, 
        'targetGoal': goal,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      print('❌ Firestore Update Error: $e');
    }
  }

  // ── 2. Stream Progres Teman ────────────────────────────────────────────────
  
  /// Digunakan oleh RideController untuk memantau progres teman secara real-time
  Stream<Map<String, dynamic>> streamFriendProgress(String friendId) {
    return _db.collection('rides').doc(friendId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return {}; // Kembalikan map kosong jika data tidak ada
    });
  }

  // ── 3. Log SOS Alerts ──────────────────────────────────────────────────────
  
  /// Mencatat status SOS di history user dan di dokumen ride aktif
  Future<void> logSosAlert(bool isTriggered) async {
    if (_uid == null) return;

    try {
      // A. Simpan di sub-collection alerts sebagai history permanen
      await _db.collection('users').doc(_uid).collection('alerts').add({
        'type': 'SOS',
        'status': isTriggered ? 'active' : 'cleared',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // B. Update di dokumen 'rides' utama agar teman langsung melihat status SOS
      await _db.collection('rides').doc(_uid).set({
        'sosActive': isTriggered,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
    } catch (e) {
      print('❌ Firestore SOS Log Error: $e');
    }
  }
}