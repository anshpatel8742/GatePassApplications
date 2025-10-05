import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  leave_approved,
  leave_rejected,
  gate_scan,
  overdue_alert,
  emergency;

  factory NotificationType.fromString(String value) {
    return values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => NotificationType.gate_scan,
    );
  }

  @override
  String toString() => name;
}

class Notification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? relatedLeaveId;
  final bool isRead;
  final DateTime createdAt;
  final NotificationType type;
  final Map<String, dynamic>? data;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.relatedLeaveId,
    bool? isRead,
    DateTime? createdAt,
    required this.type,
    this.data,
  })  : isRead = isRead ?? false,
        createdAt = createdAt ?? DateTime.now();

  factory Notification.fromFirestore(Map<String, dynamic> data, String id) {
    return Notification(
      id: id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      body: data['body'] as String,
      relatedLeaveId: data['relatedLeaveId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      type: NotificationType.fromString(data['type'] as String),
      data: data['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      if (relatedLeaveId != null) 'relatedLeaveId': relatedLeaveId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type.toString(),
      if (data != null) 'data': data,
    };
  }

  void validate() {
    if (title.isEmpty || body.isEmpty) {
      throw ArgumentError('Title and body cannot be empty');
    }
    
    if (userId.isEmpty) {
      throw ArgumentError('User ID is required');
    }
    
    if (type == NotificationType.leave_approved && relatedLeaveId == null) {
      throw ArgumentError('Leave approval notifications require leave ID');
    }
  }

  Notification copyWith({
  String? id,
  String? userId,
  String? title,
  String? body,
  String? relatedLeaveId,
  bool? isRead,
  DateTime? createdAt,
  NotificationType? type,  // Changed from String? to NotificationType?
  Map<String, dynamic>? data,
}) {
  return Notification(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    body: body ?? this.body,
    relatedLeaveId: relatedLeaveId ?? this.relatedLeaveId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt ?? this.createdAt,
    type: type ?? this.type,  // Now using NotificationType directly
    data: data ?? this.data,
  );
}
  // Helpers
  bool get isHighPriority => type == NotificationType.emergency || 
                          type == NotificationType.overdue_alert;
}