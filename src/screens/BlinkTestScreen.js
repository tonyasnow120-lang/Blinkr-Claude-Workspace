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
        <Text style={styles.errorText}>Camera permission required</Text>
      </View>
    );
  }

  if (!device) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>No front camera found</Text>
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
          <Text style={styles.headerTitle}>Blinkr — Detection Test</Text>
          <Text style={styles.detectorBadge}>{detectorName}</Text>
        </View>

        {/* Stats panel */}
        <View style={styles.statsPanel}>
          <EyeBar label="L EYE" score={leftEye} />
          <EyeBar label="R EYE" score={rightEye} />

          <View style={styles.divider} />

          <View style={styles.metaRow}>
            <Text style={styles.metaLabel}>Blinks</Text>
            <Text style={styles.metaValue}>{blinkCount}</Text>
          </View>
          <View style={styles.metaRow}>
            <Text style={styles.metaLabel}>Latency</Text>
            <Text style={styles.metaValue}>{latencyMs} ms</Text>
          </View>

          {blinkVisible && (
            <View style={styles.blinkBanner}>
              <Text style={styles.blinkBannerText}>BLINK DETECTED</Text>
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
    backgroundColor: '#000',
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#000',
  },
  errorText: {
    color: '#ff4444',
    fontSize: 16,
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
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  detectorBadge: {
    color: '#00e5ff',
    fontSize: 13,
    fontWeight: '600',
    backgroundColor: 'rgba(0,229,255,0.15)',
    paddingHorizontal: 10,
    paddingVertical: 3,
    borderRadius: 8,
    overflow: 'hidden',
  },
  statsPanel: {
    backgroundColor: 'rgba(0,0,0,0.65)',
    borderRadius: 16,
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
    color: '#aaa',
    fontSize: 12,
    fontWeight: '700',
    width: 44,
    letterSpacing: 0.5,
  },
  scoreTrack: {
    flex: 1,
    height: 10,
    backgroundColor: 'rgba(255,255,255,0.15)',
    borderRadius: 5,
    overflow: 'hidden',
    marginHorizontal: 10,
  },
  scoreFill: {
    height: '100%',
    backgroundColor: '#00e5ff',
    borderRadius: 5,
  },
  scoreFillAlert: {
    backgroundColor: '#ff4444',
  },
  eyeScore: {
    color: '#fff',
    fontSize: 14,
    fontVariant: ['tabular-nums'],
    width: 36,
    textAlign: 'right',
  },
  divider: {
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.12)',
    marginVertical: 10,
  },
  metaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 6,
  },
  metaLabel: {
    color: '#888',
    fontSize: 13,
  },
  metaValue: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '600',
    fontVariant: ['tabular-nums'],
  },
  blinkOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#fff',
  },
  blinkBanner: {
    marginTop: 12,
    alignItems: 'center',
    backgroundColor: 'rgba(255,68,68,0.9)',
    borderRadius: 10,
    paddingVertical: 8,
  },
  blinkBannerText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '900',
    letterSpacing: 2,
  },
});
