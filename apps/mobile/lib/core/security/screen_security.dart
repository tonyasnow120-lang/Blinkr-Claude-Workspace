import 'dart:io';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// Manages Android FLAG_SECURE on sensitive screens (GAP-15).
/// Blocks screenshots and screen recording on contest and result screens.
/// No-op on iOS — iOS screenshot prevention is handled at the OS level for system apps.
class ScreenSecurity {
  static Future<void> enableSecureMode() async {
    if (!Platform.isAndroid) return;
    await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }

  static Future<void> disableSecureMode() async {
    if (!Platform.isAndroid) return;
    await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
  }
}
