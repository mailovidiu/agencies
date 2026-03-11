import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../ads/ad_manager.dart';
import '../services/consent_service.dart';
import '../utils/app_logger.dart';
import 'home_screen.dart';

class OpenAdScreen extends StatefulWidget {
  const OpenAdScreen({super.key});

  @override
  State<OpenAdScreen> createState() => _OpenAdScreenState();
}

class _OpenAdScreenState extends State<OpenAdScreen> {
  final AdManager _adManager = AdManager();
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
      logVerbose('Attempting to show open ad...');
    }

    // Show app open ad with callback
    try {
      bool adAttempted = await _adManager.showAppOpenAdWithCallback(
        onCompleted: () {
          if (mounted && !_navigated) {
            if (kDebugMode) {
              logVerbose('Open ad completed, navigating to home');
            }
            _navigateToHome();
          }
        },
      );

      if (!adAttempted) {
        // Ad was not shown (no consent, web platform, or not available)
        if (kDebugMode) {
          logVerbose('Open ad not shown, navigating directly to home');
        }
        if (!_navigated) {
          _navigateToHome();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        logVerbose('Failed to show open ad: $e');
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
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const SizedBox.shrink(),
    );
  }
}
