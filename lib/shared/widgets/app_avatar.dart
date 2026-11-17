import 'package:flutter/material.dart';

/// Monogram avatar for an application.
///
/// SignalBox does not read application icons from the package manager yet, so
/// the first letter of the label is shown on a colour derived from the package
/// name. This keeps the colour stable across restarts.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.packageName,
    required this.label,
    this.size = 40,
    super.key,
  });

  final String packageName;
  final String label;
  final double size;

  static const List<Color> _palette = [
    Color(0xFF3E63DD),
    Color(0xFF2E9E5B),
    Color(0xFFE5A32A),
    Color(0xFF8E4EC6),
    Color(0xFFE5484D),
    Color(0xFF0D9488),
    Color(0xFFD6409F),
  ];

  Color get _color {
    if (packageName.isEmpty) return _palette.first;
    final hash = packageName.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? '?' : label.trim()[0].toUpperCase();
    return Semantics(
      label: '$label icon',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: _color,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}
