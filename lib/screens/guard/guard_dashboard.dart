import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guard_provider.dart';
import '../../providers/guard_type_provider.dart';
import '../../models/enums.dart';
import 'guard_home_tab.dart';
import 'guard_pending_requests_tab.dart';
import 'guard_database_tab.dart';
import 'guard_active_trips_tab.dart';
import 'qr_scanner_screen.dart';

class GuardDashboard extends StatefulWidget {
  const GuardDashboard({Key? key}) : super(key: key);

  @override
  State<GuardDashboard> createState() => _GuardDashboardState();
}

class _GuardDashboardState extends State<GuardDashboard> {
  bool _isInitializing = true;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    try {
      final guardType = context.read<GuardTypeProvider>();
      final guardProvider = context.read<GuardProvider>();
      
      await guardType.determineGuardType();
      await guardProvider.refreshData();

      if (guardType.isHostelGuard) {
        await guardProvider.refreshData(); // Refresh again if hostel guard
      }
      
      if (!guardProvider.isInitialized) {
      throw Exception("Guard data failed to load");
    }

      setState(() {
        _isInitializing = false;
      });
    } catch (error) {
      setState(() {
        _initializationError = 'Error loading dashboard: ${error.toString()}';
        _isInitializing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initialization error: ${error.toString()}'),
            duration: const Duration(seconds: 3),
          )
        );
      }
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout ?? false && mounted) {
      await auth.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _navigateToQrScanner(BuildContext context, GuardTypeProvider guardType) {
    if (guardType.isLoading || guardType.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while guard type is verified'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuardScanScreen(
          expectedEventType: guardType.isHostelGuard 
              ? GateEventType.hostel_exit 
              : GateEventType.main_exit,
          scannerTitle: guardType.scanActionLabel,
        ),
      ),
    );
  }

  void _showGuardInfo(BuildContext context) {
    final guardType = context.read<GuardTypeProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(guardType.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(guardType.icon, size: 40, color: guardType.primaryColor),
            const SizedBox(height: 16),
            Text('You are logged in as ${guardType.displayName}'),
            const SizedBox(height: 8),
            Text('Scan Type: ${guardType.scanActionLabel}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleMismatchScreen(BuildContext context, String error) {
    final guardType = context.read<GuardTypeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Error'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: guardType.primaryColor),
            const SizedBox(height: 20),
            const Text(
              'Guard Type Mismatch',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: guardType.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  List<Tab> _buildTabs(GuardTypeProvider guardType) {
    return [
      const Tab(icon: Icon(Icons.home, size: 24)), 
      if (guardType.isHostelGuard) const Tab(icon: Icon(Icons.approval, size: 24)),
      const Tab(icon: Icon(Icons.history, size: 24)),
      const Tab(icon: Icon(Icons.list, size: 24)),
    ];
  }

  List<Widget> _buildTabViews(GuardTypeProvider guardType) {
    return [
      const GuardHomeTab(),
      if (guardType.isHostelGuard) const GuardPendingRequestsTab(),
      const GuardDatabaseTab(),
      const GuardActiveTripsTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final guardType = context.watch<GuardTypeProvider>();

    // Handle initialization states
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading dashboard...'),
            ],
          ),
        ),
      );
    }

    if (_initializationError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Initialization Error')),
        body: Center(
          child: Text(_initializationError!),
        ),
      );
    }

    // Handle guard type loading and error states
    if (guardType.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Verifying guard type...'),
            ],
          ),
        ),
      );
    }

    if (guardType.error != null) {
      return _buildRoleMismatchScreen(context, guardType.error!);
    }

    return DefaultTabController(
      length: guardType.isHostelGuard ? 4 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            guardType.displayName,
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: guardType.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(guardType.icon, color: Colors.white),
              onPressed: () => _showGuardInfo(context),
              tooltip: 'Guard Info',
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              onPressed: () => _navigateToQrScanner(context, guardType),
              tooltip: 'Scan QR Code',
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () => _handleSignOut(context),
              tooltip: 'Logout',
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _buildTabs(guardType),
          ),
        ),
        body: TabBarView(
          children: _buildTabViews(guardType),
        ),
      ),
    );
  }
}