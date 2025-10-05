import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/guard_provider.dart';
import '../../models/trip.dart';
import '../../models/leave_request.dart';
import '../../models/enums.dart';

class GuardActiveTripsTab extends StatefulWidget {
  const GuardActiveTripsTab({Key? key}) : super(key: key);

  @override
  State<GuardActiveTripsTab> createState() => _GuardActiveTripsTabState();
}

class _GuardActiveTripsTabState extends State<GuardActiveTripsTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _showOnlyOverdue = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GuardProvider>(context);
    final activeTrips = _filterTrips(provider.activeTrips);

    return Column(
      children: [
        _buildFilterBar(context),
        if (activeTrips.isEmpty)
          _buildEmptyState()
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.refreshData(),
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: activeTrips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final trip = activeTrips[index];
                  return _buildTripCard(context, trip, provider);
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
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Overdue Only'),
            selected: _showOnlyOverdue,
            onSelected: (value) => setState(() => _showOnlyOverdue = value),
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
            Icon(Icons.directions_walk, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No active trips',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            if (_showOnlyOverdue) ...[
              const SizedBox(height: 4),
              const Text(
                'No overdue trips found',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip, GuardProvider provider) {
    final dateFormat = DateFormat('MMM dd, hh:mm a');
    final isOverdue = trip.isOverdue;
    final leaveRequest = provider.getLeaveRequestForTrip(trip.id);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isOverdue ? Colors.red : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showTripDetails(context, trip, leaveRequest),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStudentHeader(trip),
              const SizedBox(height: 12),
              _buildTripDetails(trip, dateFormat),
              if (isOverdue) _buildOverdueActions(context, trip, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader(Trip trip) {
    return Row(
      children: [
        CircleAvatar(
          child: Text(trip.studentRoll.substring(trip.studentRoll.length - 2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.studentName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                trip.studentRoll,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Chip(
          label: Text(
            trip.leaveType.toString().split('.').last.toUpperCase(),
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: trip.leaveType == LeaveType.day
              ? Colors.blue[50]
              : Colors.green[50],
        ),
      ],
    );
  }

  Widget _buildTripDetails(Trip trip, DateFormat dateFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trip.hostelExitTime != null)
          _buildDetailRow(
            Icons.exit_to_app,
            'Exited: ${dateFormat.format(trip.hostelExitTime!)}',
          ),
        if (trip.mainExitTime != null)
          _buildDetailRow(
            Icons.directions_walk,
            'Left campus: ${dateFormat.format(trip.mainExitTime!)}',
          ),
        if (trip.expectedReturn != null)
          _buildDetailRow(
            Icons.timer,
            'Expected return: ${dateFormat.format(trip.expectedReturn!)}',
            valueColor: trip.isOverdue ? Colors.red : null,
          ),
        if (trip.isOverdue)
          _buildDetailRow(
            Icons.warning,
            'Overdue by ${_formatDuration(trip.remainingTime?.abs() ?? Duration.zero)}',
            valueColor: Colors.red,
          ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: valueColor ?? Colors.grey),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueActions(BuildContext context, Trip trip, GuardProvider provider) {
    return Column(
      children: [
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.notification_add, size: 16),
              label: const Text('Notify Warden'),
              onPressed: () => _notifyWarden(context, trip, provider),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.phone, size: 16),
              label: const Text('Call Student'),
              onPressed: () => _callStudent(trip),
            ),
          ],
        ),
      ],
    );
  }

  List<Trip> _filterTrips(List<Trip> trips) {
    var filtered = trips.where((trip) {
      final matchesSearch = _searchController.text.isEmpty ||
          trip.studentRoll.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          trip.studentName.toLowerCase().contains(_searchController.text.toLowerCase());

      final matchesOverdueFilter = !_showOnlyOverdue || trip.isOverdue;

      return matchesSearch && matchesOverdueFilter;
    }).toList();

    // Sort by urgency (most overdue first)
    filtered.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      return (b.remainingTime?.abs() ?? Duration.zero)
          .compareTo(a.remainingTime?.abs() ?? Duration.zero);
    });

    return filtered;
  }

  String _formatDuration(Duration duration) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  Future<void> _notifyWarden(BuildContext context, Trip trip, GuardProvider provider) async {
    try {
      await provider.notifyOverdueStudent(trip.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warden notified'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _callStudent(Trip trip) async {
    // Implementation would depend on your contact system
    debugPrint('Calling student: ${trip.studentName}');
  }

  Future<void> _showTripDetails(BuildContext context, Trip trip, LeaveRequest? leaveRequest) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TripDetailsBottomSheet(trip: trip, leaveRequest: leaveRequest),
    );
  }
}

class _TripDetailsBottomSheet extends StatelessWidget {
  final Trip trip;
  final LeaveRequest? leaveRequest;

  const _TripDetailsBottomSheet({required this.trip, this.leaveRequest});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');

    return Padding(
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
                    'Trip Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    label: 'Student',
                    value: '${trip.studentName} (${trip.studentRoll})',
                  ),
                  _DetailRow(
                    label: 'Hostel',
                    value: trip.hostelName,
                  ),
                  _DetailRow(
                    label: 'Leave Type',
                    value: trip.leaveType.toString().split('.').last,
                  ),
                  if (leaveRequest != null) ...[
                    _DetailRow(
                      label: 'Reason',
                      value: leaveRequest!.reason,
                    ),
                  ],
                  if (trip.hostelExitTime != null)
                    _DetailRow(
                      label: 'Hostel Exit',
                      value: dateFormat.format(trip.hostelExitTime!),
                    ),
                  if (trip.mainExitTime != null)
                    _DetailRow(
                      label: 'Campus Exit',
                      value: dateFormat.format(trip.mainExitTime!),
                    ),
                  if (trip.expectedReturn != null)
                    _DetailRow(
                      label: 'Expected Return',
                      value: dateFormat.format(trip.expectedReturn!),
                      valueColor: trip.isOverdue ? Colors.red : null,
                    ),
                  if (trip.isOverdue)
                    _DetailRow(
                      label: 'Overdue By',
                      value: _formatDuration(trip.remainingTime?.abs() ?? Duration.zero),
                      valueColor: Colors.red,
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
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