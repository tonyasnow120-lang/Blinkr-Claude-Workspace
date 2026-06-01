#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

// ObjC bridge — RCT_EXTERN_MODULE must be wrapped in @interface/@end
// so the preprocessor receives the required @interface keyword prefix.
@interface RCT_EXTERN_MODULE(ARKitBlinkDetector, RCTEventEmitter)

RCT_EXTERN_METHOD(
  startDetection:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  stopDetection:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
)

@end
