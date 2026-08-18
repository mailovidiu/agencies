import Flutter
import UIKit
import GoogleMobileAds
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDV8vQ78L4OJFgaoylf6GHNpXBHjfllJBQ")
    GeneratedPluginRegistrant.register(with: self)

    // Initialize Google Mobile Ads SDK
    MobileAds.shared.start(completionHandler: nil)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
