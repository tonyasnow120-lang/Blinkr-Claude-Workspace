import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Animated,
  Platform,
  Alert,
  SafeAreaView,
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
} from 'react-native-vision-camera';
import BlinkDetectorFactory from '../detection/BlinkDetectorFactory';

const BLINK_THRESHOLD = 0.7;

const EyeBar = ({ label, score }) => (
  <View style={styles.eyeRow}>
    <Text style={styles.eyeLabel}>{label}</Text>
    <View style={styles.scoreTrack}>
      <View
        style={[
          styles.scoreFill,
          { width: `${Math.round(score * 100)}%` },
          score >= BLINK_THRESHOLD && styles.scoreFillAlert,
        ]}
      />
    </View>
    <Text style={styles.eyeScore}>{score.toFixed(2)}</Text>
  </View>
);

const BlinkTestScreen = () => {
  const { hasPermission, requestPermission } = useCameraPermission();
  const device = useCameraDevice('front');

  const [leftEye, setLeftEye] = useState(0.0);
  const [rightEye, setRightEye] = useState(0.0);
  const [blinkCount, setBlinkCount] = useState(0);
  const [latencyMs, setLatencyMs] = useState(0);
  const [detectorName, setDetectorName] = useState('—');
  const [blinkVisible, setBlinkVisible] = useState(false);

  const blinkAnim = useRef(new Animated.Value(0)).current;
  const detectorRef = useRef(null);
  const prevTimestamp = useRef(null);
  const blinking = useRef(false);

  useEffect(() => {
    if (!hasPermission) {
      requestPermission();
    }
  }, [hasPermission, requestPermission]);

  useEffect(() => {
    // Force ARKit for this test screen (simulates iOS vs iOS match)
    const detector = BlinkDetectorFactory.create({
      localPlatform: Platform.OS,
      remotePlatform: 'ios',
    });

    detectorRef.current = detector;
    setDetectorName(detector.getName());

    detector
      .start(data => {
        const now = Date.now();
        if (prevTimestamp.current !== null) {
          setLatencyMs(now - prevTimestamp.current);
        }
        prevTimestamp.current = data.timestamp ?? now;

        setLeftEye(data.eyeBlinkLeft);
        setRightEye(data.eyeBlinkRight);

        const isBlink =
          data.eyeBlinkLeft >= BLINK_THRESHOLD ||
          data.eyeBlinkRight >= BLINK_THRESHOLD;

        if (isBlink && !blinking.current) {
          blinking.current = true;
          setBlinkCount(c => c + 1);
          flashBlink();
        } else if (!isBlink) {
          blinking.current = false;
        }
      })
      .catch(err => Alert.alert('Detector Error', err.message));

    return () => {
      detector.stop().catch(() => {});
    };
  }, []);

  const flashBlink = () => {
    setBlinkVisible(true);
    Animated.sequence([
      Animated.timing(blinkAnim, {
        toValue: 1,
        duration: 80,
        useNativeDriver: true,
      }),
      Animated.timing(blinkAnim, {
        toValue: 0,
        duration: 350,
        useNativeDriver: true,
      }),
    ]).start(() => setBlinkVisible(false));
  };

  if (!hasPermission) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>CAMERA PERMISSION REQUIRED.</Text>
      </View>
    );
  }

  if (!device) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>NO FRONT CAMERA FOUND.</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Live camera preview */}
      <Camera
        style={StyleSheet.absoluteFill}
        device={device}
        isActive={true}
      />

      {/* Blink flash overlay */}
      <Animated.View
        pointerEvents="none"
        style={[styles.blinkOverlay, { opacity: blinkAnim }]}
      />

      <SafeAreaView style={styles.safeArea}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.headerTitle}>BLINKR — DETECTION TEST</Text>
          <Text style={styles.detectorBadge}>{detectorName}</Text>
        </View>

        {/* Stats panel */}
        <View style={styles.statsPanel}>
          <EyeBar label="L EYE" score={leftEye} />
          <EyeBar label="R EYE" score={rightEye} />

          <View style={styles.divider} />

          <View style={styles.metaRow}>
            <Text style={styles.metaLabel}>BLINKS</Text>
            <Text style={styles.metaValue}>{blinkCount}</Text>
          </View>
          <View style={styles.metaRow}>
            <Text style={styles.metaLabel}>LATENCY</Text>
            <Text style={styles.metaValue}>{latencyMs} MS</Text>
          </View>

          {blinkVisible && (
            <View style={styles.blinkBanner}>
              <Text style={styles.blinkBannerText}>BLINK DETECTED.</Text>
            </View>
          )}
        </View>
      </SafeAreaView>
    </View>
  );
};

export default BlinkTestScreen;

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#080808',
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#080808',
  },
  errorText: {
    color: '#FF3B30',
    fontSize: 16,
    letterSpacing: 1,
  },
  safeArea: {
    flex: 1,
    justifyContent: 'space-between',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 8,
  },
  headerTitle: {
    color: '#F0EDE0',
    fontSize: 16,
    fontWeight: '700',
    letterSpacing: 2,
  },
  detectorBadge: {
    color: '#39FF14',
    fontSize: 13,
    fontWeight: '600',
    backgroundColor: 'rgba(57,255,20,0.15)',
    paddingHorizontal: 10,
    paddingVertical: 3,
    borderRadius: 4,
    overflow: 'hidden',
    letterSpacing: 1,
  },
  statsPanel: {
    backgroundColor: 'rgba(8,8,8,0.65)',
    borderRadius: 4,
    marginHorizontal: 16,
    marginBottom: 24,
    padding: 16,
  },
  eyeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 10,
  },
  eyeLabel: {
    color: 'rgba(240,237,224,0.54)',
    fontSize: 12,
    fontWeight: '700',
    width: 44,
    letterSpacing: 1,
  },
  scoreTrack: {
    flex: 1,
    height: 10,
    backgroundColor: 'rgba(240,237,224,0.15)',
    borderRadius: 2,
    overflow: 'hidden',
    marginHorizontal: 10,
  },
  scoreFill: {
    height: '100%',
    backgroundColor: '#39FF14',
    borderRadius: 2,
  },
  scoreFillAlert: {
    backgroundColor: '#FF3B30',
  },
  eyeScore: {
    color: '#F0EDE0',
    fontSize: 14,
    fontVariant: ['tabular-nums'],
    width: 36,
    textAlign: 'right',
  },
  divider: {
    height: 1,
    backgroundColor: 'rgba(240,237,224,0.12)',
    marginVertical: 10,
  },
  metaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 6,
  },
  metaLabel: {
    color: 'rgba(240,237,224,0.38)',
    fontSize: 13,
    letterSpacing: 1,
  },
  metaValue: {
    color: '#F0EDE0',
    fontSize: 13,
    fontWeight: '600',
    fontVariant: ['tabular-nums'],
  },
  blinkOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#F0EDE0',
  },
  blinkBanner: {
    marginTop: 12,
    alignItems: 'center',
    backgroundColor: 'rgba(255,59,48,0.9)',
    borderRadius: 4,
    paddingVertical: 8,
  },
  blinkBannerText: {
    color: '#F0EDE0',
    fontSize: 18,
    fontWeight: '900',
    letterSpacing: 2,
  },
});
