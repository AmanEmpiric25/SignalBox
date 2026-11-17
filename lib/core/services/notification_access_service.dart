import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../errors/failures.dart';

/// A notification handed over by the Android notification listener.
class IncomingNotification {
  const IncomingNotification({
    required this.packageName,
    required this.appLabel,
    required this.title,
    required this.body,
    required this.postedAt,
    required this.nativeKey,
    required this.androidImportance,
  });

  final String packageName;
  final String appLabel;
  final String title;
  final String body;
  final DateTime postedAt;
  final String? nativeKey;

  /// Raw Android importance value, used as a hint for priority mapping.
  final int androidImportance;

  factory IncomingNotification.fromMap(Map<Object?, Object?> map) {
    final postedAtMs = (map['postedAt'] as num?)?.toInt();
    return IncomingNotification(
      packageName: (map['packageName'] as String?) ?? 'unknown',
      appLabel: (map['appLabel'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      postedAt: postedAtMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(postedAtMs),
      nativeKey: map['key'] as String?,
      androidImportance: (map['importance'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Bridge to the Android `NotificationListenerService`.
///
/// Android is the only platform that can read other applications'
/// notifications. On every other platform [isSupported] is false and the
/// stream stays empty: SignalBox never pretends otherwise.
class NotificationAccessService {
  NotificationAccessService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methods = methodChannel ?? const MethodChannel(_methodChannelName),
       _events = eventChannel ?? const EventChannel(_eventChannelName);

  static const String _methodChannelName = 'com.signalbox/notification_access';
  static const String _eventChannelName = 'com.signalbox/notification_stream';

  final MethodChannel _methods;
  final EventChannel _events;

  /// Whether the host platform can expose other applications' notifications.
  bool get isSupported => Platform.isAndroid;

  /// Whether the user has granted notification-listener access.
  Future<bool> isPermissionGranted() async {
    if (!isSupported) return false;
    try {
      final granted = await _methods.invokeMethod<bool>('isPermissionGranted');
      return granted ?? false;
    } on PlatformException catch (e) {
      throw PlatformFailure(
        'Could not read the notification access state.',
        cause: e,
      );
    }
  }

  /// Opens the system screen where the listener can be enabled.
  Future<void> openPermissionSettings() async {
    if (!isSupported) {
      throw const PermissionFailure(
        'Notification access is only available on Android.',
      );
    }
    try {
      await _methods.invokeMethod<void>('openPermissionSettings');
    } on PlatformException catch (e) {
      throw PlatformFailure('Could not open notification settings.', cause: e);
    }
  }

  /// Live notifications as they are posted by other applications.
  Stream<IncomingNotification> stream() {
    if (!isSupported) return const Stream<IncomingNotification>.empty();
    return _events
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map(
          (event) =>
              IncomingNotification.fromMap(event as Map<Object?, Object?>),
        );
  }
}
