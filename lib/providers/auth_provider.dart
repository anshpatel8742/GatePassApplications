import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import 'dart:async'; // Add this for StreamSubscription

class AuthProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = false;
  String _error = '';
  String? _roleValue; // Stores the string value from Firestore
  StreamSubscription<User?>? _authStateSubscription;
// Add this property to your AuthProvider class
String? _guardType; // Will store 'hostel' or 'main'
  // Public getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get isAuthenticated => _user != null;
  // Add this getter
String? get guardType => _guardType;
  
  // Returns the enum version of the role
  UserRole? get userRole => _roleValue != null 
      ? UserRole.fromValue(_roleValue!) 
      : null;

  AuthProvider() {
    _user = _auth.currentUser;
    _setupAuthListener();
  }

  // ================== CORE AUTH METHODS ================== //
Future<bool> signIn(String email, String password) async {
  try {
    _setLoading(true);
    _error = '';
    notifyListeners();

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    if (credential.user == null) throw Exception('Authentication failed');

    _user = credential.user;
    await _loadUserRole();

    if (userRole == null) {
      _error = 'Your account is not properly configured. Please contact support.';
      await _cleanupAuthState();
      return false;
    }

    final roleVerified = await _verifyRoleDocumentExists(
      email: email,
      uid: _user!.uid,
    );

    if (!roleVerified) {
      _error = 'Could not verify your role permissions. Please contact support.';
      await _cleanupAuthState();
      return false;
    }

    return true;
  } on FirebaseAuthException catch (e) {
    _error = _getReadableErrorMessage(e);
    return false;
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      _error = 'You do not have permission to access this system.';
    } else {
      _error = 'Database error: ${e.message}';
    }
    await _cleanupAuthState();
    return false;
  } catch (e) {
    _error = 'Login failed: ${e.toString()}';
    await _cleanupAuthState();
    return false;
  } finally {
    _setLoading(false);
    notifyListeners();
  }
}


