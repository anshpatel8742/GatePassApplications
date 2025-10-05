import 'package:cloud_firestore/cloud_firestore.dart';

enum GuardType {
  main('Main Gate'),
  hostel('Hostel Gate'); // Changed label to be more consistent

  final String label;
  const GuardType(this.label);
}

class Guard {
  final String uid;
  final String employeeId; // Format: "GRD-{typeCode}-{number}"
  final String name;
  final String email;
  final GuardType type;
  final String? assignedHostel;
  final String phone;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool isActive; // Added active status flag

  Guard({
    required this.uid,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.type,
    this.assignedHostel,
    required this.phone,
    this.photoUrl,
    DateTime? createdAt,
    DateTime? lastActive,
    this.isActive = true, // Default to active
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActive = lastActive ?? DateTime.now(),
        assert(type == GuardType.main || assignedHostel != null,
            'Hostel guards must have an assigned hostel');
factory Guard.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>? ?? {};
  
  // Handle all required fields with defaults
  return Guard(
    uid: doc.id,
    employeeId: data['employeeId'] as String? ?? 'GRD-UNKNOWN-000',
    name: data['name'] as String? ?? 'Unknown Guard',
    email: data['email'] as String? ?? 'no-email@college.edu',
    type: GuardType.values.firstWhere(
      (e) => e.name == (data['type'] as String?),
      orElse: () => GuardType.main,
    ),
    assignedHostel: data['assignedHostel'] as String?,
    phone: data['phone'] as String? ?? '0000000000',
    photoUrl: data['photoUrl'] as String?,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    lastActive: (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
    isActive: data['isActive'] as bool? ?? true,
  );
}

  Map<String, dynamic> toMap() {
    return {
       'uid': uid,
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'type': type.name,
      if (assignedHostel != null) 'assignedHostel': assignedHostel,
      'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'isActive': isActive,
    };
  }

  void validate() {
    // Enhanced employee ID validation
    final expectedPrefix = type == GuardType.main 
        ? 'GRD-M-' 
        : 'GRD-H${assignedHostel?.substring(6,7)}-'; // Extract "A" from "Hostel-A"
    
    if (!employeeId.startsWith(expectedPrefix)) {
      throw ArgumentError('Employee ID must start with $expectedPrefix');
    }

    if (!RegExp(r'^GRD-(M|H[A-Z])-\d{3}$').hasMatch(employeeId)) {
      throw ArgumentError('Invalid employee ID format (e.g. GRD-M-001 or GRD-HA-001)');
    }

    // Enhanced phone validation (matches student format)
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      throw ArgumentError('Phone must be 10 digits');
    }

    if (type == GuardType.hostel && assignedHostel == null) {
      throw ArgumentError('Hostel guards must have an assigned hostel');
    }
  }

  // New helper method
  String get formattedAssignment {
    return type == GuardType.main
        ? 'Main Campus Gate'
        : '$assignedHostel Gate';
  }

  

  // Existing helpers remain the same
  String get formattedId => '${type.label} Guard: $employeeId';
  bool get isMainGuard => type == GuardType.main;
  bool managesHostel(String hostelName) => 
      type == GuardType.hostel && assignedHostel == hostelName;
}