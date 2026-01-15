import 'package:flutter/material.dart';
import 'native_ad_widget.dart';
import '../services/consent_service.dart';

class MediumNativeAdWidget extends StatelessWidget {
  const MediumNativeAdWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ConsentService.instance.shouldShowAds) {
      return const SizedBox.shrink();
    }
    return const NativeAdWidget(height: 300);
  }
}