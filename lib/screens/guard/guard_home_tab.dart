import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/guard_provider.dart';
import '../../models/trip.dart';
import '../../models/enums.dart';
import '../../providers/guard_type_provider.dart';


class GuardHomeTab extends StatefulWidget {
  const GuardHomeTab({Key? key}) : super(key: key);

  @override
  State<GuardHomeTab> createState() => _GuardHomeTabState();
}

class _GuardHomeTabState extends State<GuardHomeTab> {
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
    }}
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GuardProvider>(context);
    final isHostelGuard = provider.role == UserRole.hostelGuard;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => await provider.refreshData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Overview Row
            _buildStatsGrid(provider, theme),
            const SizedBox(height: 24),
            
            // Alerts Section
            if (provider.overdueTrips.isNotEmpty) ...[
              _buildSectionHeader('Priority Alerts', Icons.warning, Colors.red),
              _buildOverdueList(provider),
              const SizedBox(height: 16),
            ],
            
            // Recent Activity
            _buildSectionHeader('Recent Activity', Icons.history, theme.primaryColor),
            _buildRecentActivityList(provider),
            
            // Quick Actions
            if (isHostelGuard) ...[
              const SizedBox(height: 24),
              _buildSectionHeader('Quick Actions', Icons.bolt, theme.primaryColor),
              _buildQuickActions(context, provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(GuardProvider provider, ThemeData theme) {
     final guardType = Provider.of<GuardTypeProvider>
     (context);


    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _StatCard(
          icon: Icons.how_to_reg,
          value: provider.todayApprovals.toString(),
          label: 'Approved Today',
          color: Colors.green,
        ),
        _StatCard(
          icon: Icons.pending_actions,
          value: provider.pendingRequests.length.toString(),
          label: 'Pending Requests',
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.person_outline,
          value: provider.activeTrips.length.toString(),
          label: 'Active Trips',
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.warning,
          value: provider.overdueTrips.length.toString(),
          label: 'Overdue',
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildOverdueList(GuardProvider provider) {
  return Card(
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Colors.red.shade200, width: 1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: provider.overdueTrips.take(3).map((trip) {
        final overdueDuration = trip.remainingTime?.abs() ?? Duration.zero;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: Text(trip.studentRoll.substring(trip.studentRoll.length - 2)),),
          title: Text(trip.studentName),
          subtitle: Text(
            'Overdue by ${overdueDuration.inHours}h ${overdueDuration.inMinutes.remainder(60)}m',
            style: const TextStyle(color: Colors.red),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.notification_add),
            color: Colors.red,
            onPressed: () => provider.notifyOverdueStudent(trip.id),
          ),
        );
      }).toList(),
    ),
  );
}

Widget _buildRecentActivityList(GuardProvider provider) {
  final dateFormat = DateFormat('MMM dd, hh:mm a');
  return Card(
    child: Column(
      children: provider.activeTrips.take(5).map((trip) {
        return ListTile(
          leading: CircleAvatar(
            child: Text(trip.studentRoll.substring(trip.studentRoll.length - 2)),),
          title: Text(trip.studentName),
          subtitle: Text(dateFormat.format(trip.hostelExitTime ?? DateTime.now())),
          trailing: _buildStatusIndicator(trip.status),
          onTap: () => _showTripDetails(context, trip),
        );
      }).toList(),
    ),
  );
}


Widget _buildQuickActions(BuildContext context, GuardProvider provider) {
  final guardType = Provider.of<GuardTypeProvider>(context);
  
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ActionChip(
        avatar: const Icon(Icons.qr_code_scanner, size: 18),
        label: Text(guardType.isHostelGuard 
            ? 'Scan Hostel QR' 
            : 'Scan Main Gate QR'),
        onPressed: () => Navigator.pushNamed(context, '/guard-qr-scanner'),
      ),
      if (guardType.isHostelGuard) // Only show for hostel guards
        ActionChip(
          avatar: const Icon(Icons.list_alt, size: 18),
          label: const Text('Pending Requests'),
          onPressed: () => Navigator.pushNamed(context, '/guard-pending-requests'),
        ),
      if (provider.overdueTrips.isNotEmpty)
        ActionChip(
          avatar: const Icon(Icons.warning, size: 18),
          label: Text(guardType.isHostelGuard
              ? 'Overdue Students'
              : 'Overdue Verification'),
          onPressed: () => Navigator.pushNamed(context, '/guard-active-trips'),
        ),
    ],
  );
}

  Widget _buildStatusIndicator(String status) {
    final color = status == 'completed'
        ? Colors.green
        : status == 'overdue'
            ? Colors.red
            : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showTripDetails(BuildContext context, Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                )),
            ),
            const SizedBox(height: 16),
            Text(
              'Trip Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _DetailRow(label: 'Student', value: trip.studentName),
            _DetailRow(label: 'Roll No', value: trip.studentRoll),
            _DetailRow(label: 'Hostel', value: trip.hostelName),
            _DetailRow(
              label: 'Status',
              value: trip.status,
              valueColor: _getStatusColor(trip.status),
            ),
            if (trip.hostelExitTime != null)
              _DetailRow(
                label: 'Exit Time',
                value: DateFormat('MMM dd, yyyy - hh:mm a').format(trip.hostelExitTime!),
              ),
            if (trip.hostelEntryTime != null)
              _DetailRow(
                label: 'Return Time',
                value: DateFormat('MMM dd, yyyy - hh:mm a').format(trip.hostelEntryTime!),
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
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
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
            width: 100,
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