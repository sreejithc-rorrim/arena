import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/app/providers/profile_providers.dart';
import 'package:arena_ops/app/router/app_shell.dart';
import 'package:arena_ops/app/sync/cloud_binding.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/features/auth/presentation/login_screen.dart';
import 'package:arena_ops/features/bills/presentation/my_bills_screen.dart';
import 'package:arena_ops/features/bookings/presentation/bookings_screen.dart';
import 'package:arena_ops/features/floor/presentation/floor_screen.dart';
import 'package:arena_ops/features/profile/presentation/terms_screen.dart';
import 'package:arena_ops/features/more/presentation/more_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:arena_ops/features/bookings/presentation/booking_screen.dart';
import 'package:arena_ops/features/controllers/presentation/controller_board_screen.dart';
import 'package:arena_ops/features/customers/presentation/customer_profile_screen.dart';
import 'package:arena_ops/features/customers/presentation/customers_screen.dart';
import 'package:arena_ops/features/floor/presentation/station_detail_screen.dart';
import 'package:arena_ops/features/more/presentation/help_screen.dart';
import 'package:arena_ops/features/new_session/presentation/new_session_screen.dart';
import 'package:arena_ops/features/notifications/presentation/notification_settings_screen.dart';
import 'package:arena_ops/features/notifications/presentation/notifications_screen.dart';
import 'package:arena_ops/features/reports/presentation/session_log_screen.dart';
import 'package:arena_ops/features/sync/presentation/sync_screen.dart';

/// The root navigator key for full-screen dialogs and secondary pages that sit
/// above the tab shell (hiding the bottom navigation bar).
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');

/// Four bottom tabs: Floor · Bookings · Bills · More. Bills shows with
/// bill_edit or bill_record when signed in online. Customers ("Members") live
/// under More. Owner work (takings, reports, pricing, stations, games, staff)
/// is on the admin web, not here.
final goRouterProvider = Provider<GoRouter>((ref) {
  // Re-run redirect whenever the signed-in user changes (sign in / out).
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  // …and whenever the staff terms gate opens or closes.
  ref.listen(termsGateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: LoginScreen.path,
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(authControllerProvider);
      final cloud = ref.read(cloudBindingProvider) != null;
      final loc = state.matchedLocation;
      final atLogin = loc == LoginScreen.path;

      if (user == null) return atLogin ? null : LoginScreen.path;

      // Staff terms not accepted, or not known yet: nothing but the terms
      // screen (it shows the check, the failure with Retry, or the terms).
      final atTerms = loc == TermsScreen.path;
      if (ref.read(termsGateProvider) is! TermsGateOpen) {
        return atTerms ? null : TermsScreen.path;
      }
      if (atLogin || atTerms) return defaultPathFor(user);

      // Block tabs the user can't access (e.g. Bills without bill_edit).
      for (final tab in AppTab.all) {
        if (tab.path == loc && !tab.visibleFor(user, cloud: cloud)) {
          return defaultPathFor(user);
        }
      }

      // Block secondary routes the user can't access.
      if (loc.startsWith('/customers') && !user.can(Permission.members)) {
        return defaultPathFor(user);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: LoginScreen.path,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: TermsScreen.path,
        builder: (context, state) => const TermsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: FloorScreen.path,
              builder: (context, state) => const FloorScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: BookingsScreen.path,
              builder: (context, state) => const BookingsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: MoreScreen.path,
              builder: (context, state) => const MoreScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: MyBillsScreen.path,
              builder: (context, state) => const MyBillsScreen(),
            ),
          ]),
        ],
      ),
      // Full-screen secondary routes (covering the AppShell and bottom navigation):
      GoRoute(
        path: SessionLogScreen.path,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SessionLogScreen(),
      ),
      GoRoute(
        path: CustomersScreen.path,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CustomerProfileScreen(
          customerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: HelpScreen.path,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: NotificationsScreen.path,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/notifications/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/sync',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SyncScreen(),
      ),
      GoRoute(
        path: '/controllers',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ControllerBoardScreen(),
      ),
      GoRoute(
        path: '/bookings/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BookingScreen(),
      ),
      GoRoute(
        path: '/sessions/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NewSessionScreen(),
      ),
      GoRoute(
        path: '/sessions/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => StationDetailScreen(
          sessionId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});

/// Where a user lands after signing in: the Floor, owners included.
String defaultPathFor(AppUser user) => FloorScreen.path;

/// Tab metadata, kept next to the router so the shell and routes agree. Each
/// tab's branch index matches its position in the shell above.
class AppTab {
  const AppTab(
    this.label,
    this.icon,
    this.selectedIcon,
    this.path,
    this.branchIndex, {
    this.requiresAny,
    this.online = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
  final int branchIndex;

  /// Any one of these permissions opens the tab, if set.
  final List<Permission>? requiresAny;

  /// Online-only tab (Bills): hidden in local mode.
  final bool online;

  bool visibleFor(AppUser user, {bool cloud = true}) {
    if (requiresAny != null && !requiresAny!.any(user.can)) return false;
    if (online && !cloud) return false;
    return true;
  }

  static const List<AppTab> all = [
    AppTab('Floor', Icons.grid_view_outlined, Icons.grid_view_rounded,
        FloorScreen.path, 0),
    AppTab('Bookings', Icons.event_available_outlined, Icons.event_available,
        BookingsScreen.path, 1),
    AppTab('Bills', Icons.receipt_long_outlined, Icons.receipt_long,
        MyBillsScreen.path, 3,
        requiresAny: [Permission.billEdit, Permission.billRecord],
        online: true),
    AppTab('More', Icons.more_horiz, Icons.more_horiz, MoreScreen.path, 2),
  ];
}
