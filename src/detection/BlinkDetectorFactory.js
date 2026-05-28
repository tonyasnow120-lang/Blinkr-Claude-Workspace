import { Platform } from 'react-native';
import ARKitDetector from './ARKitDetector';
import MediaPipeDetector from './MediaPipeDetector';

/**
 * Returns the correct blink detector based on match context.
 *
 * Rules:
 *   iOS vs iOS   → ARKitDetector  (ARFaceAnchor blend shapes, ~60fps, no camera access needed)
 *   Any Android  → MediaPipeDetector  (EAR from face landmarks, requires frame processor)
 *
 * @param {{ localPlatform: 'ios'|'android', remotePlatform: 'ios'|'android' }} matchContext
 * @returns {ARKitDetector | MediaPipeDetector}
 */
function createDetector(matchContext) {
  const { localPlatform, remotePlatform } = matchContext;

  const bothIOS =
    Platform.OS === 'ios' &&
    localPlatform === 'ios' &&
    remotePlatform === 'ios';

  if (bothIOS) {
    return new ARKitDetector();
  }

  return new MediaPipeDetector();
}

export default { create: createDetector };
