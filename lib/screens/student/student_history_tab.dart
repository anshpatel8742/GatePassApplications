import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/student_provider.dart';
import '../../models/trip.dart';
import '../../models/enums.dart';

class StudentHistoryTab extends StatefulWidget {
  const StudentHistoryTab({Key? key}) : super(key: key);

  @override
  State<StudentHistoryTab> createState() => _StudentHistoryTabState();
}

class _StudentHistoryTabState extends State<StudentHistoryTab> {
  final _scrollController = ScrollController();
  bool _isRefreshing = false;
  String? _error;
  final _dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData(StudentProvider provider) async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      await provider.initialize(provider.student?.uid ?? '');
    } catch (e) {
      setState(() => _error = 'Failed to refresh trip history');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<StudentProvider>(context);
    final trips = _getFilteredTrips(provider.trips);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refreshData(provider),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            if (_error != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(
                  error: _error!,
                  onRetry: () => _refreshData(provider),
                ),
              ),
            if (trips.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  isLoading: _isRefreshing,
                  onRetry: () => _refreshData(provider),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.separated(
                  itemCount: trips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) => 
                    _TripCard(
                      trip: trips[index],
                      tripNumber: trips.length - index,
                      dateFormat: _dateFormat,
                    ),
                ),
              ),
            if (_isRefreshing && trips.isNotEmpty)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  List<Trip> _getFilteredTrips(List<Trip> trips) {
    return trips
        .where((trip) => trip.isCompleted)
        .toList()
        .reversed
        .toList();
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onRetry;

  const _EmptyState({required this.isLoading, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Trip History',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed trips will appear here',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isLoading ? null : onRetry,
              child: isLoading 
                  ? const CircularProgressIndicator()
                  : const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final int tripNumber;
  final DateFormat dateFormat;

  const _TripCard({
    required this.trip,
    required this.tripNumber,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _calculateTripDuration(trip);
    final statusColor = _getStatusColor(trip.sequenceStatus, theme);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showTripDetails(context, trip),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(tripNumber, duration, statusColor, theme),
              const SizedBox(height: 12),
              _buildStatusChips(trip, theme),
              const SizedBox(height: 12),
              _buildTimeline(trip),
            ],
          ),
        ),
      ),
    );
  }

  void _showTripDetails(BuildContext context, Trip trip) {
    // TODO: Implement trip details dialog
  }

  Widget _buildHeader(int tripNumber, String duration, Color color, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Trip #$tripNumber',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Chip(
          label: Text(
            duration,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
          backgroundColor: color.withOpacity(0.1),
        ),
      ],
    );
  }

  Widget _buildStatusChips(Trip trip, ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _StatusChip(
          label: 'Type: ${trip.leaveType.name.toUpperCase()}',
          color: theme.colorScheme.primary,
        ),
        _StatusChip(
          label: 'Status: ${_formatSequenceStatus(trip.sequenceStatus)}',
          color: _getStatusColor(trip.sequenceStatus, theme),
        ),
        if (trip.isOverdue)
          _StatusChip(
            label: 'OVERDUE',
            color: theme.colorScheme.error,
          ),
      ],
    );
  }

  Widget _buildTimeline(Trip trip) {
    final events = [
      if (trip.hostelExitTime != null)
        _TimelineEvent(
          icon: Icons.exit_to_app,
          title: 'Exited Hostel',
          time: dateFormat.format(trip.hostelExitTime!),
          guard: _getGuardName(trip.hostelExitEvent),
          isFirst: true,
        ),
      if (trip.mainExitTime != null)
        _TimelineEvent(
          icon: Icons.door_front_door,
          title: 'Exited Main Gate',
          time: dateFormat.format(trip.mainExitTime!),
          guard: _getGuardName(trip.mainExitEvent),
        ),
      if (trip.mainEntryTime != null)
        _TimelineEvent(
          icon: Icons.door_back_door,
          title: 'Entered Main Gate',
          time: dateFormat.format(trip.mainEntryTime!),
          guard: _getGuardName(trip.mainEntryEvent),
        ),
      if (trip.hostelEntryTime != null)
        _TimelineEvent(
          icon: Icons.login,
          title: 'Returned to Hostel',
          time: dateFormat.format(trip.hostelEntryTime!),
          guard: _getGuardName(trip.hostelEntryEvent),
          isLast: true,
        ),
    ];

    return Column(
      children: events,
    );
  }

  String _calculateTripDuration(Trip trip) {
    final exitTime = trip.hostelExitTime;
    final returnTime = trip.hostelEntryTime;

    if (exitTime == null || returnTime == null) return 'N/A';

    final duration = returnTime.difference(exitTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _getGuardName(Map<String, dynamic>? event) {
    if (event == null) return 'Unknown';
    final guardId = event['guardId'] as String? ?? 'Unknown';
    return guardId.split('_').first;
  }

  String _formatSequenceStatus(SequenceStatus status) {
    return status.toString().split('.').last.replaceAll('_', ' ').capitalize();
  }

  Color _getStatusColor(SequenceStatus status, ThemeData theme) {
    switch (status) {
      case SequenceStatus.completed:
        return theme.colorScheme.primary;
      case SequenceStatus.invalid:
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.secondary;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final String guard;
  final bool isFirst;
  final bool isLast;

  const _TimelineEvent({
    required this.icon,
    required this.title,
    required this.time,
    required this.guard,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (!isFirst) Container(
              width: 1,
              height: 8,
              color: Colors.grey.shade300,
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
            if (!isLast) Container(
              width: 1,
              height: 8,
              color: Colors.grey.shade300,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Scanned by: $guard',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}