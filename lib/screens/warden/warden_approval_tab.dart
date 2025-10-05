import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/leave_request.dart';
import '../../providers/warden_provider.dart';
import '../../models/enums.dart';

class WardenApprovalTab extends StatefulWidget {
  const WardenApprovalTab({Key? key}) : super(key: key);

  @override
  State<WardenApprovalTab> createState() => _WardenApprovalTabState();
}

class _WardenApprovalTabState extends State<WardenApprovalTab> {
  final _verificationControllers = <String, TextEditingController>{};
  final _verificationCodes = <String, String>{};
  final _expandedCards = <String, bool>{};
  final _random = Random();

  @override
  void dispose() {
    _verificationControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wardenProvider = Provider.of<WardenProvider>(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.pending_actions, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Pending Home Leave Approvals',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: wardenProvider.fetchPendingHomeRequests,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: wardenProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : wardenProvider.pendingHomeRequests.isEmpty
                  ? _buildEmptyState(theme)
                  : RefreshIndicator.adaptive(
                      onRefresh: wardenProvider.fetchPendingHomeRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: wardenProvider.pendingHomeRequests.length,
                        itemBuilder: (ctx, index) {
                          final request = wardenProvider.pendingHomeRequests[index];
                          _verificationControllers.putIfAbsent(
                            request.id, 
                            () => TextEditingController()
                          );
                          _expandedCards.putIfAbsent(request.id, () => false);

                         return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: _buildLeaveRequestCard(context, request, wardenProvider),
)
.animate()
.fadeIn(delay: 100.ms * index);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
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
            'No pending approvals',
            style: theme.textTheme.titleMedium,
          ),
          Text(
            'All home leave requests are processed',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestCard(
    BuildContext context,
    LeaveRequest request,
    WardenProvider provider,
  ) {
    final theme = Theme.of(context);
    final isExpanded = _expandedCards[request.id] ?? false;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
     ), child: InkWell(
        onTap: () => setState(() => _expandedCards[request.id] = !isExpanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            children: [
              ListTile(
                leading: Container(
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
                title: Text(
                  request.studentName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Hostel ${request.hostelName}',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              if (isExpanded) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Leave Date',
                        DateFormat('MMM dd, yyyy').format(request.exitTimePlanned),
                      ),
                      _buildDetailRow(
                        Icons.access_time,
                        'From',
                        DateFormat('hh:mm a').format(request.exitTimePlanned),
                      ),
                      _buildDetailRow(
                        Icons.access_time,
                        'To',
                        DateFormat('MMM dd, yyyy - hh:mm a')
                            .format(request.returnTimePlanned ?? 
                                    request.exitTimePlanned.add(const Duration(hours: 24))),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reason:',
                        style: theme.textTheme.labelSmall,
                      ),
                      Text(
                        request.reason,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parent Verification',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('Call'),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.secondaryContainer,
                                foregroundColor: theme.colorScheme.onSecondaryContainer,
                              ),
                              onPressed: () => _callParent(request),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.sms, size: 18),
                              label: const Text('SMS Code'),
                              onPressed: () => _sendVerificationCode(request),
                            ),
                          ),
                        ],
                      ),
                      if (_verificationCodes.containsKey(request.id)) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _verificationControllers[request.id],
                          decoration: InputDecoration(
                            labelText: 'Enter 4-digit code',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.check_circle),
                              onPressed: () => _verifyCode(
                                request, 
                                _verificationControllers[request.id]!.text,
                                provider,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showRejectDialog(context, request, provider),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _approveLeave(request, provider),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  void _callParent(LeaveRequest request) {
    // In a real app, implement actual call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling parent for ${request.studentName}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sendVerificationCode(LeaveRequest request) {
    final code = _generateRandomCode();
    setState(() => _verificationCodes[request.id] = code);
    
    // In a real app, implement actual SMS sending
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verification code sent: $code'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _verifyCode(LeaveRequest request, String enteredCode, WardenProvider provider) {
    if (_verificationCodes[request.id] == enteredCode) {
      provider.approveHomeLeave(
        leaveRequestId: request.id,
        verificationMethod: VerificationMethod.sms,
        verificationCode: enteredCode,
      );
      setState(() {
        _verificationCodes.remove(request.id);
        _verificationControllers[request.id]?.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid verification code'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _approveLeave(LeaveRequest request, WardenProvider provider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Leave'),
        content: const Text('Have you verified with the parent?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Approve'),
          ),
        ],
      ),
    );

    if (result == true) {
      await provider.approveHomeLeave(
        leaveRequestId: request.id,
        verificationMethod: VerificationMethod.call,
      );
    }
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    LeaveRequest request,
    WardenProvider provider,
  ) async {
    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please specify reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result == true && reasonController.text.isNotEmpty) {
      await provider.rejectHomeLeave(request.id, reasonController.text);
    }
  }

  String _generateRandomCode() => (1000 + _random.nextInt(9000)).toString();
}


