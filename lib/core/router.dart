import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/household_management_screen.dart';
import '../screens/dashboard/notification_center_screen.dart';
import '../screens/dashboard/register_device_screen.dart';
import '../screens/dashboard/night_light_control_screen.dart';
import '../screens/dashboard/gate_security_screen.dart';
import '../screens/dashboard/anti_theft_room_screen.dart';
import '../services/auth_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final loggedIn = await authService.isLoggedIn();
      final onAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation.startsWith('/verify-otp');

      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (_, state) =>
            VerifyOtpScreen(email: state.extra as String),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/register-device',
        builder: (_, __) => const RegisterDeviceScreen(),
      ),
      GoRoute(
        path: '/household-management',
        builder: (_, __) => const HouseholdManagementScreen(),
      ),
      GoRoute(
        path: '/device-control/:id',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return NightLightControlScreen(deviceId: id);
        },
      ),
      GoRoute(
        path: '/gate-security/:id',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return GateSecurityScreen(deviceId: id);
        },
      ),
      GoRoute(
        path: '/anti-theft/:id',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AntiTheftRoomScreen(deviceId: id);
        },
      ),
    ],
  );
});
