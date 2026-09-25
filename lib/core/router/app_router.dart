import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/household_repository.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/home/screens/root_shell.dart';
import '../../features/onboarding/screens/household_setup_screen.dart';
import '../config/supabase_config.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const signup = '/signup';
  static const householdSetup = '/household-setup';
  static const home = '/';
}

/// Ponte entre o `Stream<AuthState>` do Supabase e o `refreshListenable`
/// do go_router, que exige um [Listenable] síncrono.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Roteador único do app. Auth gate + gate de onboarding de household
/// (briefing, seção 9) ficam centralizados aqui em [_redirect].
class AppRouter {
  AppRouter._();

  static final _householdRepository = HouseholdRepository(SupabaseConfig.client);

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: GoRouterRefreshStream(
      SupabaseConfig.client.auth.onAuthStateChange,
    ),
    redirect: _redirect,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.householdSetup,
        builder: (context, state) => const HouseholdSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const RootShell(),
      ),
    ],
  );

  static Future<String?> _redirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final session = SupabaseConfig.client.auth.currentSession;
    final path = state.matchedLocation;
    final isAuthRoute = path == AppRoutes.login || path == AppRoutes.signup;

    if (session == null) {
      return isAuthRoute ? null : AppRoutes.login;
    }

    if (isAuthRoute) return AppRoutes.home;

    final household = await _householdRepository.fetchCurrentHousehold();
    final isSetupRoute = path == AppRoutes.householdSetup;

    if (household == null) {
      return isSetupRoute ? null : AppRoutes.householdSetup;
    }

    if (isSetupRoute) return AppRoutes.home;

    return null;
  }
}
