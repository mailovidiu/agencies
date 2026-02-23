import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/department.dart';

/// Background message handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background message received: ${message.messageId}');
}

/// Service for managing push notifications via Firebase Cloud Messaging.
/// No user account required — uses device tokens and topic subscriptions.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Preferences keys
  static const String _prefNotificationsEnabled = 'notifications_enabled';
  static const String _prefTopicPrefix = 'notification_topic_';

  // Notification channel
  static const String _channelId = 'gov_departments_updates';
  static const String _channelName = 'Department Updates';
  static const String _channelDescription =
      'Notifications about government department updates';

  /// Stream controller for notification taps (to handle navigation)
  final StreamController<String?> _onNotificationTap =
      StreamController<String?>.broadcast();
  Stream<String?> get onNotificationTap => _onNotificationTap.stream;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Request permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('🔔 Notification permission denied');
        return;
      }

      print(
          '🔔 Notification permission: ${settings.authorizationStatus}');

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      print('🔔 FCM Token: ${_fcmToken?.substring(0, 20)}...');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        print('🔔 FCM Token refreshed');
      });

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Subscribe to default topics based on saved preferences
      await _restoreTopicSubscriptions();

      _isInitialized = true;
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Notification service initialization failed: $e');
    }
  }

  /// Initialize flutter_local_notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _onNotificationTap.add(response.payload);
      },
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle foreground messages — show as local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Department Update',
      notification.body ?? 'A government department has been updated.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['departmentId'],
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Notification tapped: ${message.data}');
    _onNotificationTap.add(message.data['departmentId']);
  }

  // ─── Topic Subscription Management ───

  /// Get the FCM topic name for a department category
  String _topicName(DepartmentCategory category) {
    return 'dept_${category.name}';
  }

  /// Check if notifications are globally enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefNotificationsEnabled) ?? true;
  }

  /// Enable or disable all notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefNotificationsEnabled, enabled);

    if (!enabled) {
      // Unsubscribe from all topics
      for (final category in DepartmentCategory.values) {
        await _messaging.unsubscribeFromTopic(_topicName(category));
      }
      print('🔔 All notification topics unsubscribed');
    } else {
      // Re-subscribe to previously selected topics
      await _restoreTopicSubscriptions();
      print('🔔 Notification topics restored');
    }
  }

  /// Check if subscribed to a specific category topic
  Future<bool> isSubscribedToCategory(DepartmentCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefTopicPrefix${category.name}') ?? true;
  }

  /// Subscribe or unsubscribe from a category topic
  Future<void> setCategorySubscription(
      DepartmentCategory category, bool subscribed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefTopicPrefix${category.name}', subscribed);

    final enabled = await areNotificationsEnabled();
    if (!enabled) return;

    if (subscribed) {
      await _messaging.subscribeToTopic(_topicName(category));
      print('🔔 Subscribed to topic: ${_topicName(category)}');
    } else {
      await _messaging.unsubscribeFromTopic(_topicName(category));
      print('🔔 Unsubscribed from topic: ${_topicName(category)}');
    }
  }

  /// Restore topic subscriptions from saved preferences
  Future<void> _restoreTopicSubscriptions() async {
    final enabled = await areNotificationsEnabled();
    if (!enabled) return;

    for (final category in DepartmentCategory.values) {
      final subscribed = await isSubscribedToCategory(category);
      if (subscribed) {
        await _messaging.subscribeToTopic(_topicName(category));
      }
    }
    print('🔔 Topic subscriptions restored');
  }

  /// Get a map of all category subscription states
  Future<Map<DepartmentCategory, bool>> getAllCategorySubscriptions() async {
    final result = <DepartmentCategory, bool>{};
    for (final category in DepartmentCategory.values) {
      result[category] = await isSubscribedToCategory(category);
    }
    return result;
  }

  /// Dispose resources
  void dispose() {
    _onNotificationTap.close();
  }
}
