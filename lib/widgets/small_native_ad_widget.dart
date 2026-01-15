import 'package:flutter/material.dart';
import 'native_ad_widget.dart';
import '../services/consent_service.dart';

class SmallNativeAdWidget extends StatelessWidget {
  const SmallNativeAdWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ConsentService.instance.shouldShowAds) {
      return const SizedBox.shrink();
    }
    return const NativeAdWidget(height: 200);
  }
}