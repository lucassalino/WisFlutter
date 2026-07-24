import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/set_new_password_screen.dart';
import '../../features/onboarding/presentation/create_org_screen.dart';
import '../../features/onboarding/presentation/join_org_screen.dart';
import '../../features/onboarding/presentation/org_selection_screen.dart';
import '../../features/shell/presentation/app_shell_screen.dart';
import '../../shared/state/org_store.dart';
import '../supabase/supabase_providers.dart';

const _authRoutes = {
  '/login',
  '/register',
  '/forgot-password',
  '/set-password',
};
const _onboardingRoutes = {'/org-selection', '/new-org', '/join-org'};

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(authStateChangesProvider, (_, _) => refreshNotifier.notify());
  ref.listen(orgStoreProvider, (_, _) => refreshNotifier.notify());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/set-password',
        builder: (context, state) => const SetNewPasswordScreen(),
      ),
      GoRoute(
        path: '/org-selection',
        builder: (context, state) => const OrgSelectionScreen(),
      ),
      GoRoute(
        path: '/new-org',
        builder: (context, state) => const CreateOrgScreen(),
      ),
      GoRoute(
        path: '/join-org',
        builder: (context, state) => const JoinOrgScreen(),
      ),
      GoRoute(
        path: '/:orgId/dashboard',
        builder: (context, state) =>
            AppShellScreen(orgId: state.pathParameters['orgId']!),
      ),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final location = state.matchedLocation;
  final session = ref.read(supabaseClientProvider).auth.currentSession;

  if (session == null) {
    return _authRoutes.contains(location) ? null : '/login';
  }

  if (_authRoutes.contains(location) || location == '/splash') {
    final activeOrg = ref.read(orgStoreProvider);
    return activeOrg == null
        ? '/org-selection'
        : '/${activeOrg.organization.id}/dashboard';
  }

  final activeOrg = ref.read(orgStoreProvider);
  if (activeOrg == null) {
    return _onboardingRoutes.contains(location) ? null : '/org-selection';
  }

  if (_onboardingRoutes.contains(location)) {
    return '/${activeOrg.organization.id}/dashboard';
  }

  return null;
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
