enum AdSurface {
  appOpen,
  interstitial,
  detailBanner,
  nativeInline,
}

class AdPolicyConfig {
  const AdPolicyConfig({
    required this.appOpen,
    required this.interstitial,
    required this.detailBanner,
    required this.native,
  });

  static const current = AdPolicyConfig(
    appOpen: true,
    interstitial: true,
    detailBanner: false,
    native: false,
  );

  final bool appOpen;
  final bool interstitial;
  final bool detailBanner;
  final bool native;

  bool isEnabled(AdSurface surface) {
    switch (surface) {
      case AdSurface.appOpen:
        return appOpen;
      case AdSurface.interstitial:
        return interstitial;
      case AdSurface.detailBanner:
        return detailBanner;
      case AdSurface.nativeInline:
        return native;
    }
  }
}
