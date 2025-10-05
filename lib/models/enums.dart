
// Add this extension for easier string conversion
extension LeaveStatusX on LeaveStatus {
  String get firestoreValue {
    switch (this) {
      case LeaveStatus.pending_guard:
        return 'pending_guard';
      case LeaveStatus.pending_warden:
        return 'pending_warden';
      // other cases...
      default:
        return value;
    }
  }
}

// Add similar for LeaveType
extension LeaveTypeX on LeaveType {
  String get firestoreValue => value;
}

// Core Leave Types with enhanced metadata
enum LeaveType {
  day('day', 
    maxDuration: Duration(hours: 12),
    description: 'Day pass (return same day)',
    requiresWarden: false,
    requiresParent: false,
  ),
  home('home', 
    minDuration: Duration(hours: 12),
    description: 'Home leave (overnight/weekend)',
    requiresWarden: true,
    requiresParent: true,
  ),
  emergency('emergency',
    maxDuration: Duration(hours: 6),
    description: 'Emergency leave',
    requiresWarden: false,
    requiresParent: false,
  ),

   other('other', // Add this new type
    description: 'Other leave type',
    requiresWarden: false,
    requiresParent: false,
  );  

  final String value;
  final Duration? minDuration;
  final Duration? maxDuration;
  final String description;
  final bool requiresWarden;
  final bool requiresParent;

  const LeaveType(
    this.value, {
    this.minDuration,
    this.maxDuration,
    required this.description,
    required this.requiresWarden,
    required this.requiresParent,
  });

  factory LeaveType.fromValue(String value) {
    return values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => LeaveType.other, // Return 'other' as fallback
    );
  }


  bool get requiresWardenApproval => requiresWarden;
  bool get requiresParentConsent => requiresParent;

  // Get allowed durations for UI display
  String get durationDescription {
    if (minDuration != null && maxDuration != null) {
      return '${minDuration!.inHours}-${maxDuration!.inHours} hours';
    }
    if (minDuration != null) return 'Minimum ${minDuration!.inHours} hours';
    if (maxDuration != null) return 'Maximum ${maxDuration!.inHours} hours';
    return 'Flexible duration';
  }

  
}

// Enhanced sequence status with descriptions
enum SequenceStatus {
  pendingHostelExit('Pending Hostel Exit', 'Student needs to exit hostel first'),
  pendingMainExit('Pending Main Exit', 'Student needs to exit main gate'),
  pendingMainEntry('Pending Main Entry', 'Student needs to enter main gate'),
  pendingHostelEntry('Pending Hostel Entry', 'Student needs to enter hostel'),
  completed('Completed', 'Trip completed successfully'),
  invalid('Invalid', 'Invalid sequence detected');

  final String displayName;
  final String description;

  const SequenceStatus(this.displayName, this.description);

  bool get isComplete => this == completed;
  bool get isValid => this != invalid;
}

// Enhanced leave status with state machine
enum LeaveStatus {
  draft('draft', 'Draft', 'Leave request not yet submitted'),
  pending_guard('pending_guard', 'Pending Guard Approval', 'Waiting for hostel guard approval'),
  pending_warden('pending_warden', 'Pending Warden Approval', 'Waiting for warden approval'),
  approved('approved', 'Approved', 'Leave request approved'),
  active('active', 'Active', 'Leave in progress'),
  completed('completed', 'Completed', 'Leave successfully completed'),
  rejected('rejected', 'Rejected', 'Leave request rejected'),
  cancelled('cancelled', 'Cancelled', 'Leave request cancelled'),
  expired('expired', 'Expired', 'Leave request expired'),
  recalled('recalled', 'Recalled', 'Leave recalled by authorities');

  final String value;
  final String displayName;
  final String description;

  const LeaveStatus(this.value, this.displayName, this.description);

  bool get isTerminal => this == completed || 
                       this == rejected || 
                       this == cancelled || 
                       this == expired ||
                       this == recalled;

