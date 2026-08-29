package com.thewalkingpet.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Reels Native Ad Factory
        val reelsFactory = ReelsNativeAdFactory(layoutInflater)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "reelsNativeAd", reelsFactory)

        // Register Social Feed Native Ad Factory
        val socialFeedFactory = SocialFeedNativeAdFactory(layoutInflater)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "socialFeedNativeAd", socialFeedFactory)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)

        // Unregister Native Ad Factories
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "reelsNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "socialFeedNativeAd")
    }
}
