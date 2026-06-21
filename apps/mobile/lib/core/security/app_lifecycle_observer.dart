import 'package:flutter/material.dart';

/// Overlays an opaque screen when the app moves to background (M12).
/// Prevents the app switcher thumbnail from capturing match camera feeds or results.
class AppLifecycleObserver extends StatefulWidget {
  final Widget child;

  const AppLifecycleObserver({super.key, required this.child});

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver>
    with WidgetsBindingObserver {
  bool _obscured = false;
  // Guard against startup lifecycle events (e.g. Android 12+ `hidden` during launch
  // animation) that fire before the app ever enters `resumed`. Without this, the
  // overlay would appear immediately on first launch and never clear.
  bool _hasEverResumed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // `inactive` fires before the OS captures the iOS app-switcher thumbnail,
      // so it must trigger the overlay (not just `paused`) to protect all screens.
      // `hidden` and `paused` cover Android. All three are gated on _hasEverResumed
      // so the startup launch animation cannot falsely trigger the overlay.
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_hasEverResumed && !_obscured) setState(() => _obscured = true);
        break;
      case AppLifecycleState.resumed:
        _hasEverResumed = true;
        if (_obscured) setState(() => _obscured = false);
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // This Stack sits at the app root, above MaterialApp, so there is no
    // Directionality ancestor yet. Stack's default alignment
    // (AlignmentDirectional.topStart) calls Directionality.of(context) to
    // resolve, which throws in debug (visible red error) but silently
    // produces a blank/black render in release (the assert is stripped) —
    // i.e. a release-only black screen on launch with no error shown.
    // Alignment.topLeft is non-directional and needs no Directionality.
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        if (_obscured)
          const ModalBarrier(
            color: Colors.black,
            dismissible: false,
          ),
      ],
    );
  }
}
