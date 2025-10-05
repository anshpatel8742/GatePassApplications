import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'enums.dart';


class Trip {
  final String id;
  final String studentUid;
  final String studentRoll;
  final String studentName;
  final String hostelName;
  final String leaveRequestId;
  final DocumentReference<Object?>? leaveRequestRef;
  final List<Map<String, dynamic>> gateEvents;
  bool isCompleted;
  final LeaveType leaveType;
  final DateTime? expectedReturn;
  final DateTime createdAt;
  DateTime? updatedAt;
  final String? qrSecret;
   GeoPoint? _currentLocation;  // Made private with getter
  String? _currentStatusMessage;  // Made private with getter
  final DeviceType deviceType;
  AuditAction? _lastAuditAction;  // Made private with getter


  Trip({
    required this.id,
    required this.studentUid,
    required this.studentRoll,
    required this.studentName,
    required this.hostelName,
    required this.leaveRequestId,
    this.leaveRequestRef,
    List<Map<String, dynamic>>? gateEvents,
    bool? isCompleted,
    required this.leaveType,
    this.expectedReturn,
    DateTime? createdAt,
    this.updatedAt,
    this.qrSecret,
    GeoPoint? currentLocation,
    String? currentStatusMessage,
    this.deviceType = DeviceType.unknown,
    AuditAction? lastAuditAction,
  })  : gateEvents = gateEvents ?? [],
        isCompleted = isCompleted ?? false,
        createdAt = createdAt ?? DateTime.now(),
        _currentLocation = currentLocation,
        _currentStatusMessage = currentStatusMessage,
        _lastAuditAction = lastAuditAction;

   // Getters for final fields
  GeoPoint? get currentLocation => _currentLocation;
  String? get currentStatusMessage => _currentStatusMessage;
  AuditAction? get lastAuditAction => _lastAuditAction;

  // Setters for private fields
  set currentLocation(GeoPoint? location) => _currentLocation = location;
  set currentStatusMessage(String? message) => _currentStatusMessage = message;
  set lastAuditAction(AuditAction? action) => _lastAuditAction = action;


