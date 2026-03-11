import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import 'firebase_service.dart';
import 'firebase_admin_service.dart';
import 'notification_service.dart';
import '../utils/data_migration.dart';
import '../repositories/firebase_department_repository.dart';
import '../utils/app_logger.dart';

/// Comprehensive Firebase initialization service that handles all setup tasks
/// for the US Government Departments and Agencies app
class FirebaseInitializationService {
  static final FirebaseInitializationService _instance =
      FirebaseInitializationService._internal();
  factory FirebaseInitializationService() => _instance;
  FirebaseInitializationService._internal();

  bool _isInitialized = false;
  String? _initializationError;

  bool get isInitialized => _isInitialized;
  String? get initializationError => _initializationError;

  /// Initialize Firebase and all related services
  Future<bool> initializeFirebase() async {
    try {
      logVerbose('🔥 Starting Firebase initialization...');

      // Step 1: Initialize Firebase Core
      await _initializeFirebaseCore();

      // Step 2: Configure Firestore settings
      await _configureFirestore();

      // Step 3: Initialize Firebase Service
      final firebaseService = FirebaseService();
      final serviceInitialized = await firebaseService.initialize();

      if (!serviceInitialized) {
        throw Exception('Firebase service failed to initialize');
      }

      // Step 4: Initialize Firebase Admin Service
      await FirebaseAdminService().initialize();

      // Step 4.5: Initialize Notification Service (FCM)
      try {
        await NotificationService().initialize();
      } catch (e) {
        logVerbose('⚠️  Notification service warning: $e');
      }

      // Step 5: Handle initial data migration/setup
      await _handleDataInitialization();

      // Step 6: Validate setup
      await _validateSetup();

      _isInitialized = true;
      _initializationError = null;

      logVerbose('✅ Firebase initialization completed successfully');
      return true;
    } catch (e) {
      _initializationError = e.toString();
      logError('❌ Firebase initialization failed: $e');
      return false;
    }
  }

  /// Initialize Firebase Core with proper error handling
  Future<void> _initializeFirebaseCore() async {
    try {
      // Check if Firebase is already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        logVerbose('✅ Firebase Core initialized');
      } else {
        logVerbose('✅ Firebase Core already initialized');
      }
    } catch (e) {
      throw Exception('Failed to initialize Firebase Core: $e');
    }
  }

  /// Configure Firestore settings for optimal performance
  Future<void> _configureFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Enable network (in case it was disabled)
      await firestore.enableNetwork();

      // Configure settings for better performance
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      logVerbose('✅ Firestore configured');
    } catch (e) {
      logVerbose('⚠️  Firestore configuration warning: $e');
      // Don't throw - app can work without these optimizations
    }
  }

  /// Handle initial data migration and setup
  Future<void> _handleDataInitialization() async {
    try {
      logVerbose('📊 Initializing data...');

      // Initialize Firebase data migration
      final repository = FirebaseDepartmentRepository();
      final migrationUtility = DataMigrationUtility(repository);

      // Check if we need to initialize data
      final hasData = await migrationUtility.hasFirebaseData();

      if (!hasData) {
        logVerbose(
            '📥 No existing data found, initializing with sample data...');

        // Try to migrate from localStorage first
        if (await migrationUtility.hasLocalStorageData()) {
          await migrationUtility.migrateFromLocalStorage();
          logVerbose('✅ Data migrated from localStorage');
        } else {
          await migrationUtility.loadSampleData();
          logVerbose('✅ Sample data loaded');
        }
      } else {
        logVerbose('✅ Existing data found, skipping initialization');
      }
    } catch (e) {
      logVerbose('⚠️  Data initialization warning: $e');
      // Don't throw - app can work with empty data
    }
  }

  /// Validate Firebase setup and configuration
  Future<void> _validateSetup() async {
    try {
      logVerbose('🔍 Validating Firebase setup...');

      // Test Authentication
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      logVerbose(
          '🔐 Auth state: ${currentUser != null ? 'Signed in' : 'Anonymous'}');

      // Test Firestore connectivity
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('_health_check').limit(1).get();
      logVerbose('📊 Firestore: Connected');

      // Validate admin service
      final adminService = FirebaseAdminService();
      await adminService.getDashboardStats();
      logVerbose('👨‍💼 Admin service: Ready');

      logVerbose('✅ Firebase setup validation completed');
    } catch (e) {
      logVerbose('⚠️  Setup validation warning: $e');
      // Don't throw - these are validation checks
    }
  }

  /// Check Firebase connection status
  Future<Map<String, dynamic>> getConnectionStatus() async {
    try {
      final status = <String, dynamic>{};

      // Check Firebase Core
      status['core'] = Firebase.apps.isNotEmpty;

      // Check Auth
      try {
        final auth = FirebaseAuth.instance;
        status['auth'] = {
          'initialized': true,
          'currentUser': auth.currentUser?.uid != null,
          'email': auth.currentUser?.email,
        };
      } catch (e) {
        status['auth'] = {
          'initialized': false,
          'error': e.toString(),
        };
      }

      // Check Firestore
      try {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('_connection_test').limit(1).get();
        status['firestore'] = {
          'connected': true,
          'timestamp': DateTime.now().toIso8601String(),
        };
      } catch (e) {
        status['firestore'] = {
          'connected': false,
          'error': e.toString(),
        };
      }

      // Overall status
      status['overall'] = _isInitialized;
      status['initializationError'] = _initializationError;

      return status;
    } catch (e) {
      return {
        'overall': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Reset initialization state (for testing/debugging)
  void reset() {
    _isInitialized = false;
    _initializationError = null;
  }

  /// Get Firebase project information
  Map<String, dynamic> getProjectInfo() {
    try {
      if (Firebase.apps.isEmpty) {
        return {'error': 'Firebase not initialized'};
      }

      final app = Firebase.app();
      return {
        'name': app.name,
        'projectId': app.options.projectId,
        'appId': app.options.appId,
        'apiKey':
            '${app.options.apiKey.substring(0, 10)}...', // Hide full API key
        'authDomain': app.options.authDomain,
        'storageBucket': app.options.storageBucket,
        'messagingSenderId': app.options.messagingSenderId,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Enable/disable Firestore offline persistence
  Future<void> setOfflineMode(bool enabled) async {
    try {
      final firestore = FirebaseFirestore.instance;

      if (enabled) {
        await firestore.disableNetwork();
        logVerbose('📴 Firestore offline mode enabled');
      } else {
        await firestore.enableNetwork();
        logVerbose('🌐 Firestore online mode enabled');
      }
    } catch (e) {
      logVerbose('⚠️  Failed to change offline mode: $e');
    }
  }

  /// Get detailed initialization log
  List<String> getInitializationLog() {
    return [
      '🔥 Firebase Initialization Service',
      '========================',
      'Status: ${_isInitialized ? "✅ Initialized" : "❌ Not Initialized"}',
      if (_initializationError != null) 'Error: $_initializationError',
      'Timestamp: ${DateTime.now().toIso8601String()}',
      '========================',
    ];
  }
}

/// Exception class for Firebase initialization errors
class FirebaseInitializationException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  const FirebaseInitializationException(
    this.message, [
    this.code,
    this.originalException,
  ]);

  @override
  String toString() {
    return 'FirebaseInitializationException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}
