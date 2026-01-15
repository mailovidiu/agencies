package com.trendmobileapp.usgovdepandagen

import android.content.Context
import android.view.LayoutInflater
import android.widget.TextView
import android.widget.ImageView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class MediumNativeAdFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.medium_native_ad, null) as NativeAdView

        with(nativeAdView) {
            val headlineView = findViewById<TextView>(R.id.ad_headline)
            val bodyView = findViewById<TextView>(R.id.ad_body)
            val callToActionView = findViewById<TextView>(R.id.ad_call_to_action)
            val iconView = findViewById<ImageView>(R.id.ad_icon)
            val mediaView = findViewById<com.google.android.gms.ads.nativead.MediaView>(R.id.ad_media)
            val starRatingView = findViewById<TextView>(R.id.ad_stars)
            val priceView = findViewById<TextView>(R.id.ad_price)

            this.headlineView = headlineView
            headlineView.text = nativeAd.headline

            this.bodyView = bodyView
            bodyView?.text = nativeAd.body

            this.callToActionView = callToActionView
            callToActionView?.text = nativeAd.callToAction

            this.iconView = iconView
            if (nativeAd.icon != null) {
                iconView.setImageDrawable(nativeAd.icon?.drawable)
            }

            this.mediaView = mediaView
            mediaView.mediaContent = nativeAd.mediaContent

            this.starRatingView = starRatingView
            if (nativeAd.starRating != null) {
                starRatingView.text = "${nativeAd.starRating} ⭐"
            }

            this.priceView = priceView
            priceView?.text = nativeAd.price

            setNativeAd(nativeAd)
        }

        return nativeAdView
    }
}