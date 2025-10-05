import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String id;
  final String studentUid;
  final String name;
  final String relationship;
  final String primaryPhone;
  final String? secondaryPhone;
  final String email;
  final bool isVerified;
  final DateTime? lastVerifiedOn;
  final String? verificationCode;
  final DateTime? codeExpiry;

  EmergencyContact({
    required this.id,
    required this.studentUid,
    required this.name,
    required this.relationship,
    required this.primaryPhone,
    this.secondaryPhone,
    required this.email,
    bool? isVerified,
    this.lastVerifiedOn,
    this.verificationCode,
    this.codeExpiry,
  }) : isVerified = isVerified ?? false;

   factory EmergencyContact.fromFirestore(Map<String, dynamic> data, String id) {
    return EmergencyContact(
      id: id,
      studentUid: data['studentUid'] as String,
      name: data['name'] as String,
      relationship: data['relationship'] as String,
      primaryPhone: data['primaryPhone'] as String,
      secondaryPhone: data['secondaryPhone'] as String?,
      email: data['email'] as String,
      isVerified: data['isVerified'] as bool? ?? false,
      lastVerifiedOn: data['lastVerifiedOn'] != null 
          ? (data['lastVerifiedOn'] as Timestamp).toDate()
          : null,
      verificationCode: data['verificationCode'] as String?,
      codeExpiry: data['codeExpiry'] != null
          ? (data['codeExpiry'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentUid': studentUid,
      'name': name,
      'relationship': relationship,
      'primaryPhone': primaryPhone,
      if (secondaryPhone != null) 'secondaryPhone': secondaryPhone,
      'email': email,
      'isVerified': isVerified,
      if (lastVerifiedOn != null) 
        'lastVerifiedOn': Timestamp.fromDate(lastVerifiedOn!),
      if (verificationCode != null) 'verificationCode': verificationCode,
      if (codeExpiry != null) 'codeExpiry': Timestamp.fromDate(codeExpiry!),
    };
  }

  void validate() {
    if (studentUid.isEmpty || !studentUid.startsWith('stu')) {
      throw ArgumentError('Invalid student reference');
    }
    
    if (name.isEmpty) {
      throw ArgumentError('Contact name is required');
    }
    
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      throw ArgumentError('Invalid email format');
    }
    
    if (!RegExp(r'^[0-9]{10}$').hasMatch(primaryPhone)) {
      throw ArgumentError('Primary phone must be 10 digits');
    }
    
    if (secondaryPhone != null && 
        !RegExp(r'^[0-9]{10}$').hasMatch(secondaryPhone!)) {
      throw ArgumentError('Secondary phone must be 10 digits');
    }
    
    if (isVerified && lastVerifiedOn == null) {
      throw ArgumentError('Verified contacts must have verification date');
    }
  }

  // Helpers
  bool get isCodeValid {
    if (verificationCode == null || codeExpiry == null) return false;
    return codeExpiry!.isAfter(DateTime.now());
  }
}