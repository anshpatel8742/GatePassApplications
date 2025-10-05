import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/trip.dart';
import '../models/leave_request.dart';
import '../models/enums.dart' as Enums;
import '../models/gate_event.dart';
import '../services/qr_service.dart';
import '../models/qr_payload.dart';

class TripProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;
  
  final List<Trip> _trips = [];
  bool _isScanning = false;
  String? _lastScanError;
  bool _isOffline = false;
  DateTime? _lastScanTime;
  Trip? _lastProcessedTrip;
  String _currentGuardId = '';
  String _deviceId = '';

  TripProvider({FirebaseFirestore? firestore}) 
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Getters
  bool get isScanning => _isScanning;
  String? get lastScanError => _lastScanError;
  bool get isOffline => _isOffline;
  DateTime? get lastScanTime => _lastScanTime;
  Trip? get lastProcessedTrip => _lastProcessedTrip;
  String get currentGuardId => _currentGuardId;
  String get deviceId => _deviceId;

  void initializeGuardSession(String guardId, String deviceId) {
    _currentGuardId = guardId;
    _deviceId = deviceId;
    notifyListeners();
  }

// For prototype - bypass the initialization check
bool get isInitialized => true;

  Future<Trip> getTrip(String tripId, {Source source = Source.server}) async {
    try {
      final doc = await _firestore.collection('trips')
        .doc(tripId)
        .get(GetOptions(source: source));
      
      if (!doc.exists) throw TripNotFoundException(tripId);

      return Trip.fromFirestore(doc.data()!, doc.id);
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        _isOffline = true;
        notifyListeners();
        return getTrip(tripId, source: Source.cache);
      }
      rethrow;
    }
  }

  Stream<Trip> watchTrip(String tripId) {
    return _firestore.collection('trips').doc(tripId)
      .snapshots()
      .handleError((error) {
        _isOffline = true;
        notifyListeners();
        return _firestore.collection('trips').doc(tripId)
          .get(GetOptions(source: Source.cache))
          .asStream()
          .map((doc) => Trip.fromFirestore(doc.data()!, doc.id));
      })
      .map((doc) {
        if (!doc.exists) throw TripNotFoundException(tripId);
        return Trip.fromFirestore(doc.data()!, doc.id);
      });
  }

  Enums.GateEventType? getNextExpectedEvent(String tripId) {
    final trip = _trips.firstWhere((t) => t.id == tripId);
    return trip.nextExpectedEvent;
  }

  Future<ScanResult> processGateScan({
    required String qrData,
    required Enums.GateEventType attemptedEventType,
  }) async {
    // if (_currentGuardId.isEmpty || _deviceId.isEmpty) {
    //   throw StateError('Guard session not initialized');
    // }

    try {
      final payload = QrPayload.fromJson(qrData);
      final trip = await getTrip(payload.tripId);

      if (!QrService.validateHmac(
        secret: trip.qrSecret!,
        receivedHash: payload.hash,
        tripId: payload.tripId,
        studentId: payload.studentId,
      )) {
        throw InvalidQRHashException();
      }

      final nextEvent = trip.nextExpectedEvent;
      if (nextEvent != attemptedEventType) {
        throw GateSequenceException(
          expected: nextEvent,
          actual: attemptedEventType,
          currentStatus: trip.sequenceStatus,
        );
      }

      await _logGateEvent(
        trip: trip,
        eventType: attemptedEventType,
        qrHash: payload.hash,
      );

      _lastProcessedTrip = trip;
      return ScanResult.success(trip);
    } on FormatException {
      throw MalformedQRException();
    } on FirebaseException catch (e) {
      throw ScanException('Network error: ${e.message}');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> _logGateEvent({
    required Trip trip,
    required Enums.GateEventType eventType,
    required String qrHash,
    GeoPoint? location,
  }) async {
    final batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();
    
      // PROTOTYPE MODE: Use fallback values for missing fields
    final String guardId = _currentGuardId.isNotEmpty ? _currentGuardId : 'prototype_guard';
    final String deviceId = _deviceId.isNotEmpty ? _deviceId : 'prototype_device';

    final eventData = {
      'type': eventType.value,
      'time': timestamp,
      'guardId': _currentGuardId,
      'deviceId': _deviceId,
      'qrHash': qrHash,
      if (location != null) 'location': location,
    };

    batch.update(trip.tripDocumentRef, {
      'gateEvents': FieldValue.arrayUnion([eventData]),
      'updatedAt': timestamp,
      if (eventType.isExit) 'currentLocation': location,
      if (eventType == Enums.GateEventType.hostel_entry) 'isCompleted': true,
    });

    if (eventType == Enums.GateEventType.hostel_entry) {
      batch.update(trip.leaveRequestDocumentRef, {
        'status': Enums.LeaveStatus.completed.value,
        'updatedAt': timestamp,
      });
    }

    final auditRef = _firestore.collection('gateAuditLogs').doc();
    batch.set(auditRef, {
      'tripId': trip.id,
      'leaveRequestId': trip.leaveRequestId,
      'studentId': trip.studentUid,
      'eventType': eventType.value,
      'guardId': _currentGuardId,
      'deviceId': _deviceId,
      'qrHash': qrHash,
      'timestamp': timestamp,
      if (location != null) 'location': location,
      'status': 'success',
    });

    await batch.commit();
  }

 Stream<List<Trip>> watchActiveTrips({String? hostelName}) {
  Query query = _firestore.collection('trips')
    .where('isCompleted', isEqualTo: false)
    .orderBy('updatedAt', descending: true);

  if (hostelName != null) {
    query = query.where('hostelName', isEqualTo: hostelName);
  }

  return query.snapshots().map((snap) => snap.docs
      .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Trip.fromFirestore(data, doc.id);
      })
      .where((trip) => trip.sequenceStatus != Enums.SequenceStatus.invalid)
      .toList());
}

  Stream<List<Trip>> watchOverdueTrips({
    String? hostelName,
    Duration tolerance = const Duration(minutes: 15),
  }) {
    return watchActiveTrips(hostelName: hostelName).map((trips) => trips.where((trip) {
      if (!trip.isActive) return false;
      final expectedReturn = trip.expectedReturn ?? 
          trip.hostelExitTime?.add(const Duration(hours: 8));
      return expectedReturn != null &&
          DateTime.now().isAfter(expectedReturn.add(tolerance));
    }).toList());
  }

  Future<void> recallStudent(String tripId) async {
    try {
      final trip = await getTrip(tripId);
      
      if (trip.isCompleted) {
        throw StateError('Cannot recall - trip already completed');
      }

      await _firestore.collection('trips').doc(tripId).update({
        'status': Enums.LeaveStatus.recalled.value,
        'recalledBy': _currentGuardId,
        'recalledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('leaveRequests').doc(trip.leaveRequestId).update({
        'status': Enums.LeaveStatus.recalled.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to recall student: $e');
      rethrow;
    }
  }

  void clearError() {
    _lastScanError = null;
    notifyListeners();
  }

  void resetScanState() {
    _isScanning = false;
    _lastScanError = null;
    _lastProcessedTrip = null;
    notifyListeners();
  }
}

class ScanResult {
  final Trip? trip;
  final ScanException? error;

  ScanResult.success(this.trip) : error = null;
  ScanResult.failure(this.error) : trip = null;

  bool get isSuccess => error == null;
}

class ScanException implements Exception {
  final String message;
  ScanException(this.message);
}

class TripNotFoundException extends ScanException {
  TripNotFoundException(String tripId) : super('Trip $tripId not found');
}

class InvalidQRVersionException extends ScanException {
  InvalidQRVersionException() : super('Invalid QR code version');
}

class QRExpiredException extends ScanException {
  QRExpiredException() : super('QR code has expired');
}

class MalformedQRException extends ScanException {
  MalformedQRException() : super('Invalid QR code format');
}

class InvalidQRHashException extends ScanException {
  InvalidQRHashException() : super('QR code verification failed');
}

class GuardNotAuthorizedException extends ScanException {
  GuardNotAuthorizedException(Enums.UserRole role) 
    : super('${role.name} not authorized for this action');
}

class GateSequenceException implements Exception {
  final Enums.GateEventType? expected;
  final Enums.GateEventType actual;
  final Enums.SequenceStatus currentStatus;
  
  GateSequenceException({
    required this.expected,
    required this.actual,
    required this.currentStatus,
  });
  
  @override
  String toString() {
    return 'Expected $expected but got $actual. Current status: $currentStatus';
  }
}

class TripIntegrityException extends ScanException {
  TripIntegrityException(String message) : super(message);
}