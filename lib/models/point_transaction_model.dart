import 'package:cloud_firestore/cloud_firestore.dart';

class PointTransaction {
  final String id;
  final String uid;
  final int points;
  final String reason;
  final DateTime timestamp;

  PointTransaction({
    required this.id,
    required this.uid,
    required this.points,
    required this.reason,
    required this.timestamp,
  });

  factory PointTransaction.fromFirebase(Map<String, dynamic> data, String id) {
    dynamic ts = data['timestamp'];
    DateTime timestamp;
    if (ts is Timestamp) {
      timestamp = ts.toDate();
    } else {
      timestamp = DateTime.now(); // Fallback for pending server timestamps
    }

    return PointTransaction(
      id: id,
      uid: data['uid'] ?? '',
      points: data['points'] ?? 0,
      reason: data['reason'] ?? '',
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'uid': uid,
      'points': points,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
