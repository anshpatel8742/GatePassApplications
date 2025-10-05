import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/student_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/leave_request.dart';
import '../../models/student.dart';
import '../../models/enums.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({Key? key}) : super(key: key);

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Update time every second
    _updateTime();
    _verifyInitialData();
  }

  Future<void> _verifyInitialData() async {
  final studentProvider = context.read<StudentProvider>();
  if (studentProvider.student == null) {
    await studentProvider.initialize(context.read<AuthProvider>().user!.uid);
  }
}

  void _updateTime() {
    if (mounted) {
      setState(() => _currentTime = DateTime.now());
      Future.delayed(const Duration(seconds: 1), _updateTime);
    }
  }


  Future<void> _handleRefresh() async {
  try {
    await context.read<StudentProvider>()
      .initialize(context.read<AuthProvider>().user!.uid);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: ${e.toString()}')),
      );
    }
  }
}

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final theme = Theme.of(context);

    if (studentProvider.isLoading && studentProvider.student == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
     if (studentProvider.error != null) {
    return _buildErrorState(
      studentProvider.error!,
     onRetry: () => studentProvider.initialize(
          context.read<AuthProvider>().user!.uid
     ),
    );
  }

    if (studentProvider.student == null) {
      return _buildErrorState(
        'Failed to load student data',
        onRetry: () => studentProvider.initialize(
          context.read<AuthProvider>().user!.uid
        ),
      );
    }

   return RefreshIndicator(
    onRefresh: () async {
      try {
        await studentProvider.initialize(context.read<AuthProvider>().user!.uid);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: ${e.toString()}')),
        );
      }
    },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (studentProvider.error != null)
                  _buildErrorCard(studentProvider.error!, theme),
                
                _buildWelcomeCard(theme, studentProvider.student!),
                
                const SizedBox(height: 20),
                _buildActivePassesSection(studentProvider),
                const SizedBox(height: 20),
                _buildQuickActions(context),
                const SizedBox(height: 20),
                _buildHostelInfoSection(studentProvider),
                const SizedBox(height: 20), // Bottom padding
              ]),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildErrorState(String error, {VoidCallback? onRetry}) {
  return Center(
    child: Column(  // This is the required child parameter
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        if (onRetry != null)
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),  // This is the required child parameter
          ),
      ],
    ),
  );
}



  Widget _buildErrorCard(String error, ThemeData theme) {
    return Card(
      color: theme.colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.read<StudentProvider>().clearError(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme, Student student) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              student.name.split(' ').first,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d').format(_currentTime),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Academic Year: ${student.year}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('h:mm a').format(_currentTime),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePassesSection(StudentProvider studentProvider) {
    if (studentProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeRequests = studentProvider.leaveRequests
        .where((req) => req.status == LeaveStatus.approved)
        .toList();

    if (activeRequests.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Passes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No active passes currently'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Passes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: activeRequests.map((request) => ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: request.type == LeaveType.day 
                        ? Colors.blue.shade50 
                        : Colors.purple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    request.type == LeaveType.day ? Icons.sunny : Icons.home,
                    color: request.type == LeaveType.day 
                        ? Colors.blue.shade700 
                        : Colors.purple.shade700,
                  ),
                ),
                title: Text(
                  request.type == LeaveType.day ? 'Day Pass' : 'Home Pass',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Until ${DateFormat('MMM d, h:mm a').format(request.returnTimePlanned ?? request.exitTimePlanned.add(const Duration(hours: 12)))}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.qr_code),
                  onPressed: () => _showQrDialog(context, request),
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionButton(
              context,
              icon: Icons.schedule,
              label: 'Timetable',
              color: Colors.blue,
              onPressed: () => _navigateTo(context, '/timetable'),
            ),
            _buildActionButton(
              context,
              icon: Icons.add_circle_outline,
              label: 'New Request',
              color: Colors.green,
              onPressed: () => _navigateTo(context, '/request-leave'),
            ),
            _buildActionButton(
              context,
              icon: Icons.history,
              label: 'Leave History',
              color: Colors.orange,
              onPressed: () => _navigateTo(context, '/leave-history'),
            ),
            _buildActionButton(
              context,
              icon: Icons.help_outline,
              label: 'Help',
              color: Colors.purple,
              onPressed: () => _navigateTo(context, '/help'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostelInfoSection(StudentProvider studentProvider) {
    final student = studentProvider.student;
    final warden = studentProvider.warden;
    final guard = studentProvider.guard;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hostel Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Hostel', student?.hostelName ?? 'Not assigned'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'Warden Contact', warden?.phone ?? 'Not available'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.security, 'Security Contact', guard?.phone ?? 'Not available'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showQrDialog(BuildContext context, LeaveRequest request) async {
    try {
      final qrData = await context.read<StudentProvider>()
          .generateLeaveQR(request.id);
          
      final expiry = request.returnTimePlanned ?? 
                    request.exitTimePlanned.add(const Duration(hours: 12));
      final isExpired = DateTime.now().isAfter(expiry);

      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isExpired ? 'EXPIRED PASS' : 'HOSTELGATE PASS',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isExpired ? Colors.red : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  request.type == LeaveType.day ? 'Day Pass' : 'Home Pass',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isExpired ? Colors.red.shade200 : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: qrData,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Status: ${isExpired ? 'Expired' : 'Active'}',
                        style: TextStyle(
                          color: isExpired ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Valid until: ${DateFormat('MMM dd, hh:mm a').format(expiry)}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate QR: ${e.toString()}')),
      );
    }
  }

  void _navigateTo(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }
}