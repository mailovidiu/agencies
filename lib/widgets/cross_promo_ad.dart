import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:govt_departments_and_agencies/models/cross_promo_ad_config.dart';
import 'package:govt_departments_and_agencies/services/cross_promo_service.dart';
import 'package:govt_departments_and_agencies/services/firebase_analytics_service.dart';

class CrossPromoAd extends StatefulWidget {
  const CrossPromoAd({super.key});

  @override
  State<CrossPromoAd> createState() => _CrossPromoAdState();
}

class _CrossPromoAdState extends State<CrossPromoAd> {
  CrossPromoAdConfig? _adConfig;
  bool _loading = true;
  bool _impressionLogged = false;
  static const String _placement = 'dashboard_home';

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    final ad = await CrossPromoService.instance.getAd();
    if (mounted) {
      setState(() {
        _adConfig = ad;
        _loading = false;
      });
    }
    if (ad != null) {
      await _logImpression(ad);
    }
  }

  Future<void> _logImpression(CrossPromoAdConfig ad) async {
    if (_impressionLogged) return;
    _impressionLogged = true;
    try {
      await FirebaseAnalyticsService.instance.logCrossPromoAdImpression(
        adId: ad.id,
        adTitle: ad.title,
        sourceAppId: CrossPromoService.appId,
        placement: _placement,
      );
    } catch (e) {
      debugPrint('Failed to log cross promo ad impression: $e');
    }
  }

  Future<void> _launchURL() async {
    if (_adConfig == null) return;
    final ad = _adConfig!;
    try {
      await FirebaseAnalyticsService.instance.logCrossPromoAdClick(
        adId: ad.id,
        adTitle: ad.title,
        sourceAppId: CrossPromoService.appId,
        placement: _placement,
      );
    } catch (e) {
      debugPrint('Failed to log cross promo ad click: $e');
    }
    final urlString =
        defaultTargetPlatform == TargetPlatform.iOS ? ad.iosUrl : ad.androidUrl;
    if (urlString.isEmpty) {
      debugPrint('No cross promo URL configured for ${ad.id}');
      return;
    }
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _adConfig == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ad = _adConfig!;
    final gradientColors = ad.parsedGradientColors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launchURL,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Featured app',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ad.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                      ),
                      child: Icon(ad.iconData, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        ad.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _launchURL,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(ad.ctaLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
