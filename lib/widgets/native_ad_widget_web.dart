// Web stub implementation for NativeAdWidget
import 'package:flutter/material.dart';

class NativeAdWidget extends StatelessWidget {
  final double height;
  
  const NativeAdWidget({super.key, this.height = 300});

  @override
  Widget build(BuildContext context) {
    // Return empty widget on web platform
    return const SizedBox.shrink();
  }
}