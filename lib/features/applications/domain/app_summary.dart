/// Aggregated notification activity for one application.
class AppSummary {
  const AppSummary({
    required this.packageName,
    required this.appLabel,
    required this.total,
    required this.unread,
    required this.lastPostedAt,
    required this.isMuted,
    required this.matchingRules,
  });

  final String packageName;
  final String appLabel;
  final int total;
  final int unread;
  final DateTime? lastPostedAt;
  final bool isMuted;

  /// How many enabled rules target this package.
  final int matchingRules;

  bool get hasUnread => unread > 0;
}
