package com.thewalkingpet.app

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class SocialFeedNativeAdFactory(private val layoutInflater: LayoutInflater) : NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.social_feed_native_ad, null) as NativeAdView

        // App Icon
        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
        val icon = nativeAd.icon
        if (icon != null) {
            iconView.visibility = View.VISIBLE
            iconView.setImageDrawable(icon.drawable)
        } else {
            iconView.visibility = View.GONE
        }
        adView.iconView = iconView

        // Headline
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        // Body
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        if (nativeAd.body != null) {
            bodyView.visibility = View.VISIBLE
            bodyView.text = nativeAd.body
        } else {
            bodyView.visibility = View.GONE
        }
        adView.bodyView = bodyView

        // Call to Action
        val callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)
        if (nativeAd.callToAction != null) {
            callToActionView.visibility = View.VISIBLE
            callToActionView.text = nativeAd.callToAction
        } else {
            callToActionView.visibility = View.INVISIBLE
        }
        adView.callToActionView = callToActionView

        // Media
        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        adView.mediaView = mediaView

        adView.setNativeAd(nativeAd)
        return adView
    }
}
