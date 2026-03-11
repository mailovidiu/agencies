import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:govt_departments_and_agencies/models/cross_promo_ad_config.dart';

class StorageService {
  static const String _keyCrossPromoAdsCache = 'cross_promo_ads_cache';
  static const String _keyCrossPromoAdsCacheTimestamp =
      'cross_promo_ads_cache_ts';

  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    final instance = _instance ??= StorageService._();
    instance._prefs ??= await SharedPreferences.getInstance();
    return instance;
  }

  Future<bool> saveCrossPromoAdsCache(List<CrossPromoAdConfig> ads) async {
    try {
      final jsonList = ads.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      final success =
          await _prefs!.setString(_keyCrossPromoAdsCache, jsonString);
      await _prefs!.setString(
        _keyCrossPromoAdsCacheTimestamp,
        DateTime.now().toIso8601String(),
      );
      return success;
    } catch (e) {
      debugPrint('Error saving cross promo ads cache: $e');
      return false;
    }
  }

  Future<List<CrossPromoAdConfig>> loadCrossPromoAdsCache() async {
    try {
      final jsonString = _prefs!.getString(_keyCrossPromoAdsCache);
      if (jsonString == null || jsonString.isEmpty) return [];
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) =>
              CrossPromoAdConfig.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading cross promo ads cache: $e');
      return [];
    }
  }

  DateTime? loadCrossPromoAdsCacheTimestamp() {
    try {
      final ts = _prefs!.getString(_keyCrossPromoAdsCacheTimestamp);
      if (ts == null) return null;
      return DateTime.tryParse(ts);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearAllData() async {
    await _prefs!.remove(_keyCrossPromoAdsCache);
    await _prefs!.remove(_keyCrossPromoAdsCacheTimestamp);
  }
}
