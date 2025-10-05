import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/warden_provider.dart';
import '../../models/leave_request.dart';
import '../../models/enums.dart';

class WardenOverdueTab extends StatefulWidget {
  const WardenOverdueTab({Key? key}) : super(key: key);

  @override
  State<WardenOverdueTab> createState() => _WardenOverdueTabState();
}

class _WardenOverdueTabState extends State<WardenOverdueTab> {
  final Map<String, bool> _notifyingStudents = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<WardenProvider>(context);
    final overdue = provider.overdueRequests;

    return Scaffold(
      floatingActionButton: overdue.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.notifications_active),
              label: const Text('Notify All'),
              onPressed: () => _notifyAllOverdue(context, provider),
            )
          : null,
      body: RefreshIndicator.adaptive(
        onRefresh: () => provider.fetchOverdueRequests(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(
                'Overdue Students',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => provider.fetchOverdueRequests(),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            if (overdue.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No overdue students',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'All students have returned on time',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final request = overdue[index];
                      return _buildOverdueCard(
                        context,
                        request,
                        provider,
                      ).animate().fadeIn(delay: (100 * index).ms);
                    },
                    childCount: overdue.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueCard(
    BuildContext context,
    LeaveRequest request,
    WardenProvider provider,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final returnTime = request.returnTimePlanned ?? 
        request.exitTimePlanned.add(const Duration(hours: 24));
    final hoursLate = now.difference(returnTime).inHours;
    final isNotifying = _notifyingStudents[request.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: hoursLate > 24 
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.surfaceVariant,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showStudentDetails(context, request),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        request.studentRoll.substring(0, 2),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.studentName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Hostel ${request.hostelName}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (hoursLate > 24)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'CRITICAL',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onError,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Should have returned:',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(returnTime),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${hoursLate} hour${hoursLate == 1 ? '' : 's'} overdue',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                    onPressed: () => _callStudent(context, request),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: isNotifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.notification_add, size: 18),
                    label: Text(isNotifying ? 'Sending...' : 'Notify'),
                    onPressed: isNotifying
                        ? null
                        : () => _sendAlert(context, request, provider),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showStudentDetails(BuildContext context, LeaveRequest request) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request.studentName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Roll: ${request.studentRoll}'),
            Text('Hostel: ${request.hostelName}'),
            const SizedBox(height: 16),
            Text(
              'Leave Details',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(),
            Text('Reason: ${request.reason}'),
            const SizedBox(height: 8),
            Text('Left: ${DateFormat('MMM dd, hh:mm a').format(request.exitTimePlanned)}'),
            Text('Expected Return: ${DateFormat('MMM dd, hh:mm a').format(request.returnTimePlanned ?? request.exitTimePlanned.add(const Duration(hours: 24)))}'),
            const SizedBox(height: 8),
            Text(
              'Contact Info',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(),
            Text('Room: ${request.studentRoll.substring(3, 5)}'), // Assuming room in roll number
            Text('Phone: [REDACTED]'), // In real app, show actual contact
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _callStudent(BuildContext context, LeaveRequest request) async {
    // In a real app, implement actual call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling student ${request.studentName}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendAlert(
    BuildContext context,
    LeaveRequest request,
    WardenProvider provider,
  ) async {
    setState(() => _notifyingStudents[request.id] = true);
    
    try {
      await provider.notifyOverdueStudent(request.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification sent to ${request.studentName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to notify ${request.studentName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _notifyingStudents.remove(request.id));
    }
  }

  Future<void> _notifyAllOverdue(
    BuildContext context,
    WardenProvider provider,
  ) async {
    final overdue = provider.overdueRequests;
    if (overdue.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notify All Overdue Students'),
        content: Text(
          'Send notifications to all ${overdue.length} overdue students?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Notify All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifying ${overdue.length} students...'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      for (final request in overdue) {
        await _sendAlert(context, request, provider);
      }
    }
  }
}