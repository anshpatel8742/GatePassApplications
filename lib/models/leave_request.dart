import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'enums.dart';
import 'package:crypto/crypto.dart';


// In leave_request.dart - Enhance status handling
extension LeaveStatusTransitions on LeaveStatus {
  bool canTransitionTo(LeaveStatus newStatus) {
    final validTransitions = {
      LeaveStatus.pending_guard: [LeaveStatus.approved, LeaveStatus.rejected],
      LeaveStatus.pending_warden: [LeaveStatus.approved, LeaveStatus.rejected],
      LeaveStatus.approved: [LeaveStatus.active, LeaveStatus.cancelled],
      LeaveStatus.active: [LeaveStatus.completed, LeaveStatus.expired],
    };
    return validTransitions[this]?.contains(newStatus) ?? false;
  }
}


class LeaveRequest {
  final String id;
  final String studentUid;
  final DocumentReference? studentRef;
  final String studentRoll;
  final String studentName;
  final String hostelName;
  final LeaveType type;
  final String reason;
  final DateTime exitTimePlanned;
  final DateTime? returnTimePlanned;
  final LeaveStatus status;
  final Map<String, dynamic>? approvedBy;
  final bool? parentApproved;
  final String? parentConsentUrl;
  final String? qrSecret;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String tripId;
  final List<Map<String, dynamic>> timeline;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final DateTime? parentVerifiedAt;
  final String? verificationMethod;
  final String? deviceId;
  final bool? hostelGuardApproved;
  final bool? mainGuardApproved;
  final DateTime? hostelGuardApprovedAt;
  final DateTime? mainGuardApprovedAt;

