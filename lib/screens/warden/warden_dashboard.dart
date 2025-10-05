import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/warden_provider.dart';
import 'warden_home_tab.dart';
import 'warden_approval_tab.dart';
import 'warden_overdue_tab.dart';


class WardenDashboard extends StatefulWidget {
    const WardenDashboard({Key? key}) : super(key: key);

  @override
  State<WardenDashboard> createState() => _WardenDashboardState();
}

class _WardenDashboardState extends State<WardenDashboard> {
  int _selectedIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const WardenHomeTab(),
      const WardenApprovalTab(),
      const WardenOverdueTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<WardenProvider>(context);
    final warden = provider.currentWarden;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Warden Dashboard'),
            if (warden != null)
              Text(
                warden.managedHostels.join(', '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.8),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              provider.fetchPendingHomeRequests();
              provider.fetchOverdueRequests();
              provider.fetchRecentApprovals();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.approval_outlined),
            selectedIcon: Icon(Icons.approval),
            label: 'Approvals',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Overdue',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 2 && provider.overdueRequests.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.notifications_active),
              label: const Text('Notify All'),
              onPressed: () => _notifyAllOverdue(context, provider),
            )
          : null,
    );
  }

  Future<void> _notifyAllOverdue(BuildContext context, WardenProvider provider) async {
    final overdue = provider.overdueRequests;
    if (overdue.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notify All Overdue Students'),
        content: Text(
          'Send notifications to all ${overdue.length} overdue students?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Notify All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifying ${overdue.length} students...'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      for (final request in overdue) {
        await provider.notifyOverdueStudent(request.id);
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Implement logout logic
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}