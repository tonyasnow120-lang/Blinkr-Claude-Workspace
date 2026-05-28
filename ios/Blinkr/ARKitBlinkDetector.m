#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

// Objective-C bridge for the Swift ARKitBlinkDetector class.
// Swift implementations are in ARKitBlinkDetector.swift.
RCT_EXTERN_MODULE(ARKitBlinkDetector, RCTEventEmitter)

RCT_EXTERN_METHOD(
  startDetection:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  stopDetection:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
)
