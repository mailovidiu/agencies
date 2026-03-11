import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';
import '../services/consent_service.dart';

class CollapsibleBannerAd extends StatefulWidget {
  const CollapsibleBannerAd({super.key});

  @override
  State<CollapsibleBannerAd> createState() => _CollapsibleBannerAdState();
}

class _CollapsibleBannerAdState extends State<CollapsibleBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int? _lastAdWidth;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    ConsentService.instance.addListener(_handleConsentChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!ConsentService.instance.shouldShowAds) {
      _disposeBannerAd();
      return;
    }

    final width = MediaQuery.sizeOf(context).width.truncate();
    final orientation = MediaQuery.orientationOf(context);
    final shouldReload = _bannerAd == null ||
        _lastAdWidth != width ||
        _lastOrientation != orientation;

    if (shouldReload) {
      _lastAdWidth = width;
      _lastOrientation = orientation;
      _loadAd(width);
    }
  }

  void _handleConsentChanged() {
    if (!mounted) return;

    if (!ConsentService.instance.shouldShowAds) {
      setState(_disposeBannerAd);
      return;
    }

    final width = MediaQuery.sizeOf(context).width.truncate();
    final orientation = MediaQuery.orientationOf(context);
    final shouldReload = _bannerAd == null ||
        _lastAdWidth != width ||
        _lastOrientation != orientation;

    if (shouldReload) {
      _lastAdWidth = width;
      _lastOrientation = orientation;
      _loadAd(width);
    } else {
      setState(() {});
    }
  }

  Future<void> _loadAd(int width) async {
    _disposeBannerAd();

    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (!mounted || size == null || !ConsentService.instance.shouldShowAds) {
      return;
    }

    final bannerAd = BannerAd(
      adUnitId: AdHelper.collapsibleBannerAdUnitId,
      size: size,
      request: const AdRequest(extras: {'collapsible': 'bottom'}),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted && identical(_bannerAd, ad)) {
            setState(() {
              _bannerAd = ad as BannerAd;
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              if (identical(_bannerAd, ad)) {
                _bannerAd = null;
              }
              _isAdLoaded = false;
            });
          }
        },
      ),
    );

    _bannerAd = bannerAd;
    bannerAd.load();
  }

  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
  }

  @override
  void dispose() {
    ConsentService.instance.removeListener(_handleConsentChanged);
    _disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ConsentService.instance.shouldShowAds) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
