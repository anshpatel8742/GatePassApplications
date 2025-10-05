import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/student_provider.dart';
import '../../models/notification.dart' as app_notification;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isRefreshing = false;
  String? _error;

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      await Provider.of<StudentProvider>(context, listen: false).refreshAllData();
    } catch (e) {
      setState(() => _error = 'Failed to refresh notifications');
      debugPrint('Refresh error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.any((n) => !n.isRead))
            IconButton(
              icon: const Icon(Icons.mark_as_unread),
              tooltip: 'Mark all as read',
              onPressed: () => _markAllAsRead(provider),
            ),
          IconButton(
            icon: _isRefreshing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(provider, notifications),
    );
  }

  Widget _buildBody(StudentProvider provider, List<app_notification.Notification> notifications) {
    if (_error != null && notifications.isEmpty) {
      return _buildErrorState();
    }

    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) => _NotificationItem(
          notification: notifications[i],
          onTap: () {
            provider.markNotificationAsRead(notifications[i].id);
            _handleNotificationTap(context, notifications[i]);
          },
        ),
      ),
    );
  }

  Future<void> _markAllAsRead(StudentProvider provider) async {
    try {
      await provider.markAllNotificationsAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked all as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Failed to load notifications',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications here when you have them',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    app_notification.Notification notification,
  ) {
    // Implement proper navigation based on notification type
    switch (notification.type) {
      case app_notification.NotificationType.leave_approved:
      case app_notification.NotificationType.leave_rejected:
        Navigator.pushNamed(
          context,
          '/leave-details',
          arguments: notification.relatedLeaveId,
        );
        break;
      case app_notification.NotificationType.gate_scan:
        Navigator.pushNamed(context, '/trip-details');
        break;
      case app_notification.NotificationType.emergency:
        Navigator.pushNamed(context, '/emergency-info');
        break;
      default:
        // Default action or do nothing
        break;
    }
  }
}

class _NotificationItem extends StatelessWidget {
  final app_notification.Notification notification;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        _getNotificationIcon(notification.type),
        color: notification.isRead ? Colors.grey : Theme.of(context).primaryColor,
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          color: notification.isHighPriority ? Colors.red : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM dd, yyyy - hh:mm a').format(notification.createdAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
      trailing: !notification.isRead
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  IconData _getNotificationIcon(app_notification.NotificationType type) {
    switch (type) {
      case app_notification.NotificationType.leave_approved:
        return Icons.check_circle;
      case app_notification.NotificationType.leave_rejected:
        return Icons.cancel;
      case app_notification.NotificationType.gate_scan:
        return Icons.qr_code_scanner;
      case app_notification.NotificationType.overdue_alert:
        return Icons.timer_off;
      case app_notification.NotificationType.emergency:
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }
}