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
      // Only obscure when truly backgrounded — not on `inactive` (system overlay, phone call)
      // or `hidden` (Android 12+ launch animation transition) to avoid false black-screen on startup.
      case AppLifecycleState.paused:
        if (!_obscured) setState(() => _obscured = true);
        break;
      case AppLifecycleState.resumed:
        if (_obscured) setState(() => _obscured = false);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
