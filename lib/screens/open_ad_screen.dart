import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../ads/ad_manager.dart';
import '../services/consent_service.dart';
import 'home_screen.dart';

class OpenAdScreen extends StatefulWidget {
  const OpenAdScreen({super.key});

  @override
  State<OpenAdScreen> createState() => _OpenAdScreenState();
}

class _OpenAdScreenState extends State<OpenAdScreen> {
  final AdManager _adManager = AdManager();
  bool _adCompleted = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _showOpenAdAndNavigate();
  }

  void _showOpenAdAndNavigate() async {
    // Wait for consent service to be initialized
    await ConsentService.instance.waitForInitialization();
    
    // Wait a bit more for the screen to be built and ads to be loaded
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (!mounted) return;

    if (kDebugMode) {
      print('Attempting to show open ad...');
    }

    // Show app open ad with callback
    try {
      bool adAttempted = await _adManager.showAppOpenAdWithCallback(
        onCompleted: () {
          if (mounted && !_navigated) {
            if (kDebugMode) {
              print('Open ad completed, navigating to home');
            }
            _navigateToHome();
          }
        },
      );
      
      if (!adAttempted) {
        // Ad was not shown (no consent, web platform, or not available)
        if (kDebugMode) {
          print('Open ad not shown, navigating directly to home');
        }
        if (!_navigated) {
          _navigateToHome();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to show open ad: $e');
      }
      if (!_navigated) {
        _navigateToHome();
      }
    }
  }

  void _navigateToHome() {
    if (_navigated || !mounted) return;
    
    setState(() {
      _navigated = true;
    });

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0), // Match app theme
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance,
                  size: 40,
                  color: Color(0xFF1565C0),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              
              const SizedBox(height: 24),
              
              // Loading text
              const Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Preparing your experience',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}