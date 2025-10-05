// lib/services/qr_service.dart
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../models/trip.dart';
import '../../models/enums.dart'; // Import enums for GateEventType

class QrService {
  // Existing HMAC hash generation
  static String generateHmacHash({
    required String secret,
    required String tripId,
    required String studentId,
  }) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    final timeSlot = DateTime.now().millisecondsSinceEpoch ~/ (1000 * 60 * 5); // 5-min window
    final message = '$tripId-$studentId-$timeSlot';
    return hmac.convert(utf8.encode(message)).toString();
  }

  // Existing HMAC validation
  static bool validateHmac({
    required String secret,
    required String receivedHash,
    required String tripId,
    required String studentId,
  }) {
    try {
      final expected = generateHmacHash(
        secret: secret,
        tripId: tripId,
        studentId: studentId,
      );
      return expected == receivedHash;
    } catch (_) {
      return false;
    }
  }

  // Corrected scan sequence validation method
  static GateEventType? validateScanSequence({
    required Trip currentTrip,
    required GateEventType attemptedScan,
  }) {
    // Access the type using map syntax and convert to GateEventType
    final events = currentTrip.gateEvents
        .map((e) => GateEventType.fromValue(e['type'] as String))
        .toList();
    
    if (events.isEmpty) {
      return attemptedScan == GateEventType.hostel_exit 
          ? null // Valid first scan
          : GateEventType.hostel_exit;
    }

    const expectedSequence = [
      GateEventType.hostel_exit,
      GateEventType.main_exit,
      GateEventType.main_entry,
      GateEventType.hostel_entry,
    ];

    // Only proceed if we haven't completed all steps
    if (events.length < expectedSequence.length) {
      final nextExpected = expectedSequence[events.length];
      return attemptedScan == nextExpected ? null : nextExpected;
    }
    
    // All steps completed
    return GateEventType.hostel_entry;
  }
}