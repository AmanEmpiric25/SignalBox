import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_access_service.dart';

final notificationAccessServiceProvider = Provider<NotificationAccessService>(
  (ref) => NotificationAccessService(),
);

/// Whether the Android notification listener is enabled for SignalBox.
///
/// Always false on platforms that cannot expose other apps' notifications.
final notificationAccessGrantedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationAccessServiceProvider);
  if (!service.isSupported) return false;
  return service.isPermissionGranted();
});
