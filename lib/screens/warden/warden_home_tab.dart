import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/warden_provider.dart';
import 'warden_approval_tab.dart';
import '../../models/leave_request.dart';  // Add this import

class WardenHomeTab extends StatefulWidget {
  const WardenHomeTab({Key? key}) : super(key: key);

  @override
  State<WardenHomeTab> createState() => _WardenHomeTabState();
}

class _WardenHomeTabState extends State<WardenHomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WardenProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<WardenProvider>(context);
    final warden = provider.currentWarden;

    return Scaffold(
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator.adaptive(
              onRefresh: () async {
                await provider.fetchPendingHomeRequests();
                await provider.fetchOverdueRequests();
                await provider.fetchRecentApprovals();
              },
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 180,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.secondaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Warden Dashboard',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (warden != null)
                                Text(
                                  warden.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildStatsGrid(provider, theme),
                          const SizedBox(height: 24),
                          _buildQuickActions(context, theme),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  if (provider.pendingHomeRequests.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Pending Approvals',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (provider.pendingHomeRequests.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final request = provider.pendingHomeRequests[index];
                          return _buildLeaveRequestCard(
                            context,
                            request,
                            provider,
                          ).animate().fadeIn(delay: (100 * index).ms);
                        },
                        childCount: provider.pendingHomeRequests.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid(WardenProvider provider, ThemeData theme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _StatCard(
          icon: Icons.pending_actions,
          value: provider.pendingHomeRequests.length,
          label: 'Pending Approvals',
          color: theme.colorScheme.primary,
        ),
        _StatCard(
          icon: Icons.timer_outlined,
          value: provider.overdueRequests.length,
          label: 'Overdue Students',
          color: theme.colorScheme.error,
        ),
        _StatCard(
          icon: Icons.check_circle_outline,
          value: provider.recentApprovals.length,
          label: 'Recent Approvals',
          color: theme.colorScheme.secondary,
        ),
        _StatCard(
          icon: Icons.home_work_outlined,
          value: provider.currentWarden?.managedHostels.length ?? 0,
          label: 'Managed Hostels',
          color: theme.colorScheme.tertiary,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ActionCard(
                icon: Icons.approval,
                label: 'Approve All Verified',
                color: theme.colorScheme.primaryContainer,
                onTap: () => _approveAllVerified(context),
              ),
              const SizedBox(width: 12),
              _ActionCard(
                icon: Icons.notifications_active,
                label: 'Notify Overdue',
                color: theme.colorScheme.errorContainer,
                onTap: () => _notifyAllOverdue(context),
              ),
              const SizedBox(width: 12),
              _ActionCard(
                icon: Icons.import_export,
                label: 'Export Data',
                color: theme.colorScheme.secondaryContainer,
                onTap: () => _exportData(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveRequestCard(
    BuildContext context,
    LeaveRequest request,
    WardenProvider provider,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, hh:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: const WardenApprovalTab(),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    request.studentRoll.substring(0, 2),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
                    Text(
                      request.reason,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(request.exitTimePlanned)} → '
                      '${dateFormat.format(request.returnTimePlanned ?? request.exitTimePlanned.add(const Duration(hours: 24)))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveAllVerified(BuildContext context) async {
    final provider = Provider.of<WardenProvider>(context, listen: false);
    // Implement logic to approve all verified requests
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Approving all verified requests...')),
    );
  }

  Future<void> _notifyAllOverdue(BuildContext context) async {
    final provider = Provider.of<WardenProvider>(context, listen: false);
    for (final request in provider.overdueRequests) {
      await provider.notifyOverdueStudent(request.id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notified ${provider.overdueRequests.length} students')),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final provider = Provider.of<WardenProvider>(context, listen: false);
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (result != null) {
      final csvData = await provider.exportLeaveData(
        startDate: result.start,
        endDate: result.end,
      );
      // Implement export functionality (share/save)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data exported successfully')),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
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
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                '$value',
                key: ValueKey(value),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}