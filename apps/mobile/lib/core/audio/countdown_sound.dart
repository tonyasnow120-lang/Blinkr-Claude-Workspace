import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Plays short synthesized beep tones for the pre-match countdown — a low
/// tick for each of "3, 2, 1" and a higher tone for "GO". Tones are
/// generated on the fly as PCM WAV data, so no audio assets are needed.
class CountdownSoundPlayer {
  static const _sampleRate = 44100;

  final AudioPlayer _player = AudioPlayer();

  CountdownSoundPlayer() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> playTick() => _play(660, 120);

  Future<void> playGo() => _play(1320, 240);

  Future<void> _play(double frequency, int durationMs) async {
    try {
      await _player.stop();
      await _player.play(BytesSource(_tone(frequency, durationMs)), volume: 0.6);
    } catch (e) {
      // Decorative — never let an audio failure affect the countdown.
    }
  }

  Uint8List _tone(double frequency, int durationMs) {
    final numSamples = (_sampleRate * durationMs / 1000).round();
    final samples = Int16List(numSamples);
    const fadeSamples = 200;
    for (var i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final fade =
          math.min(1.0, math.min(i / fadeSamples, (numSamples - i) / fadeSamples));
      final value = math.sin(2 * math.pi * frequency * t) * fade;
      samples[i] = (value * 32767 * 0.8).round();
    }
    return _wavBytes(samples);
  }

  Uint8List _wavBytes(Int16List samples) {
    final pcmBytes = samples.buffer.asUint8List();
    final builder = BytesBuilder();

    void writeString(String s) => builder.add(s.codeUnits);
    void writeUint32(int v) => builder.add([
          v & 0xFF,
          (v >> 8) & 0xFF,
          (v >> 16) & 0xFF,
          (v >> 24) & 0xFF,
        ]);
    void writeUint16(int v) => builder.add([v & 0xFF, (v >> 8) & 0xFF]);

    writeString('RIFF');
    writeUint32(36 + pcmBytes.length);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1); // PCM
    writeUint16(1); // mono
    writeUint32(_sampleRate);
    writeUint32(_sampleRate * 2); // byte rate (sampleRate * blockAlign)
    writeUint16(2); // block align (channels * bitsPerSample / 8)
    writeUint16(16); // bits per sample
    writeString('data');
    writeUint32(pcmBytes.length);
    builder.add(pcmBytes);

    return builder.toBytes();
  }

  void dispose() => _player.dispose();
}
