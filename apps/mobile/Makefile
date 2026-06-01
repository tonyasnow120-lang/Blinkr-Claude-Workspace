# Blinkr Mobile Release Build Commands (GAP-14)
# --obfuscate strips Dart symbol names from release builds
# --split-debug-info stores the symbol map locally (do NOT commit; use for crash symbolication)

.PHONY: build-android-release build-ios-release clean-debug-info

build-android-release:
	flutter build apk --release \
	  --obfuscate \
	  --split-debug-info=build/debug-info/android \
	  --dart-define-from-file=.env.dart-define

build-ios-release:
	flutter build ipa --release \
	  --obfuscate \
	  --split-debug-info=build/debug-info/ios \
	  --dart-define-from-file=.env.dart-define

build-appbundle-release:
	flutter build appbundle --release \
	  --obfuscate \
	  --split-debug-info=build/debug-info/android \
	  --dart-define-from-file=.env.dart-define

# Remove local debug symbol maps (they are stored securely out-of-band, not in git)
clean-debug-info:
	rm -rf build/debug-info/