Future<bool> signUp({
  required String email,
  required String password,
  required Map<String, dynamic> userData,
  required Map<String, dynamic> roleData,
  required UserRole role,
  required String documentId,
}) async {
  try {
    _setLoading(true);
    _error = '';
    notifyListeners();

    // 1. First create auth user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user?.uid ?? '';
    _user = credential.user;

    // 2. Then run Firestore transaction
    await _firestore.runTransaction((transaction) async {
      final roleCollection = _getRoleCollection(role);
      final roleDocRef = _firestore.collection(roleCollection)
          .doc(role == UserRole.student ? documentId : uid);
      
      if ((await transaction.get(roleDocRef)).exists) {
        throw '${role.displayName} with this ID already exists';
      }

      // Prepare documents
      final userDoc = {
        ...userData,
        'uid': uid,
        'email': email,
        'role': role.value,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final completeRoleData = {
        ...roleData,
        'uid': uid,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      };

      transaction.set(_firestore.collection('users').doc(uid), userDoc);
      transaction.set(roleDocRef, completeRoleData);
    });

    return true;
  } catch (e, stack) {
    debugPrint('Signup error: $e\n$stack');
    _error = _getReadableErrorMessage(e);
    await _cleanupFailedSignup();
    return false;
  } finally {
    _setLoading(false);
    notifyListeners();
  }
}




  Future<bool> signOut() async {
    try {
      await _auth.signOut();
      await _cleanupAuthState();
      return true;
    } catch (e) {
      _error = _getReadableErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

Future<bool> resetPassword(String email) async {
  try {
    _setLoading(true);
    _error = '';
    notifyListeners();
    
    await _auth.sendPasswordResetEmail(email: email);
    return true;
  } catch (e) {
    _error = _getReadableErrorMessage(e);
    return false;
  } finally {
    _setLoading(false);
    notifyListeners();
  }
}
  // ================== PROFILE MANAGEMENT ================== //

  Future<bool> isProfileComplete() async {
    if (userRole != UserRole.student || _user == null) return true;
    final doc = await _firestore
        .collection(_getRoleCollection(UserRole.student))
        .doc(_user!.uid)
        .get();
    return doc.data()?['profileComplete'] ?? false;
  }

   bool _isStudentProfileComplete(Map<String, dynamic> data) {
    return data['branch'] != null && 
           data['year'] != null &&
           data['phone']?.length == 10 &&
           data['parentPhone']?.length == 10;
  }

  Future<void> completeStudentProfile(Map<String, dynamic> updates) async {
    if (userRole != UserRole.student || _user == null) return;
    
     if (!_isStudentProfileComplete(updates)) {
    throw 'Missing required profile fields (branch, year, phone, parentPhone)';
  }

  
    
    try {
      _setLoading(true);
      final batch = _firestore.batch();
      
      // Update student document
      final studentRef = _firestore
          .collection(_getRoleCollection(UserRole.student))
          .doc(_user!.uid);
      batch.update(studentRef, {
        ...updates,
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      final userRef = _firestore.collection('users').doc(_user!.uid);
      batch.update(userRef, {
        'profileComplete': true,
      });

      await batch.commit();
    } catch (e) {
      _error = 'Failed to update profile: ${e.toString()}';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_user == null || userRole == null) return null;
    final doc = await _firestore
        .collection(_getRoleCollection(userRole!))
        .doc(_user!.uid)
        .get();
    return doc.data();
  }

  // ================== ROLE MANAGEMENT ================== //

  Future<bool> verifyCurrentUserRole() async {
    if (_user == null || userRole == null) return false;
    return await _verifyRoleDocumentExists(
      email: _user!.email ?? '',
      uid: _user!.uid,
    );
  }

  // ================== HELPER METHODS ================== //

  void _setupAuthListener() {
    _authStateSubscription?.cancel();
    _authStateSubscription = _auth.authStateChanges().listen((user) async {
      _user = user;
      if (user == null) {
        _roleValue = null;
      } else {
        await _loadUserRole();
      }
      notifyListeners();
    });
  }


// Future<void> _loadUserRole() async {
//   if (_user == null) return;
  
//   try {
//     final doc = await _firestore.collection('users').doc(_user!.uid).get();
//     if (!doc.exists) {
//       throw Exception('User role document missing'); // Explicit error
//     }
//     _roleValue = doc['role'] as String?;
//   } catch (e) {
//     debugPrint('Role load failed: $e');
//     await _cleanupAuthState(); // Force logout
//     rethrow;
//   }
// }



Future<void> _loadUserRole() async {
  if (_user == null) return;
  
  try {
   // 1. Load basic user data
    final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
    if (!userDoc.exists) throw Exception('User document missing');
    
    _roleValue = userDoc['role'] as String?;
    debugPrint('Loaded user role: $_roleValue');
    

    // Additional verification for students
    if (_roleValue == UserRole.student.value) {
      final email = _user!.email ?? '';
      final studentDoc = await _firestore.collection('students')
          .where('uid', isEqualTo: _user!.uid)
          .limit(1)
          .get();
          
      if (studentDoc.docs.isEmpty) {
        debugPrint('Student document missing for UID: ${_user!.uid}');
        throw Exception('Student documentation not found');
      }
    }
    
     // 3. For guards, verify matching guard document
    if (_roleValue == UserRole.hostelGuard.value || 
        _roleValue == UserRole.mainGuard.value) {
      
      final guardDoc = await _firestore.collection('guards').doc(_user!.uid).get();
      
      // Strict validation
      if (!guardDoc.exists) throw Exception('Guard document missing');
      
      final guardType = guardDoc['type'] as String?;
      final guardRole = guardDoc['role'] as String?;
      
      // Case 1: Both fields exist - must match
      if (guardType != null && guardRole != null) {
        if ((guardType == 'hostel' && guardRole != 'hostel_guard') ||
            (guardType == 'main' && guardRole != 'main_guard')) {
          throw Exception('Role/type mismatch in guard document');
        }
        _guardType = guardType;
      }
      // Case 2: Only type exists (legacy)
      else if (guardType != null) {
        _guardType = guardType;
        // Auto-repair by adding missing role field
        await guardDoc.reference.update({
          'role': guardType == 'hostel' ? 'hostel_guard' : 'main_guard'
        });
      }
      // Case 3: Only role exists (shouldn't happen)
      else if (guardRole != null) {
        _guardType = guardRole.contains('hostel') ? 'hostel' : 'main';
        await guardDoc.reference.update({
          'type': _guardType
        });
      }
      // Case 4: Neither exists (corrupt)
      else {
        throw Exception('Guard document missing both type and role');
      }
      
      // Final verification
      if ((_roleValue == 'hostel_guard' && _guardType != 'hostel') ||
          (_roleValue == 'main_guard' && _guardType != 'main')) {
        throw Exception('User role and guard type mismatch');
      }
    }

  } catch (e) {
    debugPrint('Role load error: $e');
    await _cleanupAuthState();
    rethrow;
  }
}

Future<bool> _verifyRoleDocumentExists({
  required String email,
  required String uid,
}) async {
  if (userRole == null) return false;
  
  try {
    final collection = _getRoleCollection(userRole!);
    final query = _firestore.collection(collection);
    
    // Simplified verification - only checks if document exists
    final snapshot = await query
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  } catch (e) {
    debugPrint('Role verification error: $e');
    return false;
  }
}


  String _getRoleCollection(UserRole role) {
    return switch (role) {
      UserRole.student => 'students',
      UserRole.hostelGuard || UserRole.mainGuard => 'guards',
      UserRole.warden => 'wardens',
      UserRole.admin => 'admins',
      UserRole.system => 'system_users',
      UserRole.parent => 'parents',
      UserRole.faculty => 'faculty',
    };
  }

 

  Future<void> _cleanupAuthState() async {
  _user = null;
  _roleValue = null;
  _guardType = null; // Reset guard type
  notifyListeners();
  }
  
  Future<void> _cleanupFailedSignup() async {
  try {
    if (_user != null) {
      await _user!.delete(); // Delete Firebase user
      await _firestore.collection('users').doc(_user!.uid).delete(); // Cleanup metadata
    }
  } catch (e) {
    debugPrint('Cleanup error: $e');
  } finally {
    await _cleanupAuthState(); // Reset provider state
  }
}
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  String _getReadableErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => 'Email already registered',
        'weak-password' => 'Password must be 8+ characters with letters and numbers',
        'user-not-found' => 'No account found with this email',
        'wrong-password' => 'Incorrect password',
        'too-many-requests' => 'Too many attempts. Try again later',
        'network-request-failed' => 'Network error. Check your connection',
        'user-disabled' => 'This account has been disabled',
        'operation-not-allowed' => 'Login method not enabled',
        _ => error.message ?? 'Authentication failed',
      };
    }
    return error.toString().replaceAll('Exception:', '').trim();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
