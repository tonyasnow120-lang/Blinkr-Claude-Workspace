import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'ink_grain.dart';
import 'ink_splat.dart';

/// The standard Ink-Punk screen shell. Stacks, in order:
///   1. the screen background colour,
///   2. a seeded [InkSplat] behind all content,
///   3. the screen [body],
///   4. a faint [InkGrain] overlay on top.
///
/// The body is clipped (`overflow:hidden`) and isolated so the splatter and
/// grain composite only within this screen. Every screen passes a unique
/// [splatSeed].
class InkScaffold extends StatelessWidget {
  final int splatSeed;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final double splatIntensity;
  final bool grain;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  const InkScaffold({
    super.key,
    required this.splatSeed,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.splatIntensity = 0.5,
    this.grain = true,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: backgroundColor ?? colors.background,
      appBar: appBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: InkSplat(seed: splatSeed, intensity: splatIntensity),
            ),
            body,
            if (grain) const Positioned.fill(child: InkGrain()),
          ],
        ),
      ),
    );
  }
}