  factory LeaveStatus.fromValue(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid LeaveStatus value: $value'),
    );
  }

  static LeaveStatus defaultForType(LeaveType type) {
    return type.requiresWardenApproval 
        ? LeaveStatus.pending_warden
        : LeaveStatus.pending_guard;
  }

  static List<LeaveStatus> allowedTransitions(LeaveStatus current) {
    switch (current) {
      case LeaveStatus.draft:
        return [LeaveStatus.pending_guard];
      case LeaveStatus.pending_guard:
        return [LeaveStatus.approved, LeaveStatus.rejected, LeaveStatus.cancelled];
      case LeaveStatus.pending_warden:
        return [LeaveStatus.approved, LeaveStatus.rejected, LeaveStatus.cancelled];
      case LeaveStatus.approved:
        return [LeaveStatus.active, LeaveStatus.cancelled, LeaveStatus.expired];
      case LeaveStatus.active:
        return [LeaveStatus.completed, LeaveStatus.expired, LeaveStatus.recalled];
      default:
        return [];
    }
  }
  
  bool get isApproved => this == LeaveStatus.approved;
  bool get isCompleted => this == LeaveStatus.completed;
  bool get isCancelled => this == LeaveStatus.cancelled;
  bool get isActive => this == LeaveStatus.active;
  bool get isPending => this == pending_guard || this == pending_warden;
}

// Enhanced Hostel Classification
enum HostelType {
  boys('boys', 'Boys Hostel'),
  girls('girls', 'Girls Hostel'),
  mixed('mixed', 'Mixed Hostel'),
  international('international', 'International Hostel'),
  pg('pg', 'PG Accommodation');

  final String value;
  final String displayName;

  const HostelType(this.value, this.displayName);

  factory HostelType.fromValue(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid HostelType value: $value'),
    );
  }
}

// Enhanced Approval Process Methods
enum ApprovalMethod {
  automatic('automatic', 'Automatic Approval'),
  manual('manual', 'Manual Approval'),
  parent_verified('parent_verified', 'Parent Verified'),
  biometric('biometric', 'Biometric Verification'),
  otp('otp', 'OTP Verification'),
  emergency('emergency', 'Emergency Override');

  final String value;
  final String displayName;

  const ApprovalMethod(this.value, this.displayName);

  factory ApprovalMethod.fromValue(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid ApprovalMethod value: $value'),
    );
  }
}

// Enhanced User Role System
enum UserRole {
  student('student', 'Student'),
  hostelGuard('hostel_guard', 'Hostel Guard'),
  mainGuard('main_guard', 'Main Gate Guard'),
  warden('warden', 'Warden'),
  admin('admin', 'Administrator'),
  system('system', 'System'),
  parent('parent', 'Parent'),
  faculty('faculty', 'Faculty');

  final String value;
  final String displayName;

  const UserRole(this.value, this.displayName);

  factory UserRole.fromValue(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid UserRole value: $value'),
    );
  }

  bool get canApproveLeaves => this == hostelGuard || 
                             this == warden || 
                             this == admin ||
                             this == faculty;

  bool get canManageStudents => this == warden || 
                             this == admin ||
                             this == faculty;

  bool get canViewSensitiveData => this == warden || 
                                 this == admin;

  bool get isGuard => this == hostelGuard || this == mainGuard;

  
}

// Enhanced Gate Event Types with metadata
enum GateEventType {
  hostel_exit('hostel_exit', 'Hostel Exit', 'Student exited hostel'),
  main_exit('main_exit', 'Main Exit', 'Student exited campus'),
  main_entry('main_entry', 'Main Entry', 'Student entered campus'),
  hostel_entry('hostel_entry', 'Hostel Entry', 'Student entered hostel'),
  checkpoint('checkpoint', 'Checkpoint', 'Checkpoint scan'),
  emergency_exit('emergency_exit', 'Emergency Exit', 'Emergency exit recorded');

  final String value;
  final String displayName;
  final String description;

  const GateEventType(this.value, this.displayName, this.description);

