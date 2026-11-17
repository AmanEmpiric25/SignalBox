import 'package:go_router/go_router.dart';

import '../../features/applications/presentation/app_detail_page.dart';
import '../../features/applications/presentation/applications_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/notifications/presentation/inbox_page.dart';
import '../../features/notifications/presentation/notification_detail_page.dart';
import '../../features/notifications/presentation/snoozed_page.dart';
import '../../features/rules/presentation/rules_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/statistics/presentation/statistics_page.dart';
import 'home_shell.dart';

/// Route paths, so that no screen hard-codes a string.
class Routes {
  const Routes._();

  static const String dashboard = '/';
  static const String inbox = '/inbox';
  static const String applications = '/apps';
  static const String statistics = '/statistics';
  static const String settings = '/settings';
  static const String rules = '/rules';
  static const String categories = '/categories';
  static const String snoozed = '/snoozed';

  static String notificationDetail(int id) => '/inbox/$id';

  static String appDetail(String packageName) => '/apps/$packageName';
}

final GoRouter appRouter = GoRouter(
  initialLocation: Routes.dashboard,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          HomeShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: Routes.dashboard,
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: Routes.inbox,
          builder: (context, state) => const InboxPage(),
        ),
        GoRoute(
          path: Routes.applications,
          builder: (context, state) => const ApplicationsPage(),
        ),
        GoRoute(
          path: Routes.statistics,
          builder: (context, state) => const StatisticsPage(),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/inbox/:id',
      builder: (context, state) => NotificationDetailPage(
        notificationId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
      ),
    ),
    GoRoute(
      path: '/apps/:package',
      builder: (context, state) =>
          AppDetailPage(packageName: state.pathParameters['package'] ?? ''),
    ),
    GoRoute(path: Routes.rules, builder: (context, state) => const RulesPage()),
    GoRoute(
      path: Routes.categories,
      builder: (context, state) => const CategoriesPage(),
    ),
    GoRoute(
      path: Routes.snoozed,
      builder: (context, state) => const SnoozedPage(),
    ),
  ],
);
