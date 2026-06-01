import 'dart:io';
import 'package:flutter/services.dart';

/// Manages Android FLAG_SECURE on sensitive screens (GAP-15).
/// Blocks screenshots and screen recording on contest and result screens.
/// No-op on iOS — iOS does not expose FLAG_SECURE equivalent.
class ScreenSecurity {
  static const _channel = MethodChannel('com.blinkr.app/screen_security');

  static Future<void> enableSecureMode() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('setSecure', true);
  }

  static Future<void> disableSecureMode() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('setSecure', false);
  }
}
