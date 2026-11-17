import 'package:flutter/material.dart';

/// One bar of a [SimpleBarChart].
class BarDatum {
  const BarDatum({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final int value;
  final bool highlight;
}

/// Lightweight bar chart.
///
/// SignalBox renders its own bars instead of pulling in a charting package:
/// the shapes are simple and this keeps the dependency list short.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    required this.data,
    this.height = 160,
    this.barWidth = 14,
    super.key,
  });

  final List<BarDatum> data;
  final double height;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data for this range',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final max = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final safeMax = max == 0 ? 1 : max;

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final datum in data)
              Semantics(
                label: '${datum.label}: ${datum.value} notifications',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${datum.value}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        width: barWidth,
                        height: ((height - 54) * datum.value / safeMax).clamp(
                          3,
                          height - 54,
                        ),
                        decoration: BoxDecoration(
                          color: datum.highlight
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: barWidth + 24,
                        child: Text(
                          datum.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
