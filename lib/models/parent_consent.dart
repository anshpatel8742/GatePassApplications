import 'package:cloud_firestore/cloud_firestore.dart';

class ParentConsent {
  final String id;
  final String leaveRequestId;
  final String studentRoll;
  final String parentPhone;
  final String? verificationCode;
  final bool isVerified;
  final Timestamp createdAt;

  ParentConsent({
    required this.id,
    required this.leaveRequestId,
    required this.studentRoll,
    required this.parentPhone,
    this.verificationCode,
    required this.isVerified,
    required this.createdAt,
  });

  factory ParentConsent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParentConsent(
      id: doc.id,
      leaveRequestId: data['leaveRequestId'],
      studentRoll: data['studentRoll'],
      parentPhone: data['parentPhone'],
      verificationCode: data['verificationCode'],
      isVerified: data['isVerified'] ?? false,
      createdAt: data['createdAt'],
    );
  }
}