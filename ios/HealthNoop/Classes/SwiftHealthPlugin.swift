import Flutter
import UIKit

/// No-op iOS side of the `health` plugin.
/// Keeps plugin registration happy without linking or using HealthKit.
/// Step tracking on iOS uses Core Motion through the pedometer plugin.
public class SwiftHealthPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_health",
      binaryMessenger: registrar.messenger()
    )
    let instance = SwiftHealthPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
  }
}
