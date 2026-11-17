/// Base class for recoverable, user-presentable errors.
sealed class Failure implements Exception {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Raised when a database read or write fails.
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.cause});
}

/// Raised when the Android notification-listener permission is unavailable.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.cause});
}

/// Raised when a platform channel call fails or is unsupported.
class PlatformFailure extends Failure {
  const PlatformFailure(super.message, {super.cause});
}
