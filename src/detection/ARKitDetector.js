import { NativeModules, NativeEventEmitter, Platform } from 'react-native';

const { ARKitBlinkDetector } = NativeModules;

/**
 * Wraps the native ARKitBlinkDetector Swift module.
 * Uses ARFaceAnchor blend shapes for sub-frame-accurate blink detection.
 * eyeBlinkLeft / eyeBlinkRight: 0.0 = fully open, 1.0 = fully closed.
 */
class ARKitDetector {
  constructor() {
    if (Platform.OS !== 'ios') {
      throw new Error('ARKitDetector is iOS only');
    }
    if (!ARKitBlinkDetector) {
      throw new Error(
        'ARKitBlinkDetector native module not found — run pod install and rebuild.',
      );
    }
    this._emitter = new NativeEventEmitter(ARKitBlinkDetector);
    this._subscription = null;
    this._callback = null;
  }

  /**
   * @param {(data: {eyeBlinkLeft: number, eyeBlinkRight: number, timestamp: number}) => void} onData
   */
  async start(onData) {
    this._callback = onData;
    this._subscription = this._emitter.addListener('onBlinkData', data => {
      if (this._callback) {
        this._callback({
          eyeBlinkLeft: data.eyeBlinkLeft,
          eyeBlinkRight: data.eyeBlinkRight,
          timestamp: data.timestamp,
        });
      }
    });
    await ARKitBlinkDetector.startDetection();
  }

  async stop() {
    this._subscription?.remove();
    this._subscription = null;
    this._callback = null;
    await ARKitBlinkDetector.stopDetection();
  }

  getName() {
    return 'ARKit';
  }
}

export default ARKitDetector;
