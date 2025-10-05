import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';  // Add this import

class Student {
  final String uid;
  final String rollNumber; // Now expects 9 digits
  final String name;
  final String email;
  final String branch;
  final int year;
  final String hostelName;
  final String? roomNumber;
  final int? floorNumber;
  final String phone;
  final String parentPhone;
  final String? photoUrl;
  final String? emergencyContact;
  final List<String> activeLeaveIds;
  final DateTime createdAt;
  final DocumentReference? hostelRef;
  final String? timetableImageUrl;
  final DateTime? timetableLastUpdated;
  final bool profileComplete;

  Student({
    required this.uid,
    required this.rollNumber,
    required this.name,
    required this.email,
    required this.branch,
    required this.year,
    required this.hostelName,
    this.roomNumber,
    this.floorNumber,
    required this.phone,
    required this.parentPhone,
    this.photoUrl,
    this.emergencyContact,
    List<String>? activeLeaveIds,
    DateTime? createdAt,
    this.hostelRef,
    this.timetableImageUrl,
    this.timetableLastUpdated,
    this.profileComplete = false, // Default to false
  })  : activeLeaveIds = activeLeaveIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        assert(roomNumber == null || roomNumber.isNotEmpty, 
               'Room number cannot be empty if provided'),
        assert(floorNumber == null || floorNumber > 0, 
               'Floor number must be positive if provided');


factory Student.fromFirestore(Map<String, dynamic> data, String id){

 // Validate critical fields
    final requiredFields = ['uid', 'rollNumber', 'name', 'email'];
    for (final field in requiredFields) {
      if (data[field] == null || data[field].toString().isEmpty) {
        throw FormatException('Missing required field: $field');
      }
    }

    // Ensure document ID matches rollNumber
    if (id != data['rollNumber']) {
      debugPrint('Document structure warning: ID($id) ≠ rollNumber(${data['rollNumber']})');
      
  
    }

     return Student(
      uid: id,
      rollNumber: _parseString(data['rollNumber'], 'rollNumber'),
      name: _parseString(data['name'], 'name'),
      email: _parseString(data['email'], 'email'),
      branch: data['branch']?.toString() ?? 'UNASSIGNED', // Default value
      year: (data['year'] as num?)?.toInt() ?? 0, // Default to 0 if not set
      hostelName: data['hostelName']?.toString() ?? 'UNASSIGNED',
      roomNumber: data['roomNumber']?.toString(),
      floorNumber: data['floorNumber']?.toInt(),
      phone: data['phone']?.toString() ?? '',
      parentPhone: data['parentPhone']?.toString() ?? '',
      photoUrl: data['photoUrl']?.toString(),
      emergencyContact: data['emergencyContact']?.toString(),
      activeLeaveIds: List<String>.from(data['activeLeaveIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hostelRef: data['hostelRef'] as DocumentReference?,
      timetableImageUrl: data['timetableImageUrl']?.toString(),
      timetableLastUpdated: data['timetableLastUpdated']?.toDate(),
      profileComplete: data['profileComplete'] as bool? ?? false,
    );
  }

  static String _parseString(dynamic value, String fieldName) {
    if (value == null) {
      throw FormatException('$fieldName cannot be null');
    }
    return value.toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'rollNumber': rollNumber,
      'name': name,
      'email': email,
      'branch': branch,
      'year': year,
      'hostelName': hostelName,
      if (roomNumber != null) 'roomNumber': roomNumber,
      if (floorNumber != null) 'floorNumber': floorNumber,
      'phone': phone,
      'parentPhone': parentPhone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (emergencyContact != null) 'emergencyContact': emergencyContact,
      'activeLeaveIds': activeLeaveIds,
      'createdAt': Timestamp.fromDate(createdAt),
      if (hostelRef != null) 'hostelRef': hostelRef,
      if (timetableImageUrl != null) 'timetableImageUrl': timetableImageUrl,
      if (timetableLastUpdated != null) 
        'timetableLastUpdated': Timestamp.fromDate(timetableLastUpdated!),
      'profileComplete': profileComplete,
    };
  }

  void validate() {
    final errors = <String>[];
    
    if (uid.isEmpty) errors.add('UID cannot be empty');
    if (rollNumber.isEmpty) errors.add('Roll number cannot be empty');
    
    // Roll number validation
    if (!RegExp(r'^\d{9}$').hasMatch(rollNumber)) {
      errors.add('Roll number must be exactly 9 digits');
    }
    
    // Email validation
    if (!RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(email)) {
      errors.add('Invalid email format');
    }
    
    // Hostel validation
    if (hostelName == 'UNASSIGNED') {
      errors.add('Hostel must be assigned');
    }
    
    // Phone validation
    if (phone.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
      errors.add('Invalid phone number (must be 10 digits)');
    }
    
    if (parentPhone.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(parentPhone)) {
      errors.add('Invalid parent phone number (must be 10 digits)');
    }
    
    // Year validation
    if (year < 1 || year > 5) {
      errors.add('Year must be between 1 and 5');
    }
    
    // Branch validation
    if (branch == 'UNASSIGNED') {
      errors.add('Branch must be assigned');
    }
    
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.join('\n'));
    }
  }

  bool get isProfileComplete {
    return branch != 'UNASSIGNED' && 
           year > 0 && 
           hostelName != 'UNASSIGNED' &&
           phone.length == 10 &&
           parentPhone.length == 10;
  }

  bool get hasActiveLeave => activeLeaveIds.isNotEmpty;
  
  String? get formattedRoom {
    if (roomNumber == null) return null;
    return floorNumber != null 
        ? 'Floor $floorNumber, Room $roomNumber' 
        : 'Room $roomNumber';
  }

  Student copyWith({
    String? rollNumber,
    String? name,
    String? email,
    String? branch,
    int? year,
    String? hostelName,
    String? roomNumber,
    int? floorNumber,
    String? phone,
    String? parentPhone,
    String? photoUrl,
    String? emergencyContact,
    List<String>? activeLeaveIds,
    DocumentReference? hostelRef,
    String? timetableImageUrl,  // Changed from timetableImageUrl
    DateTime? timetableLastUpdated,
    
  }) {
    return Student(
      uid: uid,
      rollNumber: rollNumber ?? this.rollNumber,
      name: name ?? this.name,
      email: email ?? this.email,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      hostelName: hostelName ?? this.hostelName,
      roomNumber: roomNumber ?? this.roomNumber,
      floorNumber: floorNumber ?? this.floorNumber,
      phone: phone ?? this.phone,
      parentPhone: parentPhone ?? this.parentPhone,
      photoUrl: photoUrl ?? this.photoUrl,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      activeLeaveIds: activeLeaveIds ?? List.from(this.activeLeaveIds),
      createdAt: createdAt,
      hostelRef: hostelRef ?? this.hostelRef,
      timetableImageUrl: timetableImageUrl ?? this.timetableImageUrl,
    timetableLastUpdated: timetableLastUpdated ?? this.timetableLastUpdated,
    
    );
  }

  Future<DocumentReference?> resolveHostelRef() async {
    if (hostelRef != null) return hostelRef;
    if (hostelName.isEmpty) return null;
    
    final hostels = await FirebaseFirestore.instance
        .collection('hostels')
        .where('name', isEqualTo: hostelName)
        .limit(1)
        .get();
        
    return hostels.docs.isNotEmpty ? hostels.docs.first.reference : null;
  }

  @override
  String toString() {
    return 'Student($rollNumber, $name, $hostelName)';
  }
}