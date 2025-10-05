
import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student.dart';
import '../models/leave_request.dart';
import '../models/trip.dart';
import '../models/notification.dart';
import '../models/emergency_contact.dart';

import '../models/enums.dart';
import 'dart:convert'; 
import '../models/guard.dart';
import '../models/warden.dart';

import '../services/qr_service.dart';

class StudentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;
  final List<StreamSubscription> _subscriptions = [];

  // State
  Student? _student;
  List<LeaveRequest> _leaveRequests = [];
  List<Trip> _trips = [];
  List<Notification> _notifications = [];
  EmergencyContact? _emergencyContact;
  Warden? _warden;
  Guard? _guard;
  bool _isLoading = false;
  String? _error;
  String? _currentQRData;
  DateTime? _qrExpiry;

  // Getters
  Student? get student => _student;
  List<LeaveRequest> get leaveRequests => _leaveRequests;
  List<Trip> get trips => _trips;
  List<Notification> get notifications => _notifications;
  EmergencyContact? get emergencyContact => _emergencyContact;
  Warden? get warden => _warden;
  Guard? get guard => _guard;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentQRData => _currentQRData;
  DateTime? get qrExpiry => _qrExpiry;
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  StudentProvider({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Initialize all real-time listeners
  Future<void> initialize(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _cancelAllSubscriptions();
      await _fetchInitialStudentData(uid);
      
      if (_student != null) {
        _setupLeaveRequestListener(_student!.uid);
        _setupTripListener(_student!.uid);
        _setupNotificationListener(_student!.uid);
        _setupEmergencyContactListener(_student!.uid);
      
      }
    } catch (e) {
      _error = "Failed to initialize: ${e.toString()}";
      debugPrint('Initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== Core Data Fetching ====================
Future<void> _fetchInitialStudentData(String uid) async {
  try {
    debugPrint('Fetching student data for UID: $uid');
    
    // 1. ONLY look up by UID in students collection
    final studentQuery = await _firestore.collection('students')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (studentQuery.docs.isEmpty) {
      throw Exception('Student document not found for UID: $uid');
    }

    final doc = studentQuery.docs.first;
    _student = Student.fromFirestore(doc.data(), doc.id);
    debugPrint('Student loaded successfully: ${_student?.name}');
    
  } catch (e, stack) {
    debugPrint('Student data fetch error: $e\n$stack');
    rethrow;
  }
}
  Future<void> refreshAllData() async {
  if (_student == null) return;
  await initialize(_student!.uid);
}

void printDebugInfo() {
  debugPrint('=== Student Provider Debug Info ===');
  debugPrint('- Student: ${_student?.toMap()}');
  debugPrint('- Leave Requests: ${_leaveRequests.length}');
  debugPrint('- Trips: ${_trips.length}');
  debugPrint('- Notifications: ${_notifications.length}');
  debugPrint('- Emergency Contact: ${_emergencyContact?.toMap()}');
  debugPrint('- Warden: ${_warden?.toMap()}');
  debugPrint('- Guard: ${_guard?.toMap()}');
  debugPrint('==================================');
}

Future<void> verifyFirestoreAccess() async {
  try {
    debugPrint('Testing Firestore access...');
    final testDoc = await _firestore.collection('test').doc('test').get();
    debugPrint('Firestore access successful: ${testDoc.exists}');
  } catch (e) {
    debugPrint('Firestore access failed: $e');
    rethrow;
  }
}


  // ==================== Real-Time Listeners ====================
  void _setupLeaveRequestListener(String uid) {
    final sub = _firestore.collection('leaveRequests')
        .where('studentUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          _leaveRequests = snapshot.docs
              .map((doc) => LeaveRequest.fromFirestore(doc.data(), doc.id))
              .toList();
          notifyListeners();
        });
    _subscriptions.add(sub);
  }

  void _setupTripListener(String uid) {
    final sub = _firestore.collection('trips')
        .where('studentUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          _trips = snapshot.docs
              .map((doc) => Trip.fromFirestore(doc.data(), doc.id))
              .toList();
          notifyListeners();
        });
    _subscriptions.add(sub);
  }

  void _setupNotificationListener(String uid) {
    final sub = _firestore.collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          _notifications = snapshot.docs
              .map((doc) => Notification.fromFirestore(doc.data(), doc.id))
              .toList();
          notifyListeners();
        });
    _subscriptions.add(sub);
  }

  void _setupEmergencyContactListener(String uid) {
    final sub = _firestore.collection('emergencyContacts')
        .where('studentUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          _emergencyContact = snapshot.docs.isNotEmpty
              ? EmergencyContact.fromFirestore(snapshot.docs.first.data(), snapshot.docs.first.id)
              : null;
          notifyListeners();
        });
    _subscriptions.add(sub);
  }

  

  // ==================== Student Operations ====================
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? parentPhone,
    String? email,
    String? branch,
    int? year,
    String? hostelName,
    String? roomNumber,
    int? floorNumber,
    String? photoUrl,
    String? emergencyContact,
  }) async {
    if (_student == null) throw Exception('Student not loaded');

    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (parentPhone != null) updates['parentPhone'] = parentPhone;
      if (email != null) updates['email'] = email;
      if (branch != null) updates['branch'] = branch;
      if (year != null) updates['year'] = year;
      if (hostelName != null) updates['hostelName'] = hostelName;
      if (roomNumber != null) updates['roomNumber'] = roomNumber;
      if (floorNumber != null) updates['floorNumber'] = floorNumber;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (emergencyContact != null) updates['emergencyContact'] = emergencyContact;

      await _firestore.collection('students').doc(_student!.rollNumber).update(updates);

      // Local state will update automatically via the listener
    } catch (e) {
      _error = "Failed to update profile: ${e.toString()}";
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadProfilePhoto(String imageUrl) async {
    if (_student == null) throw Exception('Student not loaded');
    await updateProfile(photoUrl: imageUrl);
  }

  Future<void> uploadTimetable(String imageUrl) async {
    if (_student == null) throw Exception('Student not loaded');

    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('students').doc(_student!.rollNumber).update({
        'timetableImageUrl': imageUrl,
        'timetableLastUpdated': FieldValue.serverTimestamp(),
      });

      // Local state will update automatically via the listener
    } catch (e) {
      _error = "Failed to upload timetable: ${e.toString()}";
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTimetable() async {
    if (_student == null) throw Exception('Student not loaded');

    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('students').doc(_student!.rollNumber).update({
        'timetableImageUrl': FieldValue.delete(),
        'timetableLastUpdated': FieldValue.delete(),
      });

      // Local state will update automatically via the listener
    } catch (e) {
      _error = "Failed to delete timetable: ${e.toString()}";
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== Leave Request Operations ====================
  Future<String> submitLeaveRequest({
    required LeaveType type,
    required String reason,
    required DateTime exitTime,
    DateTime? returnTime,
    List<String>? attachmentUrls,
  }) async {
    if (_student == null) throw Exception('Student not loaded');

    try {
      _isLoading = true;
      notifyListeners();

      // Validate leave request parameters
      _validateLeaveRequest(
        type: type,
        exitTime: exitTime,
        returnTime: returnTime,
        attachmentUrls: attachmentUrls,
      );

      // Check for existing active leave
      if (_student!.hasActiveLeave) {
        throw Exception('You already have an active leave request');
      }

      final leaveRequestRef = _firestore.collection('leaveRequests').doc();
      final tripRef = _firestore.collection('trips').doc(leaveRequestRef.id);

      final leaveRequest = LeaveRequest(
        id: leaveRequestRef.id,
        studentUid: _student!.uid,
        studentRoll: _student!.rollNumber,
        studentName: _student!.name,
        hostelName: _student!.hostelName,
        type: type,
        reason: reason,
        exitTimePlanned: exitTime,
        returnTimePlanned: returnTime,
        status: LeaveStatus.pending_guard,
        parentApproved: type == LeaveType.day,
        parentConsentUrl: type == LeaveType.home ? attachmentUrls?.first : null,
        createdAt: DateTime.now(),
        tripId: leaveRequestRef.id,
      );

      final trip = Trip(
        id: leaveRequestRef.id,
        studentUid: _student!.uid,
        studentRoll: _student!.rollNumber,
        studentName: _student!.name,
        hostelName: _student!.hostelName,
        leaveRequestId: leaveRequestRef.id,
        leaveType: type,
        expectedReturn: returnTime,
        isCompleted: false,
        createdAt: DateTime.now(),
        gateEvents: [],
      );

      // Batch write
      final batch = _firestore.batch();
      batch.set(leaveRequestRef, leaveRequest.toMap());
      batch.set(tripRef, trip.toMap());
      await batch.commit();

      return leaveRequestRef.id;
    } catch (e) {
      _error = "Failed to submit leave request: ${e.toString()}";
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _validateLeaveRequest({
    required LeaveType type,
    required DateTime exitTime,
    DateTime? returnTime,
    List<String>? attachmentUrls,
  }) {
    if (exitTime.isBefore(DateTime.now().add(Duration(minutes: 5)))) {
      throw Exception('Leave must be requested at least 5 minutes in advance');
    }

    if (type == LeaveType.home) {
      if (returnTime == null) {
        throw Exception('Return time required for home leave');
      }
      if (returnTime.isBefore(exitTime.add(Duration(hours: 12)))) {
        throw Exception('Home leave must be at least 12 hours');
      }
      if (attachmentUrls?.isEmpty ?? true) {
        throw Exception('Parent consent required for home leave');
      }
    }
  }

  Future<void> cancelLeaveRequest(String requestId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('leaveRequests').doc(requestId).update({
        'status': LeaveStatus.rejected.name,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _student?.rollNumber,
      });

      // Local state will update via listener
    } catch (e) {
      _error = "Failed to cancel leave request: ${e.toString()}";
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== QR Code Operations ====================
 // lib/providers/student_provider.dart
Future<String> generateLeaveQR(String leaveRequestId) async {
  final request = _leaveRequests.firstWhere((lr) => lr.id == leaveRequestId);
  if (request.qrSecret == null) throw Exception('QR secret not initialized');

  final payload = {
    'v': 2,
    'sid': _student!.uid,
    'lid': leaveRequestId,
    'tid': request.tripId,
    't': DateTime.now().millisecondsSinceEpoch,
    'h': QrService.generateHmacHash(
      secret: request.qrSecret!,
      tripId: request.tripId,
      studentId: _student!.uid,
    ),
    'exp': request.returnTimePlanned?.millisecondsSinceEpoch ?? 
          request.exitTimePlanned.add(Duration(hours: 24)).millisecondsSinceEpoch,
  };

  return jsonEncode(payload);
}


  String _generateSecureHash(String studentId, String leaveId) {
    final timeSalt = DateTime.now().millisecondsSinceEpoch ~/ (1000 * 60 * 5);
    return '$studentId-$leaveId-$timeSalt-${_student?.rollNumber}'.hashCode.toString();
  }

  Future<bool> validateQR(String scannedData) async {
    try {
      final payload = jsonDecode(scannedData) as Map<String, dynamic>;
      if (payload['v'] != 2) return false;
      
      // Validate hash
      final expectedHash = _generateSecureHash(
        payload['sid'] as String,
        payload['lid'] as String
      );
      
      if (payload['h'] != expectedHash) return false;
      
      // Validate expiry
      final expiry = DateTime.fromMillisecondsSinceEpoch(payload['exp'] as int);
      if (DateTime.now().isAfter(expiry)) return false;
      
      // Validate leave status
      return _leaveRequests.any((lr) => 
        lr.id == payload['lid'] && 
        lr.status == LeaveStatus.active
      );
    } catch (_) {
      return false;
    }
  }

  // ==================== Notification Operations ====================
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
      
      // Local state will update via listener
    } catch (e) {
      _error = "Failed to mark notification as read: ${e.toString()}";
      rethrow;
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      final batch = _firestore.batch();
      for (final notification in _notifications.where((n) => !n.isRead)) {
        final ref = _firestore.collection('notifications').doc(notification.id);
        batch.update(ref, {'isRead': true});
      }
      await batch.commit();
      
      // Local state will update via listener
    } catch (e) {
      _error = "Failed to mark all notifications as read: ${e.toString()}";
      rethrow;
    }
  }

  // ==================== Helper Methods ====================
  void _cancelAllSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearAllData() {
    _student = null;
    _leaveRequests = [];
    _trips = [];
    _notifications = [];
    _emergencyContact = null;
    _warden = null;
    _guard = null;
    _currentQRData = null;
    _qrExpiry = null;
    _cancelAllSubscriptions();
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelAllSubscriptions();
    super.dispose();
  }
}