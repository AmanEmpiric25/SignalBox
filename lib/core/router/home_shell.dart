import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// Bottom navigation scaffold shared by the five top-level destinations.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const List<_Destination> _destinations = [
    _Destination(
      Routes.dashboard,
      Icons.space_dashboard_outlined,
      Icons.space_dashboard_rounded,
      'Dashboard',
    ),
    _Destination(
      Routes.inbox,
      Icons.inbox_outlined,
      Icons.inbox_rounded,
      'Inbox',
    ),
    _Destination(
      Routes.applications,
      Icons.apps_outlined,
      Icons.apps_rounded,
      'Apps',
    ),
    _Destination(
      Routes.statistics,
      Icons.insights_outlined,
      Icons.insights_rounded,
      'Stats',
    ),
    _Destination(
      Routes.settings,
      Icons.settings_outlined,
      Icons.settings_rounded,
      'Settings',
    ),
  ];

  int get _currentIndex {
    final index = _destinations.indexWhere(
      (d) => d.path == Routes.dashboard
          ? location == Routes.dashboard
          : location.startsWith(d.path),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => context.go(_destinations[index].path),
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
              tooltip: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.path, this.icon, this.selectedIcon, this.label);

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
