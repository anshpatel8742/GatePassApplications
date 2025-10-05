import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart'; // Contains UserRole and AuditAction enums

class AuditLog {
  final String id;
  final AuditAction action;
  final String performedBy;
  final UserRole performerRole;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String? ipAddress;
  final String? deviceInfo;

  AuditLog({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.performerRole,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    this.ipAddress,
    this.deviceInfo,
  })  : timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? {};

  // Factory constructor for leave approval
  factory AuditLog.leaveApproval({
    required String id,
    required String performedBy,
    required UserRole performerRole,
    required String leaveRequestId,
  }) {
    return AuditLog(
      id: id,
      action: AuditAction.leave_approved,
      performedBy: performedBy,
      performerRole: performerRole,
      metadata: {
        'leaveRequestId': leaveRequestId,
      },
    );
  }

  factory AuditLog.fromFirestore(Map<String, dynamic> data, String id) {
    return AuditLog(
      id: id,
      action: AuditAction.values.firstWhere(
        (e) => e.value == data['action'],
        orElse: () => AuditAction.values.first,
      ),
      performedBy: data['performedBy'] as String,
      performerRole: UserRole.values.firstWhere(
        (e) => e.value == data['performerRole'],
        orElse: () => UserRole.student,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      ipAddress: data['ipAddress'] as String?,
      deviceInfo: data['deviceInfo'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action.value,
      'performedBy': performedBy,
      'performerRole': performerRole.value,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
    };
  }

  void validate() {
    if (performedBy.isEmpty) {
      throw ArgumentError('Performer ID is required');
    }
    
    if (action == AuditAction.leave_rejected && !metadata.containsKey('reason')) {
      throw ArgumentError('Rejection actions require a reason');
    }
  }

 bool get isSecurityCritical => [
  AuditAction.leave_rejected,
  AuditAction.security_override,
  AuditAction.data_exported,
].contains(action);
}