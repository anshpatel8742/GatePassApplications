import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import 'student_home_tab.dart';
import 'student_request_leave_tab.dart';
import 'student_current_status_tab.dart';
import 'student_history_tab.dart';
import 'student_profile_tab.dart';
import 'emergency_contact_screen.dart';
import 'notifications_screen.dart';

enum StudentLoadState {
  loading,
  loaded,
  noData,
  needsProfileCompletion,
  error
}

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;
  StudentLoadState _loadState = StudentLoadState.loading;
  final _pageController = PageController();
  final List<GlobalKey<NavigatorState>> _tabNavigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
  if (!mounted) return;
  
  setState(() => _loadState = StudentLoadState.loading);
  
  try {
    final auth = context.read<AuthProvider>();
    final studentProvider = context.read<StudentProvider>();
    
    if (auth.user == null) {
      throw Exception('User not authenticated');
    }

    debugPrint('Initializing student data for UID: ${auth.user!.uid}');
    
    // Initialize student provider
    await studentProvider.initialize(auth.user!.uid);
    
    // Additional verification
    if (studentProvider.student == null) {
      throw Exception('Student data not loaded');
    }

    debugPrint('Student loaded: ${studentProvider.student?.name}');
    
    // Check if profile needs completion
    if (!mounted) return;
    if (studentProvider.student!.profileComplete != true) {
      setState(() => _loadState = StudentLoadState.needsProfileCompletion);
      return;
    }

    if (!mounted) return;
    setState(() => _loadState = StudentLoadState.loaded);
    
  } catch (e, stack) {
    debugPrint('Dashboard init error: $e\n$stack');
    if (!mounted) return;
    
    setState(() {
      _loadState = StudentLoadState.error;
    });
    
    // Show detailed error to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Initialization failed: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  void _onTabTapped(int index) {
    if (_loadState != StudentLoadState.loaded) return;
    
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
    
    if (_tabNavigatorKeys[index].currentState?.canPop() ?? false) {
      _tabNavigatorKeys[index].currentState!.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('HostelGate Pass'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Emergency contact button
          if (studentProvider.student?.emergencyContact?.isNotEmpty ?? false)
            IconButton(
              icon: Badge(
                child: const Icon(Icons.emergency),
                backgroundColor: Colors.red.shade600,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EmergencyContactScreen(),
                ),
              ),
            ),
          
          // Notifications button
          IconButton(
            icon: Badge(
              isLabelVisible: studentProvider.unreadNotificationsCount > 0,
              label: Text(studentProvider.unreadNotificationsCount.toString()),
              child: const Icon(Icons.notifications),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
          ),
          
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(authProvider),
          ),
        ],
      ),
      body: _buildBody(studentProvider),
      bottomNavigationBar: _buildBottomNavBar(studentProvider),
    );
  }

  Widget _buildBody(StudentProvider provider) {
    switch (_loadState) {
      case StudentLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      
      case StudentLoadState.needsProfileCompletion:
        return _buildProfileCompletionView(provider);
      
      case StudentLoadState.error:
        return _buildErrorView(provider);
      
      case StudentLoadState.loaded:
        return Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildTabNavigator(0, const StudentHomeTab()),
                _buildTabNavigator(1, const StudentRequestLeaveTab()),
                _buildTabNavigator(2, const StudentCurrentStatusTab()),
                _buildTabNavigator(3, const StudentHistoryTab()),
                _buildTabNavigator(4, const StudentProfileTab()),
              ],
            ),
            
            // Global loading overlay
            if (provider.isLoading)
              const Opacity(
                opacity: 0.5,
                child: ModalBarrier(dismissible: false, color: Colors.black),
              ),
              
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      
      default:
        return const Center(child: Text('Unknown state'));
    }
  }

  Widget _buildTabNavigator(int index, Widget page) {
    return Navigator(
      key: _tabNavigatorKeys[index],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => page,
        settings: settings,
      ),
    );
  }

  Widget _buildProfileCompletionView(StudentProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, size: 64, color: Colors.blue),
          const SizedBox(height: 20),
          const Text(
            'Complete Your Profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please provide additional information to continue',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // Navigate directly to profile tab
              _onTabTapped(4);
              setState(() => _loadState = StudentLoadState.loaded);
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
              backgroundColor: Colors.blue.shade700,
            ),
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(StudentProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            provider.error ?? 'Failed to load data',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              provider.clearError();
              _initializeData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  BottomNavigationBar _buildBottomNavBar(StudentProvider provider) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue.shade700,
      unselectedItemColor: Colors.grey.shade600,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          activeIcon: Icon(Icons.add_circle),
          label: 'Request',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: 'Status',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Future<void> _showLogoutDialog(AuthProvider authProvider) async {
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

    if (shouldLogout ?? false) {
      await authProvider.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/', 
          (route) => false
        );
      }
    }
  }

  @override
  void dispose() {
    context.read<StudentProvider>().clearAllData();
    _pageController.dispose();
    super.dispose();
  }
}