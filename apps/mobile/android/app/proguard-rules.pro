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

# Flutter's embedding contains optional Play Store "deferred components" support
# (FlutterPlayStoreSplitApplication, PlayStoreDeferredComponentManager) that
# references com.google.android.play.core.*. We do NOT use deferred components,
# so that library is not bundled. Without these rules, R8 full-mode treats the
# missing references as fatal and the release build fails at minifyReleaseWithR8.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
