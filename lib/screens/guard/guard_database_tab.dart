import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/trip.dart';
import '../../providers/guard_provider.dart';
import '../../models/enums.dart';


class GuardDatabaseTab extends StatefulWidget {
  const GuardDatabaseTab({Key? key}) : super(key: key);

  @override
  State<GuardDatabaseTab> createState() => _GuardDatabaseTabState();
}

class _GuardDatabaseTabState extends State<GuardDatabaseTab> {
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  bool _showOnlyOverdue = false;
  LeaveType? _selectedLeaveType;

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'active':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardProvider = Provider.of<GuardProvider>(context);
    final isHostelGuard = guardProvider.role == UserRole.hostelGuard;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Search Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search by Roll No/Name',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.filter_alt),
                    onPressed: () => _showFiltersDialog(context),
                    tooltip: 'Filters',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Date Range Row
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _selectedDateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - '
                              '${DateFormat('MMM dd').format(_selectedDateRange!.end)}',
                    ),
                    onPressed: () => _selectDateRange(context),
                  ),
                  if (_selectedDateRange != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() => _selectedDateRange = null),
                    ),
                  const Spacer(),
                  FilterChip(
                    label: const Text('Overdue Only'),
                    selected: _showOnlyOverdue,
                    onSelected: (val) => setState(() => _showOnlyOverdue = val),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Trip>>(
            stream: guardProvider.searchTrips(
              query: _searchQuery,
              dateRange: _selectedDateRange,
              showOverdue: _showOnlyOverdue,
              leaveType: _selectedLeaveType,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: ErrorWidget(snapshot.error!));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final trips = snapshot.data ?? [];

              if (trips.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No trips found'),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: trips.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  final exitTime = trip.hostelExitTime;
                  final returnTime = trip.hostelEntryTime;
                  final isOverdue = trip.isOverdue;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 1,
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(trip.status),
                        child: Text(
                          trip.studentRoll.substring(trip.studentRoll.length - 2),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        trip.studentName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip.studentRoll),
                          if (exitTime != null)
                            Text(
                              'Exit: ${DateFormat('MMM dd, hh:mm a').format(exitTime)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(trip.status.toUpperCase()),
                        backgroundColor: _getStatusColor(trip.status),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Basic Info Row
                              _InfoRow(
                                icon: Icons.home_work,
                                label: 'Hostel',
                                value: trip.hostelName,
                              ),
                              _InfoRow(
                                icon: Icons.timer,
                                label: 'Duration',
                                value: _formatDuration(trip.timeOutsideHostel),
                              ),
                              // Exit/Entry Details
                              if (exitTime != null)
                                _ScanDetailRow(
                                  type: 'Hostel Exit',
                                  time: exitTime,
                                  guardId: trip.getGuardForEvent(GateEventType.hostel_exit),
                                ),
                              if (returnTime != null)
                                _ScanDetailRow(
                                  type: 'Hostel Entry',
                                  time: returnTime,
                                  guardId: trip.getGuardForEvent(GateEventType.hostel_entry),
                                ),
                              // Overdue Warning
                              if (isOverdue)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Overdue by ${_formatDuration(trip.remainingTime?.abs())}',
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              // Action Buttons
                              if (isHostelGuard && isOverdue)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.notification_important),
                                    label: const Text('Notify Warden'),
                                    onPressed: () => guardProvider.notifyOverdueStudent(trip.id),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showFiltersDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<LeaveType>(
              value: _selectedLeaveType,
              decoration: const InputDecoration(labelText: 'Leave Type'),
              items: LeaveType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedLeaveType = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _selectedLeaveType = null;
              Navigator.pop(context);
            }),
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ScanDetailRow extends StatelessWidget {
  final String type;
  final DateTime time;
  final String? guardId;

  const _ScanDetailRow({
    required this.type,
    required this.time,
    this.guardId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.qr_code_scanner, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$type at ${DateFormat('hh:mm a').format(time)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (guardId != null)
                  Text(
                    'By ${guardId!.split('_').last}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}