  factory Trip.fromFirestore(Map<String, dynamic> data, String id) {
    return Trip(
      id: id,
      studentUid: data['studentUid'] as String,
      studentRoll: data['studentRoll'] as String,
      studentName: data['studentName'] as String,
      hostelName: data['hostelName'] as String,
      leaveRequestId: data['leaveRequestId'] as String,
     leaveRequestRef: data['leaveRequestRef'] as DocumentReference<Object?>?,
      gateEvents: List<Map<String, dynamic>>.from(data['gateEvents'] ?? []),
      isCompleted: data['isCompleted'] as bool? ?? false,
      leaveType: LeaveType.fromValue(data['leaveType'] as String),
      expectedReturn: data['expectedReturn'] != null
          ? (data['expectedReturn'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      qrSecret: data['qrSecret'] as String?,
      currentLocation: data['currentLocation'] != null
          ? GeoPoint(
              data['currentLocation']['latitude'],
              data['currentLocation']['longitude'],
            )
          : null,
      currentStatusMessage: data['currentStatusMessage'] as String?,
      deviceType: DeviceType.fromValue(data['deviceType'] ?? 'unknown'),
      lastAuditAction: data['lastAuditAction'] != null
          ? AuditAction.fromValue(data['lastAuditAction'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentUid': studentUid,
      'studentRoll': studentRoll,
      'studentName': studentName,
      'hostelName': hostelName,
      'leaveRequestId': leaveRequestId,
      if (leaveRequestRef != null) 'leaveRequestRef': leaveRequestRef,
      'gateEvents': gateEvents.map((e) => {
        'type': e['type'],
        'time': Timestamp.fromDate(e['time'] as DateTime),
        'guardId': e['guardId'],
        'deviceId': e['deviceId'],
        'qrHash': e['qrHash'],
        if (e['location'] != null) 'location': {
          'latitude': (e['location'] as GeoPoint).latitude,
          'longitude': (e['location'] as GeoPoint).longitude,
        },
        if (e['notes'] != null) 'notes': e['notes'],
      }).toList(),
      'isCompleted': isCompleted,
      'leaveType': leaveType.value,
      if (expectedReturn != null) 'expectedReturn': Timestamp.fromDate(expectedReturn!),
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (qrSecret != null) 'qrSecret': qrSecret,
       if (_currentLocation != null) 'currentLocation': {
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
      },
      if (_currentStatusMessage != null) 'currentStatusMessage': _currentStatusMessage,
      'deviceType': deviceType.value,
      if (_lastAuditAction != null) 'lastAuditAction': _lastAuditAction!.value,
      
    };
  }

  void logAuditAction(AuditAction action, {required UserRole performedBy, String? notes}) {
    final auditEvent = {
      'type': 'audit',
      'action': action.value,
      'performedBy': performedBy.value,
      'timestamp': DateTime.now(),
      if (notes != null) 'notes': notes,
    };

    gateEvents.add(auditEvent);
    updatedAt = DateTime.now();
  }

  SequenceStatus get sequenceStatus {
    final events = _extractEventTypes();
    
    if (events.isNotEmpty && events.first != GateEventType.hostel_exit) {
      return SequenceStatus.invalid;
    }
    
    if (events.length >= 4) {
      return _isCompleteSequenceValid(events) 
          ? SequenceStatus.completed 
          : SequenceStatus.invalid;
    }
    
    return _getPartialSequenceStatus(events);
  }

  List<GateEventType> _extractEventTypes() {
    return gateEvents
        .where((e) => e['type'] != 'audit')
        .map((e) => GateEventType.fromValue(e['type'] as String))
        .toList();
  }

  bool _isCompleteSequenceValid(List<GateEventType> events) {
    const validSequence = [
      GateEventType.hostel_exit,
      GateEventType.main_exit,
      GateEventType.main_entry,
      GateEventType.hostel_entry
    ];
    
    if (events.length != 4) return false;
    
    for (int i = 0; i < 4; i++) {
      if (events[i] != validSequence[i]) return false;
    }
    
    return true;
  }

bool validateQRHash(String hash, String deviceId) {
  try {
    final expectedHash = generateQRHash(deviceId);
    return hash == expectedHash;
  } catch (e) {
    return false;
  }
}
  SequenceStatus _getPartialSequenceStatus(List<GateEventType> events) {
    if (events.isEmpty) return SequenceStatus.pendingHostelExit;
    
    for (int i = 0; i < events.length; i++) {
      if (i == 0 && events[i] != GateEventType.hostel_exit) {
        return SequenceStatus.invalid;
      }
      if (i == 1 && events[i] != GateEventType.main_exit) {
        return SequenceStatus.invalid;
      }
      if (i == 2 && events[i] != GateEventType.main_entry) {
        return SequenceStatus.invalid;
      }
    }
    
    if (!events.contains(GateEventType.hostel_exit)) {
      return SequenceStatus.pendingHostelExit;
    }
    if (!events.contains(GateEventType.main_exit)) {
      return SequenceStatus.pendingMainExit;
    }
    if (!events.contains(GateEventType.main_entry)) {
      return SequenceStatus.pendingMainEntry;
    }
    return SequenceStatus.pendingHostelEntry;
  }

  GateEventType? get nextExpectedEvent {
    if (sequenceStatus == SequenceStatus.invalid) return null;
    
    final events = _extractEventTypes();
    if (events.isEmpty) return GateEventType.hostel_exit;
    if (events.length == 1) return GateEventType.main_exit;
    if (events.length == 2) return GateEventType.main_entry;
    if (events.length == 3) return GateEventType.hostel_entry;
    return null;
  }

  void validateSequenceIntegrity() {
    if (sequenceStatus == SequenceStatus.invalid) {
      throw TripIntegrityException('Invalid gate event sequence');
    }
  }

  void validateNextScan({
    required GateEventType eventType,
    required UserRole guardRole,
    required String qrHash,
  }) {
    if (isCompleted) {
      throw TripIntegrityException('Cannot scan - trip already completed');
    }

    final expected = nextExpectedEvent;
    if (expected != eventType) {
      throw GateSequenceException(
        expected: expected,
        actual: eventType,
        currentStatus: sequenceStatus,
      );
    }

    if (!_isGuardAuthorized(guardRole, eventType)) {
      throw GuardAuthorizationException(
        guardRole, 
        eventType,
        allowedEvents: _getAllowedEventsForGuard(guardRole),
      );
    }

    final duplicateEvent = gateEvents.firstWhereOrNull((e) => e['qrHash'] == qrHash);
    if (duplicateEvent != null) {
      throw DuplicateScanException(
        originalScanTime: (duplicateEvent['time'] as Timestamp).toDate(),
      );
    }
  }

  List<GateEventType> _getAllowedEventsForGuard(UserRole role) {
    switch (role) {
      case UserRole.hostelGuard:
        return [GateEventType.hostel_exit, GateEventType.hostel_entry];
      case UserRole.mainGuard:
        return [GateEventType.main_exit, GateEventType.main_entry];
      default:
        return [];
    }
  }

  bool _isGuardAuthorized(UserRole role, GateEventType event) {
    return _getAllowedEventsForGuard(role).contains(event);
  }

  DateTime? getEventTime(GateEventType type) {
    try {
      final event = gateEvents.firstWhere((e) => e['type'] == type.name);
      return (event['time'] as Timestamp).toDate();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? getEventData(GateEventType type) {
    return gateEvents.firstWhereOrNull((e) => e['type'] == type.name);
  }

  Map<String, dynamic>? get hostelExitEvent => getEventData(GateEventType.hostel_exit);
  Map<String, dynamic>? get mainExitEvent => getEventData(GateEventType.main_exit);
  Map<String, dynamic>? get mainEntryEvent => getEventData(GateEventType.main_entry);
  Map<String, dynamic>? get hostelEntryEvent => getEventData(GateEventType.hostel_entry);

  DateTime? get hostelExitTime => getEventTime(GateEventType.hostel_exit);
  DateTime? get mainExitTime => getEventTime(GateEventType.main_exit);
  DateTime? get mainEntryTime => getEventTime(GateEventType.main_entry);
  DateTime? get hostelEntryTime => getEventTime(GateEventType.hostel_entry);

  bool get isActive => hostelExitTime != null && !isCompleted;
  
  Duration? get remainingTime {
    if (!isActive) return null;
    final returnTime = expectedReturn ?? hostelExitTime?.add(const Duration(hours: 8));
    if (returnTime == null) return null;
    return returnTime.difference(DateTime.now());
  }

  bool get isOverdue {
    final remaining = remainingTime;
    return remaining != null && remaining.isNegative;
  }

  String get status {
    if (sequenceStatus == SequenceStatus.invalid) {
      return 'Invalid Sequence - Please contact administrator';
    }
    if (isCompleted) return 'Completed';
    if (hostelEntryTime != null) return 'Returned to Hostel';
    if (mainEntryTime != null) return 'On Campus (Not in Hostel)';
    if (mainExitTime != null) return 'Off Campus';
    if (hostelExitTime != null) return 'Left Hostel (On Campus)';
    return 'Approved (Not Yet Started)';
  }

  void addGateEvent({
    required GateEventType type,
    required String guardId,
    required String qrHash,
    String? deviceId,
    GeoPoint? location,
    String? notes,
  }) {
    validateNextScan(
      eventType: type,
      guardRole: UserRole.fromValue(guardId.split('_').first),
      qrHash: qrHash,
    );

    final event = {
      'type': type.name,
      'time': DateTime.now(),
      'guardId': guardId,
      'deviceId': deviceId ?? 'mobile',
      'qrHash': qrHash,
      if (location != null) 'location': location,
      if (notes != null) 'notes': notes,
    };

    gateEvents.add(event);
    updatedAt = DateTime.now();

    if (type.isExit && location != null) {
      currentLocation = location;
    }

    if (type == GateEventType.hostel_entry) {
      isCompleted = true;
      currentStatusMessage = 'Trip completed at ${DateTime.now()}';
    } else {
      currentStatusMessage = 'Last action: ${type.name} at ${DateTime.now()}';
    }

    logAuditAction(
      AuditAction.qr_scanned,
      performedBy: UserRole.fromValue(guardId.split('_').first),
      notes: 'Added ${type.name} event',
    );
  }

  String generateQRHash(String deviceId) {
    if (qrSecret == null) throw MissingSecretException('QR secret not initialized for trip $id');
    
    final hmac = Hmac(sha256, utf8.encode(qrSecret!));
    final message = '$id-$deviceId-${DateTime.now().millisecondsSinceEpoch ~/ (1000 * 60 * 5)}';
    return hmac.convert(utf8.encode(message)).toString();
  }

  Duration? get timeOutsideHostel {
    if (hostelExitTime == null) return null;
    final returnTime = hostelEntryTime ?? DateTime.now();
    return returnTime.difference(hostelExitTime!);
  }

  Duration? get timeOffCampus {
    if (mainExitTime == null) return null;
    final returnTime = mainEntryTime ?? DateTime.now();
    return returnTime.difference(mainExitTime!);
  }
  

DocumentReference get tripDocumentRef => FirebaseFirestore.instance.collection('trips').doc(id);
DocumentReference get leaveRequestDocumentRef => 
    FirebaseFirestore.instance.collection('leaveRequests').doc(leaveRequestId);

  String? getGuardForEvent(GateEventType type) {
    final event = getEventData(type);
    return event?['guardId'] as String?;
  }
}

class TripIntegrityException implements Exception {
  final String message;
  final DateTime timestamp = DateTime.now();
  
  TripIntegrityException(this.message);
  
  @override
  String toString() => 'TripIntegrityException: $message (at $timestamp)';
}

class GateSequenceException implements Exception {
  final GateEventType? expected;
  final GateEventType actual;
  final SequenceStatus currentStatus;
  final DateTime timestamp = DateTime.now();
  
  GateSequenceException({
    required this.expected,
    required this.actual,
    required this.currentStatus,
  });
  
  @override
  String toString() {
    return 'GateSequenceException: Expected $expected but got $actual. '
           'Current status: $currentStatus (at $timestamp)';
  }
}

class GuardAuthorizationException implements Exception {
  final UserRole role;
  final GateEventType event;
  final List<GateEventType> allowedEvents;
  final DateTime timestamp = DateTime.now();
  
  GuardAuthorizationException(
    this.role, 
    this.event, {
    required this.allowedEvents,
  });
  
  @override
  String toString() {
    return 'GuardAuthorizationException: Role $role cannot perform $event. '
           'Allowed events: $allowedEvents (at $timestamp)';
  }
}

class DuplicateScanException implements Exception {
  final DateTime? originalScanTime;
  final DateTime timestamp = DateTime.now();
  
  DuplicateScanException({this.originalScanTime});
  
  @override
  String toString() {
    return 'DuplicateScanException: QR code already used '
           '${originalScanTime != null ? 'at $originalScanTime' : ''} (at $timestamp)';
  }
}

class TemporalSequenceException implements Exception {
  final DateTime? lastEventTime;
  final DateTime currentTime;
  final Duration? minimumDelay;
  final DateTime timestamp = DateTime.now();
  
  TemporalSequenceException({
    this.lastEventTime,
    required this.currentTime,
    this.minimumDelay,
  });
  
  @override
  String toString() {
    if (minimumDelay != null) {
      return 'TemporalSequenceException: Minimum delay of ${minimumDelay!.inSeconds} '
             'seconds required between scans (at $timestamp)';
    }
    return 'TemporalSequenceException: Current time $currentTime is before '
           'last event time ${lastEventTime ?? 'unknown'} (at $timestamp)';
  }
}

class MissingSecretException implements Exception {
  final String message;
  final DateTime timestamp = DateTime.now();
  
  MissingSecretException(this.message);
  
  @override
  String toString() => 'MissingSecretException: $message (at $timestamp)';
}

extension _FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}