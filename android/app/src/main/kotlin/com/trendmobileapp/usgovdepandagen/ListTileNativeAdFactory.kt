package com.trendmobileapp.usgovdepandagen

import android.content.Context
import android.graphics.Color
import android.view.LayoutInflater
import android.widget.TextView
import android.widget.ImageView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class ListTileNativeAdFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.list_tile_native_ad, null) as NativeAdView

        with(nativeAdView) {
            val headlineView = findViewById<TextView>(R.id.ad_headline)
            val bodyView = findViewById<TextView>(R.id.ad_body)
            val callToActionView = findViewById<TextView>(R.id.ad_call_to_action)
            val iconView = findViewById<ImageView>(R.id.ad_icon)
            val starRatingView = findViewById<TextView>(R.id.ad_stars)
            val storeView = findViewById<TextView>(R.id.ad_store)
            val priceView = findViewById<TextView>(R.id.ad_price)
            val advertiserView = findViewById<TextView>(R.id.ad_advertiser)

            this.headlineView = headlineView
            headlineView.text = nativeAd.headline

            this.bodyView = bodyView
            bodyView?.text = nativeAd.body

            this.callToActionView = callToActionView
            callToActionView?.text = nativeAd.callToAction

            this.iconView = iconView
            if (nativeAd.icon != null) {
                iconView.setImageDrawable(nativeAd.icon?.drawable)
            } else {
                iconView.setImageDrawable(null)
            }

            this.starRatingView = starRatingView
            if (nativeAd.starRating != null) {
                starRatingView.text = "${nativeAd.starRating}"
            }

            this.storeView = storeView
            storeView?.text = nativeAd.store

            this.priceView = priceView
            priceView?.text = nativeAd.price

            this.advertiserView = advertiserView
            advertiserView?.text = nativeAd.advertiser

            setNativeAd(nativeAd)
        }

        return nativeAdView
    }
}