
import 'dart:convert';
import 'package:flutter/foundation.dart';

class QrPayload {
  final String version;
  final String leaveId;
  final String tripId;
  final String studentId;
  final String hash;
  final DateTime timestamp;

  QrPayload({
    required this.leaveId,
    required this.tripId,
    required this.studentId,
    required this.hash,
    this.version = '2',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now() {
    if (leaveId.isEmpty || tripId.isEmpty || studentId.isEmpty || hash.isEmpty) {
      throw ArgumentError('Required fields cannot be empty');
    }
  }

  factory QrPayload.fromJson(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return QrPayload(
        version: data['v']?.toString() ?? '2',
        leaveId: data['lid']?.toString() ?? '',
        tripId: data['tid']?.toString() ?? '',
        studentId: data['sid']?.toString() ?? '',
        hash: data['h']?.toString() ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(data['t']?.toString() ?? '0') ?? 0,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing QrPayload: $e');
      debugPrint('Stack trace: $stackTrace');
      throw FormatException('Invalid QR payload: $e');
    }
  }

  String toJson() {
    try {
      return jsonEncode({
        'v': version,
        'lid': leaveId,
        'tid': tripId,
        'sid': studentId,
        'h': hash,
        't': timestamp.millisecondsSinceEpoch,
      });
    } catch (e, stackTrace) {
      debugPrint('Error encoding QrPayload: $e');
      debugPrint('Stack trace: $stackTrace');
      throw FormatException('Failed to encode QR payload: $e');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrPayload &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          leaveId == other.leaveId &&
          tripId == other.tripId &&
          studentId == other.studentId &&
          hash == other.hash &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      version.hashCode ^
      leaveId.hashCode ^
      tripId.hashCode ^
      studentId.hashCode ^
      hash.hashCode ^
      timestamp.hashCode;

  @override
  String toString() {
    return 'QrPayload('
        'version: $version, '
        'leaveId: $leaveId, '
        'tripId: $tripId, '
        'studentId: $studentId, '
        'hash: $hash, '
        'timestamp: $timestamp)';
  }

  /// Creates a copy of this QrPayload with the given fields replaced
  QrPayload copyWith({
    String? version,
    String? leaveId,
    String? tripId,
    String? studentId,
    String? hash,
    DateTime? timestamp,
  }) {
    return QrPayload(
      version: version ?? this.version,
      leaveId: leaveId ?? this.leaveId,
      tripId: tripId ?? this.tripId,
      studentId: studentId ?? this.studentId,
      hash: hash ?? this.hash,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Validates the payload structure
  bool validate() {
    return version.isNotEmpty &&
        leaveId.isNotEmpty &&
        tripId.isNotEmpty &&
        studentId.isNotEmpty &&
        hash.isNotEmpty;
  }

  /// Checks if the QR code is expired (older than 5 minutes)
  bool get isExpired {
    return DateTime.now().difference(timestamp) > const Duration(minutes: 5);
  }
}