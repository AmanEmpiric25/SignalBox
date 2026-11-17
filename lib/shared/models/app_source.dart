/// An application that has produced at least one notification.
class AppSource {
  const AppSource({
    required this.id,
    required this.packageName,
    required this.appLabel,
    required this.isMuted,
    required this.firstSeenAt,
  });

  final int id;
  final String packageName;
  final String appLabel;
  final bool isMuted;
  final DateTime firstSeenAt;

  factory AppSource.fromMap(Map<String, Object?> map) => AppSource(
    id: map['id'] as int,
    packageName: map['package_name'] as String,
    appLabel: map['app_label'] as String,
    isMuted: (map['is_muted'] as int? ?? 0) == 1,
    firstSeenAt: DateTime.fromMillisecondsSinceEpoch(
      map['first_seen_at'] as int,
    ),
  );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'package_name': packageName,
    'app_label': appLabel,
    'is_muted': isMuted ? 1 : 0,
    'first_seen_at': firstSeenAt.millisecondsSinceEpoch,
  };

  AppSource copyWith({String? appLabel, bool? isMuted}) => AppSource(
    id: id,
    packageName: packageName,
    appLabel: appLabel ?? this.appLabel,
    isMuted: isMuted ?? this.isMuted,
    firstSeenAt: firstSeenAt,
  );
}
