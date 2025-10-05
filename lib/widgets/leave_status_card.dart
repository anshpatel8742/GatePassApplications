import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/leave_request.dart';
import '../models/enums.dart';

class LeaveStatusCard extends StatelessWidget {
  final LeaveRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool showActions;

  const LeaveStatusCard({
    super.key,
    required this.request,
    this.onApprove,
    this.onReject,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request.type == LeaveType.day ? 'Day Pass' : 'Home Pass',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(context),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Student: ${request.studentRoll}'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.receipt, 'Reason: ${request.reason}'),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.exit_to_app,
              'Exit: ${_formatDate(request.exitTimePlanned)}',
            ),
            if (request.returnTimePlanned != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.login,
                'Return: ${_formatDate(request.returnTimePlanned!)}',
              ),
            ],
            if (showActions && (onApprove != null || onReject != null)) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onReject != null)
                    OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Reject'),
                    ),
                  if (onReject != null && onApprove != null)
                    const SizedBox(width: 12),
                  if (onApprove != null)
                    ElevatedButton(
                      onPressed: onApprove,
                      child: const Text('Approve'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final (backgroundColor, textColor, label) = switch (request.status) {
      LeaveStatus.draft => (
          Colors.grey.shade100,
          Colors.grey.shade800,
          'Draft'
        ),
      LeaveStatus.pending_guard => (
          Colors.orange.shade100,
          Colors.orange.shade800,
          'Pending Guard'
        ),
      LeaveStatus.pending_warden => (
          Colors.amber.shade100,
          Colors.amber.shade800,
          'Pending Warden'
        ),
      LeaveStatus.approved => (
          Colors.green.shade100,
          Colors.green.shade800,
          'Approved'
        ),
      LeaveStatus.active => (
          Colors.lightGreen.shade100,
          Colors.lightGreen.shade800,
          'Active'
        ),
      LeaveStatus.rejected => (
          Colors.red.shade100,
          Colors.red.shade800,
          'Rejected'
        ),
      LeaveStatus.completed => (
          Colors.blue.shade100,
          Colors.blue.shade800,
          'Completed'
        ),
      LeaveStatus.cancelled => (
          Colors.grey.shade100,
          Colors.grey.shade800,
          'Cancelled'
        ),
      LeaveStatus.expired => (
          Colors.purple.shade100,
          Colors.purple.shade800,
          'Expired'
        ),
      LeaveStatus.recalled => (
          Colors.deepOrange.shade100,
          Colors.deepOrange.shade800,
          'Recalled'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}