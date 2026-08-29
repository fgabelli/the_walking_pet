import Flutter
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register Reels Native Ad Factory
    let reelsFactory = ReelsNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(self, factoryId: "reelsNativeAd", nativeAdFactory: reelsFactory)
    
    // Register Social Feed Native Ad Factory
    let socialFeedFactory = SocialFeedNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(self, factoryId: "socialFeedNativeAd", nativeAdFactory: socialFeedFactory)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
