import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyLeave {
  final String id;
  final String studentUid;
  final String reason;
  final String approvedBy;
  final DateTime approvedAt;
  final DateTime validUntil;
  final String? verificationCode;
  final List<String> evidenceUrls;
  final String? supervisorNote;
  final bool isActive;

  EmergencyLeave({
    required this.id,
    required this.studentUid,
    required this.reason,
    required this.approvedBy,
    DateTime? approvedAt,
    required this.validUntil,
    this.verificationCode,
    List<String>? evidenceUrls,
    this.supervisorNote,
    bool? isActive,
  })  : approvedAt = approvedAt ?? DateTime.now(),
        evidenceUrls = evidenceUrls ?? [],
        isActive = isActive ?? true;
 factory EmergencyLeave.fromFirestore(Map<String, dynamic> data, String id) {
    return EmergencyLeave(
      id: id,
      studentUid: data['studentUid'] as String,
      reason: data['reason'] as String,
      approvedBy: data['approvedBy'] as String,
      approvedAt: (data['approvedAt'] as Timestamp).toDate(),
      validUntil: (data['validUntil'] as Timestamp).toDate(),
      verificationCode: data['verificationCode'] as String?,
      evidenceUrls: List<String>.from(data['evidenceUrls'] ?? []),
      supervisorNote: data['supervisorNote'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentUid': studentUid,
      'reason': reason,
      'approvedBy': approvedBy,
      'approvedAt': Timestamp.fromDate(approvedAt),
      'validUntil': Timestamp.fromDate(validUntil),
      if (verificationCode != null) 'verificationCode': verificationCode,
      'evidenceUrls': evidenceUrls,
      if (supervisorNote != null) 'supervisorNote': supervisorNote,
      'isActive': isActive,
    };
  }

  void validate() {
    if (studentUid.isEmpty || !studentUid.startsWith('stu')) {
      throw ArgumentError('Invalid student reference');
    }
    
    if (reason.isEmpty || reason.length < 10) {
      throw ArgumentError('Reason must be at least 10 characters');
    }
    
    if (approvedBy.isEmpty || !approvedBy.startsWith('GRD-')) {
      throw ArgumentError('Approver must be a valid guard');
    }
    
    if (validUntil.isBefore(DateTime.now())) {
      throw ArgumentError('Expiry time must be in the future');
    }
    
    if (evidenceUrls.isEmpty) {
      throw ArgumentError('Evidence is required for emergency leave');
    }
  }

  // Helpers
  bool get isValid => isActive && validUntil.isAfter(DateTime.now());
  bool get isVerified => verificationCode != null;
}