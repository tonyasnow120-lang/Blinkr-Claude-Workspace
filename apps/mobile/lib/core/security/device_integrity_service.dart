import 'dart:io';
import 'package:flutter/foundation.dart';

/// SECURITY NOTE — Jailbreak/Root Detection Limitations (GAP-29)
///
/// The heuristics in this class are a best-effort signal, not a hard gate.
/// Sophisticated attackers using Frida, Magisk DenyList, or Shadow API
/// can bypass these checks entirely.
///
/// This detection MUST be treated as one signal among several:
///   1. Client-side heuristics (this class) — easily bypassed by skilled attackers
///   2. App Attest (iOS) / Play Integrity (Android) — hardware-backed (deferred to v1.1)
///   3. Server-side anomaly detection (impossible blink timings, etc.) — future work
///
/// Do NOT use this as a hard block that prevents app use — it creates
/// accessibility issues and App Store rejection risk. Log the signal
/// server-side and use it for risk scoring, not hard gating.
class DeviceIntegrityService {
  static Future<bool> isDeviceCompromised() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) return _checkIOS();
    if (Platform.isAndroid) return _checkAndroid();
    return false;
  }

  static bool _checkIOS() {
    // Check for common jailbreak artifacts
    const jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Applications/Sileo.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
      '/usr/bin/ssh',
    ];

    for (final path in jailbreakPaths) {
      if (File(path).existsSync()) return true;
    }

    // Attempt to write outside sandbox — succeeds only on jailbroken devices
    try {
      final testFile = File('/private/jailbreak_test_${DateTime.now().millisecondsSinceEpoch}');
      testFile.writeAsStringSync('test');
      testFile.deleteSync();
      return true;
    } catch (_) {
      // Expected — sandbox is intact
    }

    return false;
  }

  static bool _checkAndroid() {
    // Check for su binary in common locations
    const suPaths = [
      '/system/bin/su',
      '/system/xbin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
    ];

    for (final path in suPaths) {
      if (File(path).existsSync()) return true;
    }

    // Check for known rooting app packages
    const rootPackages = [
      '/data/app/com.topjohnwu.magisk',
      '/data/app/eu.chainfire.supersu',
      '/data/app/com.noshufou.android.su',
    ];

    for (final path in rootPackages) {
      if (Directory(path).existsSync()) return true;
    }

    return false;
  }
}
