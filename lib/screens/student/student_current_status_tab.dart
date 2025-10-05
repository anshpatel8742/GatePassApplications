import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/leave_request.dart';
import '../../models/trip.dart';
import '../../models/enums.dart';

class StudentCurrentStatusTab extends StatefulWidget {
  const StudentCurrentStatusTab({Key? key}) : super(key: key);

  @override
  State<StudentCurrentStatusTab> createState() => _StudentCurrentStatusTabState();
}

class _StudentCurrentStatusTabState extends State<StudentCurrentStatusTab> {
   Timer? _qrRefreshTimer;
  bool _authInitialized = false;


  @override
  void initState() {
    super.initState();
    _setupQRRefreshTimer();
     _checkAuthState();
  }


 void _checkAuthState() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated && auth.userRole == UserRole.student) {
      _initializeStudentData(auth.user!.uid);
    }
  }

  
Future<void> _initializeStudentData(String uid) async {
  try {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    // Always use the UID directly - don't extract from email
    await studentProvider.initialize(uid);
    setState(() => _authInitialized = true);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Initialization failed: ${e.toString()}')),
      );
    }
  }
}


  void _setupQRRefreshTimer() {
    _qrRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      final studentProvider = Provider.of<StudentProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await studentProvider.initialize(authProvider.user!.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = Provider.of<StudentProvider>(context);

    
    final activeRequests = studentProvider.leaveRequests.where((req) => !req.isTerminal).toList();

    if (studentProvider.error != null && activeRequests.isEmpty) {
      return _buildErrorState(studentProvider.error!);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildStatsHeader(studentProvider)),
            _buildRequestsList(activeRequests, studentProvider.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(StudentProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Leaves',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatChip(
                count: provider.leaveRequests.where((r) => r.isApproved).length,
                label: 'Approved',
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                count: provider.leaveRequests.where((r) => r.isPending).length,
                label: 'Pending',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({required int count, required String label, required Color color}) {
    return Chip(
      label: Text('$count $label'),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
      shape: StadiumBorder(side: BorderSide(color: color)),
    );
  }

  Widget _buildRequestsList(List<LeaveRequest> requests, bool isLoading) {
    if (isLoading && requests.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading leave requests...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (requests.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, index) => _buildRequestCard(requests[index]),
        childCount: requests.length,
      ),
    );
  }

  Widget _buildRequestCard(LeaveRequest request) {
    final isExpired = request.isOverdue;
    
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      color: isExpired ? Colors.grey[100] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isExpired)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      'Overdue',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTypeChip(request.type),
                _buildStatusIndicator(request),
              ],
            ),
            const SizedBox(height: 12),
            _buildTimeline(request),
            if (request.isApproved) _buildApprovedActions(request),
            if (request.isPending) _buildPendingActions(request),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(LeaveType type) {
    return Chip(
      label: Text(
        type == LeaveType.day ? 'Day Leave' : 'Home Leave',
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: type == LeaveType.day 
          ? Colors.blue.withOpacity(0.2) 
          : Colors.purple.withOpacity(0.2),
    );
  }

 

   Widget _buildTimeline(LeaveRequest request) {
    return StreamBuilder<Trip>(
      stream: Provider.of<TripProvider>(context).watchTrip(request.tripId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        
        final trip = snapshot.data!;
        return Column(
          children: [
            _buildSequenceStatus(trip.sequenceStatus),
            ..._buildEventMarkers(trip),
          ],
        );
      },
    );
  }



  Widget _buildSequenceStatus(SequenceStatus status) {
    return Chip(
      label: Text(status.displayName),
      backgroundColor: status.isComplete 
          ? Colors.green[50]
          : Colors.orange[50],
    );
  }

  List<Widget> _buildEventMarkers(Trip trip) {
    return [
      if (trip.hostelExitTime != null)
        _TimelineEvent('Hostel Exit', trip.hostelExitTime!),
      if (trip.mainExitTime != null)
        _TimelineEvent('Campus Exit', trip.mainExitTime!),
      if (trip.mainEntryTime != null)
        _TimelineEvent('Campus Entry', trip.mainEntryTime!),
      if (trip.hostelEntryTime != null)
        _TimelineEvent('Hostel Entry', trip.hostelEntryTime!),
    ].map(_buildTimelineItem).toList();
  }

  Widget _buildStatusIndicator(LeaveRequest request) {
    final statusInfo = {
      LeaveStatus.pending_guard: (Colors.orange, 'Pending Guard'),
      LeaveStatus.pending_warden: (Colors.orange, 'Pending Warden'),
      LeaveStatus.approved: (Colors.green, 'Approved'),
      LeaveStatus.active: (Colors.blue, 'Active'),
      LeaveStatus.completed: (Colors.grey, 'Completed'),
      LeaveStatus.cancelled: (Colors.red, 'Cancelled'),
    }[request.status] ?? (Colors.grey, 'Unknown');

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: statusInfo.$1,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(statusInfo.$2),
      ],
    );
  }

   Future<void> _showQrDialog(LeaveRequest request) async {
    try {
      if (!request.canGenerateQR) {
        throw StateError('Leave not in QR-generatable state');
      }

      final qrData = await Provider.of<StudentProvider>(context, listen: false)
          .generateLeaveQR(request.id);
      
      final expiry = request.returnTimePlanned ?? 
                    request.exitTimePlanned.add(const Duration(hours: 24));

      showDialog(
        context: context,
        builder: (_) => GatePassDialog(
          qrData: qrData,
          expiry: expiry,
          studentName: request.studentName,
          hostelName: request.hostelName,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Error: ${e.toString()}')),
      );
    }
  }


 Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.list_alt, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No active leave requests'),
          const SizedBox(height: 8),
          TextButton(
            child: const Text('REFRESH'),
            onPressed: _refreshData,
          ),
        ],
      ),
    );
  }




  Widget _buildTimelineItem(_TimelineEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  DateFormat('MMM dd, hh:mm a').format(event.time),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedActions(LeaveRequest request) {
    return Column(
      children: [
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.qr_code),
          label: const Text('SHOW GATE PASS'),
          onPressed: () => _showQrDialog(request),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        if (request.canBeCancelled) ...[
          const SizedBox(height: 8),
          TextButton(
            child: const Text('CANCEL REQUEST'),
            onPressed: () => _confirmCancel(request),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingActions(LeaveRequest request) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            request.needsWardenApproval 
                ? 'Pending warden approval' 
                : 'Pending guard approval',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const Spacer(),
          if (request.canBeCancelled)
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () => _confirmCancel(request),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(LeaveRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content: const Text('Are you sure you want to cancel this request?'),
        actions: [
          TextButton(
            child: const Text('NO'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('YES'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<StudentProvider>(context, listen: false)
            .cancelLeaveRequest(request.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cancelled')),
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
  }

  
}

class _TimelineEvent {
  final String label;
  final DateTime time;
  
  _TimelineEvent(this.label, this.time);
}


class GatePassDialog extends StatelessWidget {
  final String qrData;
  final DateTime expiry;
  final String studentName;
  final String hostelName;

  const GatePassDialog({
    required this.qrData,
    required this.expiry,
    required this.studentName,
    required this.hostelName,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = DateTime.now().isAfter(expiry);
    
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isExpired ? 'EXPIRED PASS' : 'ACTIVE GATE PASS'),
          Text(studentName, style: Theme.of(context).textTheme.titleSmall),
          Text(hostelName, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: qrData,
            size: 200,
            backgroundColor: isExpired ? Colors.grey[200]! : Colors.white,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status:', style: Theme.of(context).textTheme.bodyMedium),
              Chip(
                label: Text(isExpired ? 'EXPIRED' : 'ACTIVE'),
                backgroundColor: isExpired ? Colors.red[50] : Colors.green[50],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Valid until:', style: Theme.of(context).textTheme.bodyMedium),
              Text(DateFormat('MMM dd, hh:mm').format(expiry)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('CLOSE'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
