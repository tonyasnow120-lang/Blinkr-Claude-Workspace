import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// One stat in a [StatStrip]: a mono value over a tracked Barlow label.
class StatItem {
  final String label;
  final String value;
  const StatItem({required this.label, required this.value});
}

/// Full-width surface-raised bar of evenly-spaced stats with hairline dividers.
/// Values are Share Tech Mono in acid; labels are Barlow Condensed in ink-45.
class StatStrip extends StatelessWidget {
  final List<StatItem> stats;
  final double height;

  const StatStrip({super.key, required this.stats, this.height = 48});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      children.add(Expanded(child: _cell(stats[i])));
      if (i != stats.length - 1) {
        children.add(Container(
          width: 1,
          height: height * 0.55,
          color: AppColors.chalkInk(0.12),
        ));
      }
    }

    return Container(
      height: height,
      color: AppColors.dark.surfaceRaised,
      child: Row(children: children),
    );
  }

  Widget _cell(StatItem s) => Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            s.value,
            style: AppText.mono(
              size: 20,
              weight: FontWeight.w700,
              color: AppColors.acid,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.label.toUpperCase(),
            style: AppText.label(
              size: 10,
              weight: FontWeight.w500,
              color: AppColors.chalkInk(0.45),
              letterSpacing: 1.6,
            ),
          ),
        ],
      );
}
