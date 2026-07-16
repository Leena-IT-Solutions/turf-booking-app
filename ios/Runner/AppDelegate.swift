import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyBwYyZdXko52rrcTzFptPFRNMySD5_yGQQ")

    let registrar = self.registrar(forPlugin: "GoogleMapsDynamicInit")
    let mapsChannel = FlutterMethodChannel(name: "com.turfbooking.app/google_maps",
                                           binaryMessenger: registrar!.messenger())
    mapsChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "initialize" {
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
