
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/guard_provider.dart';
import '../../models/leave_request.dart';
import '../../models/enums.dart';
import '../../providers/guard_type_provider.dart';
// Add import at top of file:
import '../../models/trip.dart';
// Add import:
import 'package:firebase_core/firebase_core.dart';


class GuardPendingRequestsTab extends StatefulWidget {
  const GuardPendingRequestsTab({Key? key}) : super(key: key);

  @override
  State<GuardPendingRequestsTab> createState() => _GuardPendingRequestsTabState();
}

class _GuardPendingRequestsTabState extends State<GuardPendingRequestsTab> {
  LeaveType? _filterType;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GuardProvider>(context);
    final isHostelGuard = provider.role == UserRole.hostelGuard;
    final pendingRequests = _filterRequests(provider.pendingRequests, isHostelGuard);

    return Column(
      children: [
        _buildFilterBar(context),
        if (pendingRequests.isEmpty)
          _buildEmptyState()
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.refreshData(),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: pendingRequests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final request = pendingRequests[index];
                  return _buildRequestCard(context, request, isHostelGuard);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by roll no or name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<LeaveType>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) {
              setState(() => _filterType = type);
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Types'),
              ),
              ...LeaveType.values.map((type) => PopupMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            if (_filterType != null) ...[
              const SizedBox(height: 4),
              Text(
                'No ${_filterType.toString().split('.').last.toLowerCase()} requests',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(
      BuildContext context, LeaveRequest request, bool isHostelGuard) {
    final dateFormat = DateFormat('MMM dd, hh:mm a');
    final timeUntilLeave = request.exitTimePlanned.difference(DateTime.now());
    final isUrgent = timeUntilLeave.inHours < 2;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isUrgent ? Colors.orange : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showRequestDetails(context, request),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStudentHeader(request),
              const SizedBox(height: 12),
              _buildRequestDetails(request, dateFormat),
              if (isUrgent) _buildUrgentIndicator(timeUntilLeave),
              const Divider(height: 24),
              if (isHostelGuard || request.type != LeaveType.day)
                _buildActionButtons(context, request),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader(LeaveRequest request) {
    return Row(
      children: [
        CircleAvatar(
          child: Text(request.studentRoll.substring(request.studentRoll.length - 2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.studentName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                request.studentRoll,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Chip(
          label: Text(
            request.type.toString().split('.').last.toUpperCase(),
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: request.type == LeaveType.day
              ? Colors.blue[50]
              : Colors.green[50],
        ),
      ],
    );
  }

  Widget _buildRequestDetails(LeaveRequest request, DateFormat dateFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          request.reason,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTimeChip(
              Icons.exit_to_app,
              dateFormat.format(request.exitTimePlanned),
            ),
            if (request.returnTimePlanned != null) ...[
              const SizedBox(width: 8),
              _buildTimeChip(
                Icons.login,
                dateFormat.format(request.returnTimePlanned!),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildUrgentIndicator(Duration timeUntilLeave) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.timer, size: 16, color: Colors.orange),
          const SizedBox(width: 4),
          Text(
            'Leaves in ${timeUntilLeave.inMinutes} minutes',
            style: const TextStyle(color: Colors.orange),
          ),
        ],
      ),
    );
  }

Widget _buildActionButtons(BuildContext context, LeaveRequest request) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
        ),
        onPressed: () => _showRejectDialog(context, request),
        child: const Text('Reject'),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: () => _handleApprove(request), // Updated handler
        child: const Text('Approve'),
      ),
    ],
  );
}




  Widget _buildTimeChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
      backgroundColor: Colors.grey[100],
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  List<LeaveRequest> _filterRequests(List<LeaveRequest> requests, bool isHostelGuard) {
    var filtered = requests.where((req) {
      // Skip day leaves for main gate guards
      if (!isHostelGuard && req.type == LeaveType.day) return false;

      final matchesSearch = _searchController.text.isEmpty ||
          req.studentRoll.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          req.studentName.toLowerCase().contains(_searchController.text.toLowerCase());

      final matchesType = _filterType == null || req.type == _filterType;

      return matchesSearch && matchesType;
    }).toList();

    // Sort by urgency (soonest departure first)
    filtered.sort((a, b) => a.exitTimePlanned.compareTo(b.exitTimePlanned));

    return filtered;
  }

 Future<void> _approveRequest(BuildContext context, LeaveRequest request) async {
  try {
    final provider = Provider.of<GuardProvider>(context, listen: false);
    await provider.approveLeaveRequest(request.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request.studentRoll} approved - QR ready for scanning'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } on FirebaseException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approval failed: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('System error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


// Add this to validate before approval
Future<bool> _validateApproval(LeaveRequest request) async {
  if (request.status != LeaveStatus.pending_guard) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request already processed')),
    );
    return false;
  }

 if (request.type == LeaveType.home && (request.parentApproved != true)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Parent consent required for home leave')),
    );
    return false;
  }

  return true;
}



// Update _handleApprove to include QR generation
Future<void> _handleApprove(LeaveRequest request) async {
  if (!await _validateApproval(request)) return;
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Confirm Approval'),
      content: Text('Generate QR pass for ${request.studentRoll}?'),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context, false),
        ),
        TextButton(
          child: const Text('Approve'),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await _approveRequest(context, request);
  }
}



  Future<void> _showRejectDialog(BuildContext context, LeaveRequest request) async {
    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reason for rejecting ${request.studentRoll}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
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
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (result == true) {
      _processRejection(context, request, reasonController.text);
    }
  }

  Future<void> _processRejection(
      BuildContext context, LeaveRequest request, String reason) async {
    try {
      final provider = Provider.of<GuardProvider>(context, listen: false);
      await provider.rejectLeaveRequest(request.id, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.studentRoll} rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRequestDetails(BuildContext context, LeaveRequest request) async {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    final timeUntilLeave = request.exitTimePlanned.difference(DateTime.now());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave Request Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      label: 'Student',
                      value: '${request.studentName} (${request.studentRoll})',
                    ),
                    _DetailRow(
                      label: 'Hostel',
                      value: request.hostelName,
                    ),
                    _DetailRow(
                      label: 'Leave Type',
                      value: request.type.toString().split('.').last,
                    ),
                    _DetailRow(
                      label: 'Reason',
                      value: request.reason,
                    ),
                    _DetailRow(
                      label: 'Planned Exit',
                      value: dateFormat.format(request.exitTimePlanned),
                    ),
                    if (request.returnTimePlanned != null)
                      _DetailRow(
                        label: 'Planned Return',
                        value: dateFormat.format(request.returnTimePlanned!),
                      ),
                    if (timeUntilLeave.inHours < 24)
                      _DetailRow(
                        label: 'Time Until Leave',
                        value: '${timeUntilLeave.inHours}h ${timeUntilLeave.inMinutes.remainder(60)}m',
                        valueColor: timeUntilLeave.inHours < 2
                            ? Colors.red
                            : Colors.orange,
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

