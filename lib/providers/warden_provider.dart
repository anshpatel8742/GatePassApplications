import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/leave_request.dart';
import '../models/warden.dart';
import '../models/audit_log.dart';
import '../models/enums.dart';

class WardenProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final CollectionReference _leaveRequestsRef;
  final CollectionReference _tripsRef;
  final CollectionReference _auditLogsRef;
  final CollectionReference _notificationsRef;
  final CollectionReference _staffRef;

  List<LeaveRequest> _pendingHomeRequests = [];
  List<LeaveRequest> _overdueRequests = [];
  List<LeaveRequest> _recentApprovals = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;
  Warden? _currentWarden;

  // Getters
  List<LeaveRequest> get pendingHomeRequests => List.unmodifiable(_pendingHomeRequests);
  List<LeaveRequest> get overdueRequests => List.unmodifiable(_overdueRequests);
  List<LeaveRequest> get recentApprovals => List.unmodifiable(_recentApprovals);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;
  Warden? get currentWarden => _currentWarden;

  WardenProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _leaveRequestsRef = (firestore ?? FirebaseFirestore.instance).collection('leaveRequests'),
        _tripsRef = (firestore ?? FirebaseFirestore.instance).collection('trips'),
        _auditLogsRef = (firestore ?? FirebaseFirestore.instance).collection('auditLogs'),
        _notificationsRef = (firestore ?? FirebaseFirestore.instance).collection('notifications'),
        _staffRef = (firestore ?? FirebaseFirestore.instance).collection('staff');

  Future<void> initialize() async {
    await _loadWardenProfile();
    await fetchPendingHomeRequests();
    await fetchOverdueRequests();
    await fetchRecentApprovals();
  }

  Future<void> _loadWardenProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _staffRef.doc(user.uid).get();
      if (doc.exists) {
        _currentWarden =  Warden.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error loading warden profile: $e');
    }
  }

  // Core Warden Functions

  Future<void> fetchPendingHomeRequests() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final snapshot = await _leaveRequestsRef
          .where('type', isEqualTo: LeaveType.home.value)
          .where('status', isEqualTo: LeaveStatus.pending_warden.value)
          .orderBy('createdAt')
          .limit(50)
          .get();

      _pendingHomeRequests = snapshot.docs
          .map((doc) => LeaveRequest.fromFirestore(doc.data()! as Map<String, dynamic>, doc.id))
          .toList();
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
    } catch (e, stackTrace) {
      _error = 'Failed to load pending requests';
      debugPrint('Error fetching home requests: $e\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOverdueRequests() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = Timestamp.now();
      final snapshot = await _leaveRequestsRef
          .where('status', isEqualTo: LeaveStatus.approved.value)
          .where('returnTimePlanned', isLessThan: now)
          .where('isCompleted', isEqualTo: false)
          .orderBy('returnTimePlanned')
          .limit(100)
          .get();

      _overdueRequests = snapshot.docs
          .map((doc) => LeaveRequest.fromFirestore(doc.data()! as Map<String, dynamic>, doc.id))
          .toList();
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
    } catch (e, stackTrace) {
      _error = 'Failed to load overdue requests';
      debugPrint('Error fetching overdue requests: $e\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecentApprovals({int limit = 10}) async {
    try {
      if (_currentWarden == null) return;

      final snapshot = await _auditLogsRef
          .where('performedBy', isEqualTo: _currentWarden!.uid)
          .where('action', isEqualTo: AuditAction.leave_approved.value)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

     final requestIds = snapshot.docs
    .map((doc) => (doc.data() as Map<String, dynamic>)['targetId'] as String)
    .toList();
      if (requestIds.isNotEmpty) {
        final requests = await _leaveRequestsRef
            .where(FieldPath.documentId, whereIn: requestIds)
            .get();

        _recentApprovals = requests.docs
            .map((doc) => LeaveRequest.fromFirestore(doc.data()! as Map<String, dynamic>, doc.id))
            .toList();
      }
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
    } catch (e, stackTrace) {
      debugPrint('Error fetching recent approvals: $e\n$stackTrace');
    }
  }

  Future<bool> verifyParentContact(String leaveRequestId, VerificationMethod method) async {
    try {
      // In real implementation, this would:
      // 1. Call/SMS parent based on method
      // 2. Verify response
      // For now, just simulate success
      return true;
    } catch (e) {
      debugPrint('Parent verification failed: $e');
      return false;
    }
  }

  Future<void> approveHomeLeave({
    required String leaveRequestId,
    required VerificationMethod verificationMethod,
    String? verificationCode,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Verify warden role
      if (_currentWarden == null) {
        throw Exception('Warden not authenticated');
      }

      // Find the leave request
      final leaveRequest = _pendingHomeRequests.firstWhere(
        (req) => req.id == leaveRequestId,
        orElse: () => throw Exception('Leave request not found'),
      );

      // Generate secure QR secret (but don't create trip yet)
      final qrSecret = _generateSecureSecret();
      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      // Update leave request
      batch.update(_leaveRequestsRef.doc(leaveRequestId), {
        'status': LeaveStatus.approved.value,
        'approvedBy': {
          'wardenId': _currentWarden!.uid,
          'name': _currentWarden!.name,
          'timestamp': now,
        },
        'qrSecret': qrSecret,
        'parentVerifiedAt': now,
        'verificationMethod': verificationMethod.value,
        'updatedAt': now,
      });

      // Create audit log
      final auditLog = AuditLog.leaveApproval(
        id: _auditLogsRef.doc().id,
        performedBy: _currentWarden!.uid,
        performerRole: UserRole.warden,
        leaveRequestId: leaveRequestId,
      );
      batch.set(_auditLogsRef.doc(auditLog.id), auditLog.toMap());

      // Create notification for student
      final notificationDoc = _notificationsRef.doc();
      batch.set(notificationDoc, {
        'userId': leaveRequest.studentUid,
        'title': 'Leave Approved',
        'body': 'Your home leave request has been approved',
        'relatedLeaveId': leaveRequestId,
        'isRead': false,
        'createdAt': now,
        'type': NotificationType.leave_approved.toString(),
        'data': {
          'qrSecret': qrSecret,
        },
      });

      await batch.commit();

      // Update local state
      _pendingHomeRequests.removeWhere((req) => req.id == leaveRequestId);
      _recentApprovals.insert(0, leaveRequest);
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
      rethrow;
    } catch (e, stackTrace) {
      _error = 'Failed to approve leave request';
      debugPrint('Error approving leave: $e\n$stackTrace');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectHomeLeave(String leaveRequestId, String reason) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_currentWarden == null) {
        throw Exception('Warden not authenticated');
      }

      final leaveRequest = _pendingHomeRequests.firstWhere(
        (req) => req.id == leaveRequestId,
        orElse: () => throw Exception('Leave request not found'),
      );

      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      // Update leave request
      batch.update(_leaveRequestsRef.doc(leaveRequestId), {
        'status': LeaveStatus.rejected.value,
        'rejectedBy': {
          'wardenId': _currentWarden!.uid,
          'name': _currentWarden!.name,
          'timestamp': now,
        },
        'rejectionReason': reason,
        'updatedAt': now,
      });

      // Create audit log
      final auditLog = AuditLog(
        id: _auditLogsRef.doc().id,
        action: AuditAction.leave_rejected,
        performedBy: _currentWarden!.uid,
        performerRole: UserRole.warden,
        metadata: {
          'leaveRequestId': leaveRequestId,
          'reason': reason,
        },
      );
      batch.set(_auditLogsRef.doc(auditLog.id), auditLog.toMap());

      // Create notification
      final notificationDoc = _notificationsRef.doc();
      batch.set(notificationDoc, {
        'userId': leaveRequest.studentUid,
        'title': 'Leave Rejected',
        'body': 'Your leave request was rejected: $reason',
        'relatedLeaveId': leaveRequestId,
        'isRead': false,
        'createdAt': now,
        'type': NotificationType.leave_rejected.toString(),
      });

      await batch.commit();

      // Update local state
      _pendingHomeRequests.removeWhere((req) => req.id == leaveRequestId);
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
      rethrow;
    } catch (e, stackTrace) {
      _error = 'Failed to reject leave request';
      debugPrint('Error rejecting leave: $e\n$stackTrace');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> notifyOverdueStudent(String leaveRequestId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final leaveRequest = _overdueRequests.firstWhere(
        (req) => req.id == leaveRequestId,
        orElse: () => throw Exception('Leave request not found'),
      );

      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      // Mark as notified
      batch.update(_leaveRequestsRef.doc(leaveRequestId), {
        'overdueNotified': true,
        'overdueNotifiedAt': now,
      });

      // Create notification
      final notificationDoc = _notificationsRef.doc();
      batch.set(notificationDoc, {
        'userId': leaveRequest.studentUid,
        'title': 'Overdue Leave',
        'body': 'You have not returned from your leave as scheduled',
        'relatedLeaveId': leaveRequestId,
        'isRead': false,
        'createdAt': now,
        'type': NotificationType.overdue_warning.value.toString(),
        'data': {
          'expectedReturn': leaveRequest.returnTimePlanned?.toIso8601String(),
        },
      });

      // Create audit log
      final auditLog = AuditLog(
        id: _auditLogsRef.doc().id,
        action: AuditAction.values.firstWhere(
  (e) => e.value == 'overdue_notification',
  orElse: () => AuditAction.leave_created,
),
        performedBy: _currentWarden?.uid ?? 'system',
        performerRole: UserRole.warden,
        metadata: {
          'leaveRequestId': leaveRequestId,
          'studentId': leaveRequest.studentUid,
        },
      );
      batch.set(_auditLogsRef.doc(auditLog.id), auditLog.toMap());

      await batch.commit();

      // Update local state
      _overdueRequests.removeWhere((req) => req.id == leaveRequestId);
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
      rethrow;
    } catch (e, stackTrace) {
      _error = 'Failed to notify student';
      debugPrint('Error notifying student: $e\n$stackTrace');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> exportLeaveData({
    DateTime? startDate,
    DateTime? endDate,
    String? hostelName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _leaveRequestsRef.orderBy('createdAt', descending: true);

      if (startDate != null && endDate != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      if (hostelName != null && _currentWarden?.managesHostel(hostelName) == true) {
        query = query.where('hostelName', isEqualTo: hostelName);
      }

      final snapshot = await query.get();
      final csvData = _formatExportData(snapshot.docs);

      // Log export action
      await _auditLogsRef.add({
        'action': AuditAction.data_exported.value,
        'performedBy': _currentWarden?.uid,
        'performerRole': UserRole.warden.value,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'range': '${startDate?.toIso8601String()} - ${endDate?.toIso8601String()}',
          'hostel': hostelName,
          'recordCount': snapshot.docs.length,
        },
      });

      return csvData;
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
      rethrow;
    } catch (e, stackTrace) {
      _error = 'Export failed';
      debugPrint('Error exporting data: $e\n$stackTrace');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper Methods

  String _formatExportData(List<DocumentSnapshot> docs) {
    final csvData = StringBuffer()
      ..writeln('Request ID,Student Name,Roll No,Type,Status,Exit Time,Return Time,Approved By');
    
    for (final doc in docs) {
      final data = doc.data()! as Map<String, dynamic>;
      csvData.writeln([
        doc.id,
        data['studentName'],
        data['studentRoll'],
        data['type'],
        data['status'],
        (data['exitTimePlanned'] as Timestamp?)?.toDate().toString(),
        (data['returnTimePlanned'] as Timestamp?)?.toDate().toString(),
        (data['approvedBy'] as Map<String, dynamic>?)?['name'],
      ].join(','));
    }

    return csvData.toString();
  }

  String _generateSecureSecret() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  void _handleFirebaseError(FirebaseException e) {
    _isOffline = e.code == 'unavailable';
    _error = _isOffline 
        ? 'Offline: Data may be outdated' 
        : 'Operation failed: ${e.message}';
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}