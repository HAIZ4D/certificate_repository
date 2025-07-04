import 'package:cloud_firestore/cloud_firestore.dart';

class CAStatus {
  final int step;

  const CAStatus({required this.step});

  factory CAStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CAStatus(
      step: data['step'] ?? 0,
    );
  }
}
