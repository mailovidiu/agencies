import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:govt_departments_and_agencies/models/cross_promo_ad_config.dart';
import 'package:govt_departments_and_agencies/services/storage_service.dart';

class CrossPromoService {
  static const String appId = 'usgovagencies';

  static const Duration _cacheTtl = Duration(hours: 1);
  static const String _collection = 'cross_promo_ads';

  static FirebaseOptions get _crossPromoOptions =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? _iosOptions
          : _androidOptions;

  static const _iosOptions = FirebaseOptions(
    apiKey: 'AIzaSyDxmQwijyEZIhPZRSQUNa3fylRIbsPb9kc',
    appId: '1:342276125716:ios:1b763a61d8baea0e76e301',
    messagingSenderId: '342276125716',
    projectId: 'cross-promo-ads',
    storageBucket: 'cross-promo-ads.firebasestorage.app',
  );

  static const _androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyDQVgUltELW841Uuaw7_OTdxIdhtt6oRCM',
    appId: '1:342276125716:android:fa2923abf924180876e301',
    messagingSenderId: '342276125716',
    projectId: 'cross-promo-ads',
    storageBucket: 'cross-promo-ads.firebasestorage.app',
  );

  static CrossPromoService? _instance;
  FirebaseFirestore? _firestore;

  CrossPromoService._();

  static CrossPromoService get instance {
    _instance ??= CrossPromoService._();
    return _instance!;
  }

  Future<FirebaseFirestore> _getFirestore() async {
    if (_firestore != null) return _firestore!;
    FirebaseApp app;
    try {
      app = Firebase.app('crossPromo');
    } catch (_) {
      app = await Firebase.initializeApp(
        name: 'crossPromo',
        options: _crossPromoOptions,
      );
    }
    _firestore = FirebaseFirestore.instanceFor(app: app);
    return _firestore!;
  }

  Future<CrossPromoAdConfig?> getAd() async {
    try {
      final storage = await StorageService.getInstance();
      final cacheTs = storage.loadCrossPromoAdsCacheTimestamp();
      final cacheIsFresh =
          cacheTs != null && DateTime.now().difference(cacheTs) < _cacheTtl;

      List<CrossPromoAdConfig> ads;
      if (cacheIsFresh) {
        ads = await storage.loadCrossPromoAdsCache();
      } else {
        ads = await _fetchFromFirestore();
        await storage.saveCrossPromoAdsCache(ads);
      }

      final eligible = ads
          .where((ad) => ad.isActive && ad.isWithinDateRange)
          .toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));

      return eligible.isEmpty ? null : eligible.first;
    } catch (e) {
      debugPrint('CrossPromoService.getAd error: $e');
      try {
        final storage = await StorageService.getInstance();
        final cached = await storage.loadCrossPromoAdsCache();
        final eligible = cached
            .where((ad) => ad.isActive && ad.isWithinDateRange)
            .toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));
        return eligible.isEmpty ? null : eligible.first;
      } catch (_) {
        return null;
      }
    }
  }

  Future<List<CrossPromoAdConfig>> _fetchFromFirestore() async {
    final firestore = await _getFirestore();
    final snapshot = await firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('targetApps', arrayContains: appId)
        .get();
    return snapshot.docs
        .map((doc) => CrossPromoAdConfig.fromFirestore(doc))
        .toList();
  }
}
