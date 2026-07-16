import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Synchronously fetch Google Maps API Key from the backend config on startup
    if let url = URL(string: "https://turf.infoleena.com/api/config") {
        let semaphore = DispatchSemaphore(value: 0)
        var apiKey: String? = nil
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let key = json["google_maps_api_key"] as? String {
                    apiKey = key
                }
            } catch {
                print("Failed to parse config JSON: \(error)")
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 3.0) // 3 seconds timeout max
        
        if let key = apiKey, !key.isEmpty {
            GMSServices.provideAPIKey(key)
            print("Google Maps API Key dynamically loaded and initialized: \(key)")
        } else {
            print("Google Maps API Key not found in config or request timed out.")
        }
    }

    let registrar = self.registrar(forPlugin: "GoogleMapsDynamicInit")
    let mapsChannel = FlutterMethodChannel(name: "com.turfbooking.app/google_maps",
                                           binaryMessenger: registrar!.messenger())
    mapsChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "initialize" {
        if let args = call.arguments as? [String: Any],
           let apiKey = args["apiKey"] as? String {
            GMSServices.provideAPIKey(apiKey)
            result(true)
        } else {
            result(false)
        }
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
