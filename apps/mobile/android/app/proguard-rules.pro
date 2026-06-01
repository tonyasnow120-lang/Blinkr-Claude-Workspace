# Blinkr ProGuard / R8 rules (GAP-14, GAP-17)
#
# DO NOT add blanket -keep rules for your own code.
# Obfuscation must apply to auth, blink detection, and challenge logic.
# Flutter's AOT compilation does not use Java class names for Dart code.

# Keep Flutter engine entry points
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep platform channel method names (used by FlutterWindowManager and any future channels)
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannel.MethodCallHandler *;
}

# Keep Firebase Messaging (required for FCM)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep LiveKit WebRTC native layer
-keep class org.webrtc.** { *; }
-keep class io.livekit.** { *; }
