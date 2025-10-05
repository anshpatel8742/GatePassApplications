import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuardTypeProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _gateType = 'unknown';
  bool _isLoading = false;
  String? _error;

  String get gateType => _gateType;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  bool get isHostelGuard => _gateType == 'hostel';
  bool get isMainGuard => _gateType == 'main';
  bool get isGuard => isHostelGuard || isMainGuard;


  // Add these new getters
  String get displayName => isHostelGuard ? 'Hostel Guard' : 'Main Gate Guard';
  IconData get icon => isHostelGuard ? Icons.home_work : Icons.security;
  Color get primaryColor => isHostelGuard ? Colors.deepPurple : Colors.blue.shade700;
  Color get secondaryColor => isHostelGuard ? Colors.purple.shade100 : Colors.blue.shade100;
  String get scanActionLabel => isHostelGuard ? 'Scan Hostel QR' : 'Scan Main Gate QR';
  String get databaseTitle => isHostelGuard ? 'Hostel Records' : 'Campus Records';
  String get overdueLabel => isHostelGuard ? 'Outside Hostel' : 'Outside Campus';


  // ... (rest of your existing getters)

  Future<void> determineGuardType() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        _gateType = 'not_guard';
        return;
      }

      final userRole = userDoc['role'] as String?;
      if (userRole != 'hostel_guard' && userRole != 'main_guard') {
        _gateType = 'not_guard';
        return;
      }

      final guardDoc = await _firestore.collection('guards').doc(user.uid).get();
      if (!guardDoc.exists) throw Exception('Guard document not found');

      final type = guardDoc['type'] as String?;
      final docRole = guardDoc['role'] as String?;

      // Auto-repair if role is missing in guards collection
      if (type != null && docRole == null) {
        await guardDoc.reference.update({
          'role': type == 'hostel' ? 'hostel_guard' : 'main_guard'
        });
        _gateType = type;
        return;
      }

      // Strict validation
      if (type == 'hostel' && docRole != 'hostel_guard') {
        throw Exception('Database corruption: Hostel guard with wrong role');
      }
      if (type == 'main' && docRole != 'main_guard') {
        throw Exception('Database corruption: Main guard with wrong role');
      }

      _gateType = type ?? 'unknown';
    } catch (e) {
      _error = e.toString();
      _gateType = 'unknown';
      debugPrint('GuardType Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ... (rest of your existing methods)
  bool hasPermission(String requiredType) {
    if (requiredType == 'any_guard') return isGuard;
    return _gateType == requiredType;
  }
}


 