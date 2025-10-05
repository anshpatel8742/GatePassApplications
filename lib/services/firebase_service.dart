// lib/services/firebase_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _isOffline = false;

  static bool get isOffline => _isOffline;

  static Future<void> initialize() async {
    await Firebase.initializeApp();
    
    // Enable persistence with settings
    await _firestore.enablePersistence(
      PersistenceSettings(
        synchronizeTabs: true,
      ),
    );

    // Set cache size (optional)
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      _isOffline = result == ConnectivityResult.none;
      if (!_isOffline) {
        // Automatically sync when connection returns
        _firestore.enableNetwork();
      }
    });
  }

  static Future<void> syncData() async {
    if (_isOffline) {
      await _firestore.enableNetwork();
      await Future.delayed(const Duration(seconds: 2)); // Allow sync time
    }
  }
}