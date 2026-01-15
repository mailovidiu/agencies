package com.trendmobileapp.usgovdepandagen

import android.content.Context
import android.view.LayoutInflater
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class SmallNativeAdFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.small_native_ad, null) as NativeAdView

        with(nativeAdView) {
            val headlineView = findViewById<TextView>(R.id.ad_headline)
            val bodyView = findViewById<TextView>(R.id.ad_body)
            val callToActionView = findViewById<TextView>(R.id.ad_call_to_action)

            this.headlineView = headlineView
            headlineView.text = nativeAd.headline

            this.bodyView = bodyView
            bodyView?.text = nativeAd.body

            this.callToActionView = callToActionView
            callToActionView?.text = nativeAd.callToAction

            setNativeAd(nativeAd)
        }

        return nativeAdView
    }
}