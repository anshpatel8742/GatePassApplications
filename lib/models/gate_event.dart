import 'package:cloud_firestore/cloud_firestore.dart';

class GateEvent {
  final String id;
  final String eventType;
  final DateTime timestamp;
  final String guardId;
  final String deviceId;
  final GeoPoint? location;
  final String? notes;
  final String leaveRequestId;

  GateEvent({
    required this.id,
    required this.eventType,
    required this.timestamp,
    required this.guardId,
    required this.deviceId,
    this.location,
    this.notes,
    required this.leaveRequestId,
  });

    factory GateEvent.fromFirestore(Map<String, dynamic> data, String id) {
    GeoPoint? location;
    if (data['location'] != null) {
      location = GeoPoint(
        (data['location'] as GeoPoint).latitude,
        (data['location'] as GeoPoint).longitude,
      );
    }
    return GateEvent(
      id: id,
      eventType: data['eventType'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      guardId: data['guardId'] as String,
      deviceId: data['deviceId'] as String,
      location: location,
      notes: data['notes'] as String?,
      leaveRequestId: data['leaveRequestId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventType': eventType,
      'timestamp': Timestamp.fromDate(timestamp),
      'guardId': guardId,
      'deviceId': deviceId,
      if (location != null) 'location': location,
      if (notes != null) 'notes': notes,
      'leaveRequestId': leaveRequestId,
    };
  }
}