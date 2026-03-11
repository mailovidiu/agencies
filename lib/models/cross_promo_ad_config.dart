import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CrossPromoAdConfig {
  final String id;
  final String title;
  final String description;
  final String ctaLabel;
  final String iosUrl;
  final String androidUrl;
  final String iconName;
  final List<String> gradientColors;
  final List<String> targetApps;
  final bool isActive;
  final int priority;
  final DateTime? startDate;
  final DateTime? endDate;

  const CrossPromoAdConfig({
    required this.id,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.iosUrl,
    required this.androidUrl,
    required this.iconName,
    required this.gradientColors,
    required this.targetApps,
    required this.isActive,
    required this.priority,
    this.startDate,
    this.endDate,
  });

  factory CrossPromoAdConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CrossPromoAdConfig(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ctaLabel: data['ctaLabel'] ?? 'Learn More',
      iosUrl: data['iosUrl'] ?? '',
      androidUrl: data['androidUrl'] ?? '',
      iconName: data['iconName'] ?? 'star_rounded',
      gradientColors: List<String>.from(data['gradientColors'] ?? []),
      targetApps: List<String>.from(data['targetApps'] ?? []),
      isActive: data['isActive'] ?? false,
      priority: data['priority'] ?? 0,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
    );
  }

  factory CrossPromoAdConfig.fromJson(Map<String, dynamic> json) {
    return CrossPromoAdConfig(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      ctaLabel: json['ctaLabel'] ?? 'Learn More',
      iosUrl: json['iosUrl'] ?? '',
      androidUrl: json['androidUrl'] ?? '',
      iconName: json['iconName'] ?? 'star_rounded',
      gradientColors: List<String>.from(json['gradientColors'] ?? []),
      targetApps: List<String>.from(json['targetApps'] ?? []),
      isActive: json['isActive'] ?? false,
      priority: json['priority'] ?? 0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate:
          json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'ctaLabel': ctaLabel,
        'iosUrl': iosUrl,
        'androidUrl': androidUrl,
        'iconName': iconName,
        'gradientColors': gradientColors,
        'targetApps': targetApps,
        'isActive': isActive,
        'priority': priority,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };

  IconData get iconData => _iconMap[iconName] ?? Icons.star_rounded;

  List<Color> get parsedGradientColors {
    if (gradientColors.length < 2) {
      return const [Color(0xFF2196F3), Color(0xFF1976D2)];
    }
    return gradientColors.map(_hexToColor).toList();
  }

  static Color _hexToColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return const Color(0xFF2196F3);
    }
    return cleaned.length == 6 ? Color(0xFF000000 + value) : Color(value);
  }

  bool get isWithinDateRange {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  static const _iconMap = <String, IconData>{
    'speed_rounded': Icons.speed_rounded,
    'star_rounded': Icons.star_rounded,
    'school_rounded': Icons.school_rounded,
    'health_and_safety_rounded': Icons.health_and_safety_rounded,
    'science_rounded': Icons.science_rounded,
    'eco_rounded': Icons.eco_rounded,
    'account_balance_rounded': Icons.account_balance_rounded,
    'psychology_rounded': Icons.psychology_rounded,
    'home_rounded': Icons.home_rounded,
    'shopping_cart_rounded': Icons.shopping_cart_rounded,
    'fitness_center_rounded': Icons.fitness_center_rounded,
    'restaurant_rounded': Icons.restaurant_rounded,
    'directions_car_rounded': Icons.directions_car_rounded,
    'flight_rounded': Icons.flight_rounded,
    'pets_rounded': Icons.pets_rounded,
    'music_note_rounded': Icons.music_note_rounded,
    'camera_alt_rounded': Icons.camera_alt_rounded,
    'bolt_rounded': Icons.bolt_rounded,
    'water_drop_rounded': Icons.water_drop_rounded,
    'thermostat_rounded': Icons.thermostat_rounded,
    'calculate_rounded': Icons.calculate_rounded,
    'attach_money_rounded': Icons.attach_money_rounded,
    'savings_rounded': Icons.savings_rounded,
    'trending_up_rounded': Icons.trending_up_rounded,
    'work_rounded': Icons.work_rounded,
    'build_rounded': Icons.build_rounded,
    'code_rounded': Icons.code_rounded,
    'palette_rounded': Icons.palette_rounded,
    'auto_awesome_rounded': Icons.auto_awesome_rounded,
  };
}
