import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/verify_email_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/home/dashboard_screen.dart';
import '../../presentation/browse/browse_screen.dart';
import '../../presentation/chat/chat_list_screen.dart';
import '../../presentation/admin/admin_dashboard.dart';
import '../../presentation/home/banned_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final userState = ref.watch(currentUserModelProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggingIn = state.uri.path == '/login';
      
      // Handle Firebase Auth 
      final firebaseUser = authState.value;
      if (authState.isLoading) return null; // Wait for auth stream
      
      if (firebaseUser == null) {
        return isLoggingIn ? null : '/login';
      }

      if (!firebaseUser.emailVerified) {
        return state.uri.path == '/verify-email' ? null : '/verify-email';
      }

      // Handle App User Model
      if (userState.isLoading) return null; 
      final userModel = userState.value;
      if (userModel == null) return null; // Still loading or error
      
      if (userModel.isBanned) {
         return state.uri.path == '/banned' ? null : '/banned';
      }

      if (!userModel.isOnboarded) {
        return state.uri.path == '/onboarding' ? null : '/onboarding';
      }

      // If user is accessing root, login, or verify pages while fully authed
      if (state.uri.path == '/' || isLoggingIn || state.uri.path == '/verify-email' || state.uri.path == '/onboarding') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/banned',
        builder: (context, state) => const BannedScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => DashboardScreen(
                  onNavigate: (index) {
                     switch(index){
                       case 1: context.go('/browse'); break;
                       case 2: context.go('/messages'); break;
                       case 3: context.go('/profile'); break;
                     }
                  },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/browse',
                builder: (context, state) => const BrowseScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (context, state) => ChatListScreen(
                  preselectedConversationId: state.uri.queryParameters['conversation'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePane(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (context, state) => const AdminDashboard(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
