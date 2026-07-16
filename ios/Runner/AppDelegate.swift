import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Synchronously fetch Google Maps API Key from the backend config on startup, with a safe static fallback
    var resolvedKey = "AIzaSyBwYyZdXko52rrcTzFptPFRNMySD5_yGQQ"
    if let url = URL(string: "https://turf.infoleena.com/api/config") {
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let key = json["google_maps_api_key"] as? String, !key.isEmpty {
                    resolvedKey = key
                }
            } catch {
                print("Failed to parse config JSON: \(error)")
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 2.0) // 2 seconds timeout max
    }
    
    GMSServices.provideAPIKey(resolvedKey)

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
