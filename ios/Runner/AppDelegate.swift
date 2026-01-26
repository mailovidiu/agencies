import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register Native Ad Factories
    let listTileFactory = NativeAdFactory(xibName: "NativeAdView")
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(self, factoryId: "listTile", nativeAdFactory: listTileFactory)
    
    let smallFactory = NativeAdFactory(xibName: "SmallNativeAdView")
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(self, factoryId: "small", nativeAdFactory: smallFactory)
    
    let mediumFactory = NativeAdFactory(xibName: "MediumNativeAdView")
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(self, factoryId: "medium", nativeAdFactory: mediumFactory)

    // Initialize Google Mobile Ads SDK
      MobileAds.shared.start(completionHandler: nil)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
