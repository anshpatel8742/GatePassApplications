
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode


// Providers
import 'providers/auth_provider.dart';
import 'providers/student_provider.dart';
import 'providers/guard_provider.dart';
import 'providers/guard_type_provider.dart';
import 'providers/warden_provider.dart';
import 'providers/trip_provider.dart';

// Auth Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';

// Student Screens
import 'screens/student/student_dashboard.dart';
import 'screens/student/student_request_leave_tab.dart';
import 'screens/student/emergency_contact_screen.dart';
import 'screens/student/notifications_screen.dart';
import 'screens/student/timetable_screen.dart';

// Warden Screens
import 'screens/warden/warden_dashboard.dart';
import 'screens/warden/warden_approval_tab.dart';
import 'screens/warden/warden_overdue_tab.dart';

// Guard Screens
import 'screens/guard/guard_dashboard.dart';
import 'screens/guard/guard_pending_requests_tab.dart';
import 'screens/guard/guard_active_trips_tab.dart';
import 'screens/guard/qr_scanner_screen.dart';
import 'screens/guard/guard_dashboard.dart';

import 'models/enums.dart';


Future<String?> _getHostelForGuard(String uid) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('guards')
        .doc(uid)
        .get();
    return doc['assignedHostel'];
  } catch (e) {
    debugPrint('Error getting hostel for guard: $e');
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
  }

  runApp(const MyApp());
}

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth Routes
      case '/':
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case '/forgot-password':
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

      // Student Routes
      case '/student-dashboard':
        return MaterialPageRoute(builder: (_) => const StudentDashboardScreen());
       case '/create-leave-request':
      return MaterialPageRoute(builder: (_) => const StudentRequestLeaveTab());
      case '/emergency-contact':
        return MaterialPageRoute(builder: (_) => const EmergencyContactScreen());
      case '/notifications':
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case '/timetable':
        return MaterialPageRoute(builder: (_) => const TimetableScreen());

      // Warden Routes
      case '/warden-dashboard':
        return MaterialPageRoute(builder: (_) =>  WardenDashboard());
      case '/warden-approval':
        return MaterialPageRoute(builder: (_) => const WardenApprovalTab());
      case '/warden-overdue':
        return MaterialPageRoute(builder: (_) => const WardenOverdueTab());

      // Guard Routes
      case '/guard-dashboard':
        return MaterialPageRoute(builder: (_) => const GuardDashboard());

//       case '/qr-scanner':
//        return MaterialPageRoute(builder: (_) => GuardScanScreen(
//   expectedEventType: GateEventType.hostel_exit, // or main_exit based on your logic
//   scannerTitle: 'QR Scanner', // or get from GuardTypeProvider
// ));
     
            
      case '/guard-pending-requests':
        return MaterialPageRoute(builder: (_) => const GuardPendingRequestsTab());
     
     
      case '/guard-active-trips':
        return MaterialPageRoute(builder: (_) => const GuardActiveTripsTab());

      // Default error route
      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Page not found!'),
        ),
      );
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
   ChangeNotifierProxyProvider<AuthProvider, GuardProvider>(
  create: (_) => GuardProvider(
    role: UserRole.hostelGuard,
    guardId: 'temp_id',
    firestore: FirebaseFirestore.instance,
  ),
  update: (_, auth, guardProvider) {
    if (auth.user != null && auth.userRole != null) {
      // First update with basic info
      guardProvider!.updateGuardData(
        role: UserRole.values.firstWhere(
          (e) => e.value == auth.userRole!,
          orElse: () => UserRole.hostelGuard,
        ),
        guardId: auth.user!.uid,
        hostelName: null, // Temporary null value
      );
      
      // Then load hostel info if needed
      if (auth.userRole == 'guard') {
        _getHostelForGuard(auth.user!.uid).then((hostelName) {
          // Only update if widget is still mounted
          if (guardProvider.guardId == auth.user!.uid) {
            guardProvider.updateGuardData(
              role: guardProvider.role,
              guardId: guardProvider.guardId,
              hostelName: hostelName,
            );
          }
        }).catchError((e) {
          debugPrint('Failed to load hostel: $e');
        });
      }
    }
    return guardProvider!;
  },
),
        ChangeNotifierProvider(create: (_) => WardenProvider()),
        ChangeNotifierProvider(create: (_) => GuardTypeProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: MaterialApp(
        title: 'Gate Pass',
        debugShowCheckedModeBanner: false,
        theme: _buildAppTheme(),
        initialRoute: '/',
        onGenerateRoute: RouteGenerator.generateRoute,
        navigatorObservers: [_AuthRouteObserver()],
      ),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}


class _AuthRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    _checkAuth(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _checkAuth(previousRoute);
  }
void _checkAuth(Route? route) {
    final context = route?.navigator?.context;
    if (context != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isAuthenticated && _isProtectedRoute(route)) {
        // Use Future.microtask instead of checking mounted
        Future.microtask(() {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        });
      }
    }
  }
  bool _isProtectedRoute(Route? route) {
    final protectedRoutes = [
      '/student-dashboard',
      '/create-leave-request',
      '/emergency-contact',
      '/notifications',
      '/timetable',
      '/warden-dashboard',
      '/warden-approval',
      '/warden-overdue',
      '/guard-dashboard',
      '/qr-scanner',
      '/guard-pending-requests',
      '/guard-active-trips',
    ];
    return protectedRoutes.contains(route?.settings.name);
  }
}