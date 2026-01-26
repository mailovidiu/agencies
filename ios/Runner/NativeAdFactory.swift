import Flutter
import google_mobile_ads

class NativeAdFactory: NSObject, FLTNativeAdFactory {
    let xibName: String
    
    init(xibName: String) {
        self.xibName = xibName
    }
    
    func createNativeAd(_ nativeAd: NativeAd,
                        customOptions: [AnyHashable : Any]? = nil) -> NativeAdView? {
        let nib = UINib(nibName: xibName, bundle: nil)
        guard let nativeAdView = nib.instantiate(withOwner: nil, options: nil).first as? NativeAdView else {
            return nil
        }
        
        // Map the assets
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        nativeAdView.bodyView?.isHidden = nativeAd.body == nil
        
        (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil
        
        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil
        
        (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
        nativeAdView.storeView?.isHidden = nativeAd.store == nil
        
        (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
        nativeAdView.priceView?.isHidden = nativeAd.price == nil
        
        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil
        
        // Star rating
        if let starRating = nativeAd.starRating {
            // If you have a star rating view
           // (nativeAdView.starRatingView as? UILabel)?.text = "\(starRating)"
        }
        // nativeAdView.starRatingView?.isHidden = nativeAd.starRating == nil
        
        // Associate the native ad with the view
        nativeAdView.nativeAd = nativeAd
        
        return nativeAdView
    }
}
