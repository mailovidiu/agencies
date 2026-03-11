import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/consent_service.dart';
import '../services/notification_service.dart';
import '../models/department.dart';
import '../ads/ad_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _appVersion = 'Loading...';
  bool _notificationsEnabled = true;
  Map<DepartmentCategory, bool> _categorySubscriptions = {};
  bool _loadingNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    final service = NotificationService();
    final enabled = await service.areNotificationsEnabled();
    final subs = await service.getAllCategorySubscriptions();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _categorySubscriptions = subs;
        _loadingNotifications = false;
      });
    }
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

  Future<void> _handleAdPreferencesTap() async {
    final consentService = ConsentService.instance;
    await consentService.waitForInitialization();

    if (!consentService.isPrivacyOptionsRequired) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Google privacy options are not required for this device or region right now.',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      return;
    }

    await consentService.showPrivacyOptionsForm();
    await AdManager().syncConsentState();

    if (!mounted) return;

    setState(() {});

    final errorMessage = consentService.lastErrorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage == null
              ? 'Advertising privacy options updated.'
              : 'Could not update advertising privacy options: $errorMessage',
        ),
        backgroundColor: errorMessage == null
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
    );
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your guide to government agencies',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                      await _launchUrl(
                          'https://trendmobilesites.com/terms-apps/gov_agency/privacy.html');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not open privacy policy: \$e'),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
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
                      await _launchUrl(
                          'https://trendmobilesites.com/terms-apps/gov_agency/terms.html');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Could not open terms of service: \$e'),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
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
                child: ListenableBuilder(
                  listenable: ConsentService.instance,
                  builder: (context, child) {
                    final consentService = ConsentService.instance;
                    return ListTile(
                      leading: Icon(
                        Icons.ads_click_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Advertising Privacy'),
                      subtitle:
                          Text(consentService.getConsentChoiceDisplayText()),
                      trailing: Icon(
                        consentService.isPrivacyOptionsRequired
                            ? Icons.arrow_forward_ios
                            : Icons.info_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onTap: _handleAdPreferencesTap,
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Notification Preferences Section
              Text(
                'Notification Preferences',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        Icons.notifications_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Push Notifications'),
                      subtitle: Text(
                        _notificationsEnabled
                            ? 'Receiving department update alerts'
                            : 'Notifications are disabled',
                      ),
                      value: _notificationsEnabled,
                      onChanged: (value) async {
                        final primaryColor =
                            Theme.of(context).colorScheme.primary;
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        await NotificationService()
                            .setNotificationsEnabled(value);
                        if (!mounted) return;
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Notifications enabled'
                                  : 'Notifications disabled',
                            ),
                            backgroundColor: primaryColor,
                          ),
                        );
                      },
                    ),
                    if (_notificationsEnabled && !_loadingNotifications) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Subscribe to categories',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ),
                      ),
                      ...DepartmentCategory.values.map((category) {
                        final subscribed =
                            _categorySubscriptions[category] ?? true;
                        return SwitchListTile(
                          title: Text(
                            category.displayName,
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: subscribed,
                          dense: true,
                          onChanged: (value) async {
                            await NotificationService()
                                .setCategorySubscription(category, value);
                            setState(() {
                              _categorySubscriptions[category] = value;
                            });
                          },
                        );
                      }),
                    ],
                  ],
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
                      subtitle: const Text(
                          'Explore US government departments and agencies with AI-powered insights'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.star_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Features'),
                      subtitle: const Text(
                          'Department browsing, AI summaries, comparisons, and favorites'),
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
                      subtitle: const Text(
                          'This app doesn\'t represent a government entity.'),
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