  LeaveRequest({
    required this.id,
    required this.studentUid,
    this.studentRef,
    required this.studentRoll,
    required this.studentName,
    required this.hostelName,
    required this.type,
    required this.reason,
    required this.exitTimePlanned,
    this.returnTimePlanned,
    required this.status,
    this.approvedBy,
    this.parentApproved,
    this.parentConsentUrl,
    this.qrSecret,
    DateTime? createdAt,
    this.updatedAt,
    required this.tripId,
    List<Map<String, dynamic>>? timeline,
    this.cancelledAt,
    this.cancelledBy,
    this.parentVerifiedAt,
    this.verificationMethod,
    this.deviceId,
    this.hostelGuardApproved,
    this.mainGuardApproved,
    this.hostelGuardApprovedAt,
    this.mainGuardApprovedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        timeline = timeline ?? [];


    static Map<String, dynamic>? parseApprovedBy(dynamic approvedBy) {
    if (approvedBy == null) return null;
    if (approvedBy is Map) return Map<String, dynamic>.from(approvedBy);
    if (approvedBy is String) return {'uid': approvedBy};
    debugPrint('Warning: Unexpected approvedBy type: ${approvedBy.runtimeType}');
    return null;
  }

  factory LeaveRequest.fromFirestore(Map<String, dynamic> data, String id) {
    try {

      
      // Handle approvedBy field safely
      Map<String, dynamic>? approvedBy;
      if (data['approvedBy'] != null) {
        if (data['approvedBy'] is Map) {
          approvedBy = Map<String, dynamic>.from(data['approvedBy'] as Map);
        } else {
          debugPrint('Warning: approvedBy is not a Map in document $id');
        }
      }

      // Handle timeline safely
      List<Map<String, dynamic>> timeline = [];
      if (data['timeline'] != null && data['timeline'] is List) {
        timeline = List<Map<String, dynamic>>.from(
          (data['timeline'] as List).map((item) => 
            item is Map ? Map<String, dynamic>.from(item) : {}
          )
        );
      }

      return LeaveRequest(
        id: id,
        studentUid: _safeGetString(data, 'studentUid'),
        studentRef: data['studentRef'] is DocumentReference 
            ? data['studentRef'] as DocumentReference 
            : null,
        studentRoll: _safeGetString(data, 'studentRoll'),
        studentName: _safeGetString(data, 'studentName'),
        hostelName: _safeGetString(data, 'hostelName'),
        type: LeaveType.fromValue(_safeGetString(data, 'type', 'day')),
        reason: _safeGetString(data, 'reason'),
        exitTimePlanned: _safeGetTimestamp(data, 'exitTimePlanned') ?? DateTime.now(),
        returnTimePlanned: _safeGetTimestamp(data, 'returnTimePlanned'),
        status: LeaveStatus.fromValue(_safeGetString(data, 'status', 'pending')),
        approvedBy: approvedBy,
        parentApproved: data['parentApproved'] as bool?,
        parentConsentUrl: _safeGetString(data, 'parentConsentUrl', null),
        qrSecret: _safeGetString(data, 'qrSecret', null),
        createdAt: _safeGetTimestamp(data, 'createdAt') ?? DateTime.now(),
        updatedAt: _safeGetTimestamp(data, 'updatedAt'),
        tripId: _safeGetString(data, 'tripId', id), // Default to document ID
        timeline: timeline,
        cancelledAt: _safeGetTimestamp(data, 'cancelledAt'),
        cancelledBy: _safeGetString(data, 'cancelledBy', null),
        parentVerifiedAt: _safeGetTimestamp(data, 'parentVerifiedAt'),
        verificationMethod: _safeGetString(data, 'verificationMethod', null),
        deviceId: _safeGetString(data, 'deviceId', null),
        hostelGuardApproved: data['hostelGuardApproved'] as bool?,
        mainGuardApproved: data['mainGuardApproved'] as bool?,
        hostelGuardApprovedAt: _safeGetTimestamp(data, 'hostelGuardApprovedAt'),
        mainGuardApprovedAt: _safeGetTimestamp(data, 'mainGuardApprovedAt'),
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing LeaveRequest $id: $e');
      debugPrint('Data: $data');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  static DateTime? _safeGetTimestamp(Map<String, dynamic> data, String key) {
    if (!data.containsKey(key)) return null;
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _safeGetString(Map<String, dynamic> data, String key, 
      [String? defaultValue]) {
    final value = data[key];
    if (value == null) return defaultValue ?? '';
    return value.toString();
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'studentUid': studentUid,
      'studentRoll': studentRoll,
      'studentName': studentName,
      'hostelName': hostelName,
      'type': type.value,
      'reason': reason,
      'exitTimePlanned': Timestamp.fromDate(exitTimePlanned),
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'tripId': tripId,
    };

    // Optional fields
    if (studentRef != null) map['studentRef'] = studentRef;
    if (returnTimePlanned != null) {
      map['returnTimePlanned'] = Timestamp.fromDate(returnTimePlanned!);
    }
    if (approvedBy != null) map['approvedBy'] = approvedBy;
    if (parentApproved != null) map['parentApproved'] = parentApproved;
    if (parentConsentUrl != null) map['parentConsentUrl'] = parentConsentUrl;
    if (qrSecret != null) map['qrSecret'] = qrSecret;
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    
    // Handle timeline safely
    map['timeline'] = timeline.map((e) {
      final entry = {
        'action': e['action']?.toString() ?? '',
        'timestamp': Timestamp.fromDate(
          e['timestamp'] is DateTime ? e['timestamp'] as DateTime : DateTime.now()
        ),
        'by': e['by']?.toString() ?? 'system',
      };
      if (e['metadata'] != null && e['metadata'] is Map) {
        entry['metadata'] = Map<String, dynamic>.from(e['metadata'] as Map);
      }
      return entry;
    }).toList();

    if (cancelledAt != null) map['cancelledAt'] = Timestamp.fromDate(cancelledAt!);
    if (cancelledBy != null) map['cancelledBy'] = cancelledBy;
    if (parentVerifiedAt != null) {
      map['parentVerifiedAt'] = Timestamp.fromDate(parentVerifiedAt!);
    }
    if (verificationMethod != null) map['verificationMethod'] = verificationMethod;
    if (deviceId != null) map['deviceId'] = deviceId;
    if (hostelGuardApproved != null) {
      map['hostelGuardApproved'] = hostelGuardApproved;
    }
    if (mainGuardApproved != null) map['mainGuardApproved'] = mainGuardApproved;
    if (hostelGuardApprovedAt != null) {
      map['hostelGuardApprovedAt'] = Timestamp.fromDate(hostelGuardApprovedAt!);
    }
    if (mainGuardApprovedAt != null) {
      map['mainGuardApprovedAt'] = Timestamp.fromDate(mainGuardApprovedAt!);
    }

    return map;
  }



  LeaveRequest copyWith({
    String? id,
    String? studentUid,
    DocumentReference? studentRef,
    String? studentRoll,
    String? studentName,
    String? hostelName,
    LeaveType? type,
    String? reason,
    DateTime? exitTimePlanned,
    DateTime? returnTimePlanned,
    LeaveStatus? status,
    Map<String, dynamic>? approvedBy,
    bool? parentApproved,
    String? parentConsentUrl,
    String? qrSecret,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? tripId,
    List<Map<String, dynamic>>? timeline,
    DateTime? cancelledAt,
    String? cancelledBy,
    DateTime? parentVerifiedAt,
    String? verificationMethod,
    String? deviceId,
    bool? hostelGuardApproved,
    bool? mainGuardApproved,
    DateTime? hostelGuardApprovedAt,
    DateTime? mainGuardApprovedAt,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      studentUid: studentUid ?? this.studentUid,
      studentRef: studentRef ?? this.studentRef,
      studentRoll: studentRoll ?? this.studentRoll,
      studentName: studentName ?? this.studentName,
      hostelName: hostelName ?? this.hostelName,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      exitTimePlanned: exitTimePlanned ?? this.exitTimePlanned,
      returnTimePlanned: returnTimePlanned ?? this.returnTimePlanned,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      parentApproved: parentApproved ?? this.parentApproved,
      parentConsentUrl: parentConsentUrl ?? this.parentConsentUrl,
      qrSecret: qrSecret ?? this.qrSecret,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tripId: tripId ?? this.tripId,
      timeline: timeline ?? List.from(this.timeline),
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      parentVerifiedAt: parentVerifiedAt ?? this.parentVerifiedAt,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      deviceId: deviceId ?? this.deviceId,
      hostelGuardApproved: hostelGuardApproved ?? this.hostelGuardApproved,
      mainGuardApproved: mainGuardApproved ?? this.mainGuardApproved,
      hostelGuardApprovedAt: hostelGuardApprovedAt ?? this.hostelGuardApprovedAt,
      mainGuardApprovedAt: mainGuardApprovedAt ?? this.mainGuardApprovedAt,
    );
  }

  

  // Enhanced validation
  void validate() {
    // Temporal validation
    if (exitTimePlanned.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      throw ValidationException('Leave must start at least 5 minutes from now');
    }

    if (type == LeaveType.home) {
      if (returnTimePlanned == null) {
        throw ValidationException('Return time required for home leave');
      }
      if (returnTimePlanned!.difference(exitTimePlanned).inHours < 12) {
        throw ValidationException('Home leave must be at least 12 hours');
      }
      if (!hasParentConsent) {
        throw ValidationException('Parent consent required for home leave');
      }
    } else if (returnTimePlanned != null) {
      if (returnTimePlanned!.isBefore(exitTimePlanned)) {
        throw ValidationException('Return time must be after exit time');
      }
      if (returnTimePlanned!.difference(exitTimePlanned).inHours > 12) {
        throw ValidationException('Day leave cannot exceed 12 hours');
      }
    }

    // Status consistency
    if (isApproved && !hasRequiredApprovals) {
      throw StateError('Approved leave is missing required approvals');
    }
  }

  // Status transition validation
  bool canTransitionTo(LeaveStatus newStatus) {
    return LeaveStatus.allowedTransitions(status).contains(newStatus);
  }

  bool get canGenerateQR {
    return (status.isApproved || status.isActive) && 
           !isOverdue &&
           exitTimePlanned.isBefore(DateTime.now().add(const Duration(hours: 24)));
  }

  // Security features
  bool get isQrValid {
    if (qrSecret == null) return false;
    return status.isActive && 
           !isOverdue &&
           exitTimePlanned.isBefore(DateTime.now());
  }

  // Helper getters
  bool get isPending => status.isPending;
  bool get isApproved => status.isApproved;
  bool get isActive => status.isActive;
  bool get isCompleted => status.isCompleted;
  bool get isCancelled => status.isCancelled;
  bool get isTerminal => status.isTerminal;

  bool get needsWardenApproval => type.requiresWardenApproval && isPending;
  bool get hasParentConsent => parentApproved == true || !type.requiresParentConsent;
  
  bool get hasRequiredApprovals {
    if (type == LeaveType.day) {
      return hostelGuardApproved == true;
    } else {
      return hostelGuardApproved == true && 
             mainGuardApproved == true && 
             parentApproved == true;
    }
  }

  bool get canBeCancelled => isPending || (isApproved && !exitTimePlanned.isBefore(DateTime.now()));
  bool get canBeApproved => isPending && hasParentConsent;

  bool get isOverdue {
    if (!isActive) return false;
    final expectedReturn = returnTimePlanned ?? exitTimePlanned.add(const Duration(hours: 8));
    return DateTime.now().isAfter(expectedReturn.add(const Duration(minutes: 15))); // 15 min grace period
  }

  

  // Timeline management
  void addTimelineEvent(String action, {String? by, Map<String, dynamic>? metadata}) {
    timeline.add({
      'action': action,
      'timestamp': DateTime.now(),
      'by': by ?? 'system',
      if (metadata != null) 'metadata': metadata,
    });
  }

  // QR Security
  String generateQRPayload(String deviceId) {
    if (qrSecret == null) throw StateError('QR secret not initialized');
    if (!isActive) throw StateError('Leave is not active');

    return jsonEncode({
      'v': 2, // version
      'lid': id,
      'tid': tripId,
      'sid': studentUid,
      't': DateTime.now().millisecondsSinceEpoch,
      'exp': returnTimePlanned?.millisecondsSinceEpoch ?? 
             exitTimePlanned.add(const Duration(hours: 24)).millisecondsSinceEpoch,
      'did': deviceId,
      'h': _generateQRHash(deviceId),
    });
  }

  String _generateQRHash(String deviceId) {
    final hmac = Hmac(sha256, utf8.encode(qrSecret!));
    final message = '$id-$deviceId-${DateTime.now().millisecondsSinceEpoch ~/ (1000 * 60 * 5)}'; // 5-minute window
    return hmac.convert(utf8.encode(message)).toString();
  }

  bool validateQRHash(String hash, String deviceId) {
    if (qrSecret == null) return false;
    return hash == _generateQRHash(deviceId);
  }

  // New methods for guard approvals
  bool get isHostelGuardApproved => hostelGuardApproved == true;
  bool get isMainGuardApproved => mainGuardApproved == true;

  DocumentReference get tripRef => FirebaseFirestore.instance.collection('trips').doc(tripId);
  DocumentReference get leaveRequestRef => FirebaseFirestore.instance.collection('leaveRequests').doc(id);

  // New method to check if all exit scans are done
  bool get hasExitedHostel {
    if (timeline.isEmpty) return false;
    return timeline.any((event) => 
        event['action'] == 'hostel_exit_scan' || 
        event['action'] == 'hostel_gate_exit');
  }

  // New method to check if all entry scans are done
  bool get hasReturnedToHostel {
    if (timeline.isEmpty) return false;
    return timeline.any((event) => 
        event['action'] == 'hostel_entry_scan' || 
        event['action'] == 'hostel_gate_entry');
  }

  // New method to get current trip status
  String get currentStatus {
    if (isCancelled) return 'Cancelled';
    if (isCompleted) return 'Completed';
    if (hasReturnedToHostel) return 'Returned';
    if (hasExitedHostel) return 'Outside Hostel';
    if (isApproved) return 'Approved';
    if (isPending) return 'Pending Approval';
    return 'Unknown';
  }
  
  @override
  String toString() {
    return 'LeaveRequest(id: $id, studentUid: $studentUid, status: ${status.value}, '
           'type: ${type.value}, exit: $exitTimePlanned, return: $returnTimePlanned)';
  }
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
  
}

