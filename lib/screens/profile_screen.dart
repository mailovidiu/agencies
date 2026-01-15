import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/consent_service.dart';
import '../ads/ad_manager.dart';
import '../ads/ad_helper.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown';
      });
    }
  }
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _showAdPreferencesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ad Preferences'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose how you\'d like to experience ads in this app:'),
            const SizedBox(height: 16),
            RadioListTile<AdConsentChoice>(
              title: const Text('Personalized Ads'),
              subtitle: const Text('Ads tailored to your interests'),
              value: AdConsentChoice.personalizedAds,
              groupValue: ConsentService.instance.userChoice,
              onChanged: (value) => _updateAdChoice(value!),
            ),
            RadioListTile<AdConsentChoice>(
              title: const Text('Non-Personalized Ads'),
              subtitle: const Text('Generic ads not based on your interests'),
              value: AdConsentChoice.nonPersonalizedAds,
              groupValue: ConsentService.instance.userChoice,
              onChanged: (value) => _updateAdChoice(value!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ConsentService.instance.resetConsent();
              if (mounted) {
                Navigator.of(context).pop();
                setState(() {});
              }
            },
            child: const Text('Reset Consent'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAdChoice(AdConsentChoice choice) async {
    await ConsentService.instance.updateConsentChoice(choice);
    
    // Reinitialize ads since both options show ads
    try {
      await AdHelper.initializeAds();
      await AdManager().initialize();
      print('📱 Ads reinitialized after user consent change');
    } catch (e) {
      print('📱 Error reinitializing ads: $e');
    }
    
    if (mounted) {
      Navigator.of(context).pop();
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ad preference updated successfully'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Profile Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to Gov\'t Departments',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your guide to government agencies',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Legal Section
            Text(
              'Legal & Support',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Privacy Policy
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Privacy Policy'),
                subtitle: const Text('Learn how we handle your data'),
                trailing: Icon(
                  Icons.open_in_new,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () async {
                  try {
                    await _launchUrl('https://trendmobilesites.com/terms-apps/gov_agency/privacy.html');
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open privacy policy: \$e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: 8),

            // Terms of Service
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.description_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Terms of Service'),
                subtitle: const Text('Read our terms and conditions'),
                trailing: Icon(
                  Icons.open_in_new,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () async {
                  try {
                    await _launchUrl('https://trendmobilesites.com/terms-apps/gov_agency/terms.html');
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open terms of service: \$e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: 24),

            // Ad Preferences Section
            Text(
              'Ad Preferences',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: ListTile(
                leading: Icon(
                  Icons.ads_click_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Advertising Preferences'),
                subtitle: Text(ConsentService.instance.getConsentChoiceDisplayText()),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: _showAdPreferencesDialog,
              ),
            ),

            const SizedBox(height: 24),

            // App Information Section
            Text(
              'App Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('About This App'),
                    subtitle: const Text('Explore US government departments and agencies with AI-powered insights'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.star_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Features'),
                    subtitle: const Text('Department browsing, AI summaries, comparisons, and favorites'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.update,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Version'),
                    subtitle: Text(_appVersion),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.warning_amber_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: const Text('Disclaimer'),
                    subtitle: const Text('This app doesn\'t represent a government entity.'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Footer
            Center(
              child: Text(
                'Thank you for using our app!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }
}