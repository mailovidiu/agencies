import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/department_provider.dart';
import 'providers/auth_provider.dart';
import 'services/department_service.dart';
import 'services/firebase_initialization_service.dart';
import 'services/app_initialization_service.dart';
import 'repositories/hybrid_department_repository.dart';
import 'screens/splash_screen.dart';
import 'ads/app_lifecycle_manager.dart';
import 'ads/ad_manager.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with comprehensive error handling
  final firebaseInit = FirebaseInitializationService();
  bool firebaseReady = false;

  try {
    firebaseReady = await firebaseInit.initializeFirebase();
    if (firebaseReady) {
      print('🔥 Firebase initialized and ready for production use');
    } else {
      print('⚠️  Firebase initialization failed, using hybrid mode');
    }
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  // Initialize app services (consent, tracking, ads)
  try {
    await AppInitializationService().initialize();
  } catch (e) {
    print('❌ App initialization error: $e');
  }

  // Always use hybrid repository for maximum compatibility
  final departmentRepository = HybridDepartmentRepository();
  await departmentRepository.initialize();
  print(
      '🗄️  Hybrid repository initialized - Status: ${departmentRepository.connectionStatus}');

  runApp(MyApp(
    departmentService: DepartmentService(departmentRepository),
  ));
}

class MyApp extends StatefulWidget {
  final DepartmentService departmentService;

  const MyApp({
    super.key,
    required this.departmentService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLifecycleManager _appLifecycleManager = AppLifecycleManager();

  @override
  void initState() {
    super.initState();
    _appLifecycleManager.initialize();
  }

  @override
  void dispose() {
    _appLifecycleManager.dispose();
    AdManager().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(
            create: (context) => DepartmentProvider(widget.departmentService)),
      ],
      child: MaterialApp(
        title: 'Gov\'t Departments & Agencies',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}
