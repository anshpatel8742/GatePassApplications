import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/leave_request.dart';
import '../models/enums.dart';
import 'trip_provider.dart';

class GuardProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;
  final TripProvider _tripProvider;
  
  // Guard information
  UserRole _role;
  String _guardId;
  String? _hostelName;
  String _firstName = '';
  String _lastName = '';


  

  // State
  List<LeaveRequest> _pendingRequests = [];
  List<Trip> _activeTrips = [];
  List<Trip> _overdueTrips = [];
  bool _isLoading = false;
  String? _lastError;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _requestsSubscription;
  StreamSubscription<QuerySnapshot>? _tripsSubscription;
  StreamSubscription<QuerySnapshot>? _overdueSubscription;

  // Getters
  List<LeaveRequest> get pendingRequests => _pendingRequests;
  List<Trip> get activeTrips => _activeTrips;
  List<Trip> get overdueTrips => _overdueTrips;
  List<Trip> get recentTrips => _activeTrips;
  UserRole get role => _role;
  String get guardId => _guardId;
  String get guardName => '$_firstName $_lastName';
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
bool get isInitialized => _guardId.isNotEmpty && _role != null;


int get todayApprovals {
  final today = DateTime.now();
  return _pendingRequests.where((r) => 
    r.hostelGuardApprovedAt?.year == today.year &&
    r.hostelGuardApprovedAt?.month == today.month &&
    r.hostelGuardApprovedAt?.day == today.day).length;
}

  GuardProvider({
    required UserRole role,
    required String guardId,
    String? hostelName,
    FirebaseFirestore? firestore,
    TripProvider? tripProvider,
  }) : _role = role,
       _guardId = guardId,
       _hostelName = hostelName,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _tripProvider = tripProvider ?? TripProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _setupRealTimeListeners();
  }

  void updateGuardData({
    required UserRole role,
    required String guardId,
    String? firstName,
    String? lastName,
    String? hostelName,
  }) {
    _role = role;
    _guardId = guardId;
    _firstName = firstName ?? _firstName;
    _lastName = lastName ?? _lastName;
    _hostelName = hostelName ?? _hostelName;
    
    // Restart listeners with new credentials
    _setupRealTimeListeners();
    notifyListeners();
  }

  void _setupRealTimeListeners() {
    // Cancel existing subscriptions
    _requestsSubscription?.cancel();
    _tripsSubscription?.cancel();
    _overdueSubscription?.cancel();

    // Set up new subscriptions
    _requestsSubscription = _createRequestsQuery().snapshots().listen((snapshot) {
      _pendingRequests = snapshot.docs.map((doc) {
        return LeaveRequest.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      notifyListeners();
    }, onError: (error) {
      _lastError = 'Failed to load pending requests: $error';
      notifyListeners();
    });

    _tripsSubscription = _createActiveTripsQuery().snapshots().listen((snapshot) {
      _activeTrips = snapshot.docs.map((doc) {
        return Trip.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      notifyListeners();
    }, onError: (error) {
      _lastError = 'Failed to load active trips: $error';
      notifyListeners();
    });

    _overdueSubscription = _createOverdueQuery().snapshots().listen((snapshot) {
      _overdueTrips = snapshot.docs.map((doc) {
        return Trip.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      notifyListeners();
    }, onError: (error) {
      _lastError = 'Failed to load overdue trips: $error';
      notifyListeners();
    });
  }

  Query<Map<String, dynamic>> _createRequestsQuery() {
    return _firestore.collection('leaveRequests')
      .where('hostelName', isEqualTo: _hostelName)
      .where('status', isEqualTo: 'pending_guard') // Only show requests needing guard approval
      .orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _createActiveTripsQuery() {
    return _firestore.collection('trips')
      .where('isCompleted', isEqualTo: false)
      .where('hostelName', isEqualTo: _hostelName)
      .orderBy('hostelExit.time', descending: true);
  }

  Query<Map<String, dynamic>> _createOverdueQuery() {
    return _firestore.collection('trips')
      .where('isCompleted', isEqualTo: false)
      .where('hostelName', isEqualTo: _hostelName)
      .where('expectedReturn', isLessThan: DateTime.now())
      .orderBy('expectedReturn', descending: true);
  }

// lib/providers/guard_provider.dart
Future<void> approveLeaveRequest(String requestId) async {
  final batch = _firestore.batch();
  final leaveRef = _firestore.collection('leaveRequests').doc(requestId);
  final tripRef = _firestore.collection('trips').doc(requestId);

  // Generate crypto-secure secret
  final qrSecret = _generateCryptoRandomString(32);

  // Update both documents atomically
  batch.update(leaveRef, {
    'status': 'approved',
    'hostelGuardApproved': true,
    'hostelGuardApprovedAt': FieldValue.serverTimestamp(),
    'qrSecret': qrSecret, // Temporary storage
  });

  batch.set(tripRef, {
    'qrSecret': qrSecret, // Primary storage
    'createdAt': FieldValue.serverTimestamp(),
    'status': 'awaiting_exit',
  }, SetOptions(merge: true));

  await batch.commit();
}

String _generateCryptoRandomString(int length) {
  final random = Random.secure();
  return base64Url.encode(List.generate(length, (i) => random.nextInt(256)));
}


  Future<void> rejectLeaveRequest(String requestId, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('leaveRequests').doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Immediately update local state
      _pendingRequests.removeWhere((req) => req.id == requestId);
    } catch (e) {
      _lastError = 'Rejection failed: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> refreshData() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Force refresh by restarting listeners
      _setupRealTimeListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<Trip>> searchTrips({
    String query = '',
    DateTimeRange? dateRange,
    bool showOverdue = false,
    LeaveType? leaveType,
  }) {
    Query queryRef = _firestore.collection('trips')
      .where('hostelName', isEqualTo: _hostelName)
      .orderBy('hostelExit.time', descending: true);

    if (query.isNotEmpty) {
      queryRef = queryRef
          .where('studentRoll', isGreaterThanOrEqualTo: query)
          .where('studentRoll', isLessThan: '${query}z');
    }

    if (dateRange != null) {
      queryRef = queryRef
          .where('hostelExit.time', isGreaterThanOrEqualTo: dateRange.start)
          .where('hostelExit.time', isLessThanOrEqualTo: dateRange.end);
    }

    if (showOverdue) {
      queryRef = queryRef
          .where('expectedReturn', isLessThan: DateTime.now())
          .where('isCompleted', isEqualTo: false);
    }

    if (leaveType != null) {
      queryRef = queryRef.where('leaveType', isEqualTo: leaveType.value);
    }

    return queryRef.snapshots().map((snapshot) => 
        snapshot.docs.map((doc) => Trip.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  LeaveRequest? getLeaveRequestForTrip(String tripId) {
    try {
      return _pendingRequests.firstWhere((req) => req.tripId == tripId);
    } catch (_) {
      return null;
    }
  }

  String _generateQrSecret() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }


   Future<void> notifyOverdueStudent(String tripId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final trip = await _tripProvider.getTrip(tripId);
      await _firestore.collection('notifications').add({
        'type': 'overdue_warning',
        'tripId': tripId,
        'studentId': trip.studentUid,
        'guardId': _guardId,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Student ${trip.studentName} (${trip.studentRoll}) is overdue',
        'status': 'pending',
      });
    } catch (e) {
      _lastError = 'Failed to send notification: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _tripsSubscription?.cancel();
    _overdueSubscription?.cancel();
    super.dispose();
  }
}