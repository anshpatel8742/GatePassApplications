import 'package:cloud_firestore/cloud_firestore.dart';

class Warden {
  final String uid;
  final String employeeId;
  final String name;
  final String email;
  final List<String> managedHostels;
  final String phone;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool isActive;
  final DocumentReference? profileRef; // Added reference to profile doc

  Warden({
    required this.uid,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.managedHostels,
    required this.phone,
    this.photoUrl,
    DateTime? createdAt,
    DateTime? lastActive,
    this.isActive = true,
    this.profileRef,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActive = lastActive ?? DateTime.now(),
        assert(managedHostels.isNotEmpty, 'Warden must manage at least one hostel');

 

 factory Warden.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data()! as Map<String, dynamic>;
  return Warden(
    uid: doc.id,
    employeeId: data['employeeId'] as String,
    name: data['name'] as String,
    email: data['email'] as String,
    managedHostels: List<String>.from(data['managedHostels']),
    phone: data['phone'] as String,
    photoUrl: data['photoUrl'] as String?,
    createdAt: (data['createdAt'] as Timestamp).toDate(),
    lastActive: (data['lastActive'] as Timestamp).toDate(),
    isActive: data['isActive'] as bool? ?? true,
    profileRef: data['profileRef'] as DocumentReference?,
  );
}
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'managedHostels': managedHostels,
      'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'isActive': isActive,
      if (profileRef != null) 'profileRef': profileRef,
    };
  }

  void validate() {
    // Enhanced employee ID validation
    final hostelCodes = managedHostels.map((h) => h.substring(6,7).toUpperCase()); // Extract "A" from "Hostel-A"
    final validPrefixes = hostelCodes.map((code) => 'WDN-$code-');
    
    if (!validPrefixes.any((prefix) => employeeId.startsWith(prefix))) {
      throw ArgumentError('Employee ID must start with one of: ${validPrefixes.join(', ')}');
    }

    if (!RegExp(r'^WDN-[A-Z]-\d{3}$').hasMatch(employeeId)) {
      throw ArgumentError('Invalid employee ID format (e.g. WDN-A-001)');
    }

    // Consistent phone validation with other models
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      throw ArgumentError('Phone must be 10 digits');
    }

    // Email validation matches student format
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      throw ArgumentError('Invalid email format');
    }
  }

  // New helper method
  List<String> get hostelCodes => managedHostels.map((h) => h.substring(6,7)).toList();

  // Existing helpers remain
  String get formattedId => 'Warden $employeeId';
  String get primaryHostel => managedHostels.first;
  bool managesHostel(String hostelName) =>
      managedHostels.any((h) => h.toLowerCase() == hostelName.toLowerCase());

  Warden copyWith({
    String? name,
    String? email,
    List<String>? managedHostels,
    String? phone,
    String? photoUrl,
    bool? isActive,
    DocumentReference? profileRef,
  }) {
    return Warden(
      uid: uid,
      employeeId: employeeId,
      name: name ?? this.name,
      email: email ?? this.email,
      managedHostels: managedHostels ?? this.managedHostels,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      lastActive: lastActive,
      isActive: isActive ?? this.isActive,
      profileRef: profileRef ?? this.profileRef,
    );
  }

  @override
  String toString() => 'Warden($employeeId, $name, hostels: ${managedHostels.join(', ')})';
}