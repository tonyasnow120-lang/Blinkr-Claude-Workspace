import Foundation
import ARKit
import React

@objc(ARKitBlinkDetector)
final class ARKitBlinkDetector: RCTEventEmitter {

  private var session: ARSession?

  // MARK: - RCTEventEmitter

  override static func requiresMainQueueSetup() -> Bool { true }

  override func supportedEvents() -> [String]! {
    return ["onBlinkData"]
  }

  // Disable automatic observation check so we can run headlessly (no ARView)
  override func startObserving() {}
  override func stopObserving() {}

  // MARK: - JS-callable methods

  @objc func startDetection(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    guard ARFaceTrackingConfiguration.isSupported else {
      reject(
        "NOT_SUPPORTED",
        "ARKit face tracking requires TrueDepth camera (iPhone X or later).",
        nil
      )
      return
    }

    DispatchQueue.main.async {
      let config = ARFaceTrackingConfiguration()
      config.maximumNumberOfTrackedFaces = 1

      self.session = ARSession()
      self.session?.delegate = self
      self.session?.run(config, options: [.resetTracking, .removeExistingAnchors])
      resolve(nil)
    }
  }

  @objc func stopDetection(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    DispatchQueue.main.async {
      self.session?.pause()
      self.session = nil
      resolve(nil)
    }
  }
}

// MARK: - ARSessionDelegate

extension ARKitBlinkDetector: ARSessionDelegate {

  func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    guard let face = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor
    else { return }

    let shapes = face.blendShapes
    let blinkLeft  = shapes[.eyeBlinkLeft]?.floatValue  ?? 0.0
    let blinkRight = shapes[.eyeBlinkRight]?.floatValue ?? 0.0

    sendEvent(withName: "onBlinkData", body: [
      "eyeBlinkLeft":  blinkLeft,
      "eyeBlinkRight": blinkRight,
      "timestamp":     Date().timeIntervalSince1970 * 1_000,
    ])
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    // Surface errors to JS via an additional event if needed in the future
    NSLog("[ARKitBlinkDetector] Session error: %@", error.localizedDescription)
  }
}
