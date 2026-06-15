import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';

// Same code alphabet/length the router enforces on /match/:code deep links.
final _codePattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{9}$');

/// QR matchmaking, scanner side (Feature 4). Scans the displayed challenge
/// QR (a standard Blinkr deep link), shows a brief confirmation, then runs
/// the exact same join flow as a tapped link (/match/:code → auto-accept).
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Accepts both https://blinkr.app/match/CODE and blinkr://match/CODE.
  String? _extractCode(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    final isHttps = uri.scheme == 'https' && uri.host == 'blinkr.app';
    final isCustom = uri.scheme == 'blinkr';
    if (!isHttps && !isCustom) return null;

    final segments =
        isCustom ? [uri.host, ...uri.pathSegments] : uri.pathSegments;
    if (segments.length < 2 || segments[0] != 'match') return null;
    final code = segments[1].toUpperCase();
    return _codePattern.hasMatch(code) ? code : null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final code = _extractCode(barcode.rawValue ?? '');
      if (code == null) continue;
      _handled = true;
      _controller.stop();
      setState(() {});
      // Brief confirmation beat before handing off to the join flow.
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) context.pushReplacement('/match/$code');
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.foreground,
        title: const Text('Scan to join'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Camera access is required to scan a challenge code. Enable it in Settings.'
                      : 'Camera unavailable: ${error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
          // Viewfinder frame
          IgnorePointer(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _handled ? Colors.greenAccent : Colors.white54,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _handled
                    ? const Center(
                        child: Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 72),
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 48,
            child: Text(
              _handled
                  ? 'Challenge found — joining…'
                  : 'Point at your opponent\'s QR code',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
