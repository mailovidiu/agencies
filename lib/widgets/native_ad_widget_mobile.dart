import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ads/ad_helper.dart';
import '../services/consent_service.dart';

class NativeAdWidget extends StatefulWidget {
  final double height;

  const NativeAdWidget({super.key, this.height = 300});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    ConsentService.instance.addListener(_handleConsentChanged);
    if (ConsentService.instance.shouldShowAds) {
      _loadNativeAd();
    }
  }

  void _handleConsentChanged() {
    if (!mounted) return;

    if (!ConsentService.instance.shouldShowAds) {
      setState(_disposeNativeAd);
      return;
    }

    if (_nativeAd == null) {
      _loadNativeAd();
    } else {
      setState(() {});
    }
  }

  void _loadNativeAd() {
    if (!ConsentService.instance.shouldShowAds) return;

    _disposeNativeAd();

    final nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted && identical(_nativeAd, ad)) {
            setState(() {
              _isAdLoaded = true;
            });
          }
          if (kDebugMode) {
            print('Native ad loaded successfully');
          }
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            print('Failed to load native ad: $error');
          }
          ad.dispose();
          if (mounted && identical(_nativeAd, ad)) {
            setState(() {
              _nativeAd = null;
              _isAdLoaded = false;
            });
          }
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 10.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.blue,
          style: NativeTemplateFontStyle.monospace,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black,
          style: NativeTemplateFontStyle.italic,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey[600],
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
    );

    _nativeAd = nativeAd;
    nativeAd.load();
  }

  void _disposeNativeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _isAdLoaded = false;
  }

  @override
  void dispose() {
    ConsentService.instance.removeListener(_handleConsentChanged);
    _disposeNativeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if ads are not consented
    if (!ConsentService.instance.shouldShowAds) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _nativeAd == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