  factory GateEventType.fromValue(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid GateEventType value: $value'),
    );
  }

  bool get isExit => this == hostel_exit || 
                   this == main_exit || 
                   this == emergency_exit;

  bool get isEntry => this == main_entry || 
                    this == hostel_entry;

  bool get isCheckpoint => this == checkpoint;
}

// Enhanced Notification Types with categories
enum NotificationType {
  // Approval Notifications
  leave_approved('leave_approved', 'Leave Approved', 'approval'),
  leave_rejected('leave_rejected', 'Leave Rejected', 'approval'),
  
  // Status Notifications
  overdue_warning('overdue_warning', 'Overdue Warning', 'status'),
  scan_reminder('scan_reminder', 'Scan Reminder', 'status'),
  
  // Verification Notifications
  parent_verification('parent_verification', 'Parent Verification', 'verification'),
  warden_verification('warden_verification', 'Warden Verification', 'verification'),
  
  // Security Notifications
  invalid_scan('invalid_scan', 'Invalid Scan Attempt', 'security'),
  emergency_alert('emergency_alert', 'Emergency Alert', 'security'),
  
  // System Notifications
  system_update('system_update', 'System Update', 'system'),
  password_reset('password_reset', 'Password Reset', 'system');

  final String value;
  final String displayName;
  final String category;

  const NotificationType(this.value, this.displayName, this.category);

  factory NotificationType.fromValue(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid NotificationType value: $value'),
    );
  }
}

// New enum for Audit Log Actions
enum AuditAction {
  leave_created('leave_created', 'Leave Request Created'),
  leave_approved('leave_approved', 'Leave Request Approved'),
  leave_rejected('leave_rejected', 'Leave Request Rejected'),
  leave_cancelled('leave_cancelled', 'Leave Request Cancelled'),
  qr_generated('qr_generated', 'QR Code Generated'),
  qr_scanned('qr_scanned', 'QR Code Scanned'),
  overdue_notification('overdue_notification', 'Overdue Notification'), // Add this
  user_login('user_login', 'User Login'),
  user_logout('user_logout', 'User Logout'),
  security_override('security_override', 'Security Override'),
  data_exported('data_exported', 'Data Exported');

  final String value;
  final String description;

  const AuditAction(this.value, this.description);

  factory AuditAction.fromValue(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid AuditAction value: $value'),
    );
  }
}

// New enum for Device Types
enum DeviceType {
  mobile('mobile', 'Mobile Device'),
  tablet('tablet', 'Tablet Device'),
  desktop('desktop', 'Desktop Computer'),
  kiosk('kiosk', 'Checkpoint Kiosk'),
  unknown('unknown', 'Unknown Device');

  final String value;
  final String description;

  const DeviceType(this.value, this.description);

  factory DeviceType.fromValue(String value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => DeviceType.unknown,
    );
  }
}


enum VerificationMethod {
  call,
  sms,
  email,
  other;

  int get value {
    switch (this) {
      case VerificationMethod.call: return 0;
      case VerificationMethod.sms: return 1;
      case VerificationMethod.email: return 2;
      case VerificationMethod.other: return 3;
    }
  }
}


class InvalidQRException implements Exception {
  @override
  String toString() => 'Invalid QR code';
}

class WrongSequenceException implements Exception {
  final GateEventType? expectedEvent;
  WrongSequenceException(this.expectedEvent);
  
  @override
  String toString() => expectedEvent != null 
      ? 'Expected ${expectedEvent!.displayName}' 
      : 'Invalid sequence';
}


// Custom exceptions in enums.dart
enum ScanErrorType {
  invalidQR,
  wrongSequence,
  expiredQR,
  guardNotAuthorized,
}

extension ScanErrorMessages on ScanErrorType {
  String get message {
    switch (this) {
      case ScanErrorType.invalidQR:
        return 'Invalid QR code';
      case ScanErrorType.wrongSequence:
        return 'Please scan at the previous gate first';
      case ScanErrorType.expiredQR:
        return 'QR code has expired';
      case ScanErrorType.guardNotAuthorized:
        return 'You are not authorized for this scan';
    }
  }
}