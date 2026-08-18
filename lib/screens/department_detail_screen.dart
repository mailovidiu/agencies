import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/department.dart';
import '../providers/department_provider.dart';
import '../openai/openai_config.dart';
import '../ads/ad_manager.dart';
import '../widgets/ai_summary_card.dart';

/// Detailed view screen for a government department or agency
class DepartmentDetailScreen extends StatefulWidget {
  final Department department;

  const DepartmentDetailScreen({
    super.key,
    required this.department,
  });

  @override
  State<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<DepartmentDetailScreen> {
  static const double _expandedHeaderContentHeight = 96.0;
  static const double _collapsedHeaderContentHeight = 56.0;

  String? _aiSummary;
  bool _isLoadingSummary = false;
  final TextEditingController _questionController = TextEditingController();
  final List<Map<String, String>> _qaHistory = [];
  bool _isLoadingAnswer = false;

  @override
  void initState() {
    super.initState();
    // Show interstitial ad when entering detail screen (with frequency control)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AdManager().showInterstitialAd();
      }
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access theme data
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final topPadding = MediaQuery.paddingOf(context).top;
    final expandedAppBarHeight = topPadding + _expandedHeaderContentHeight;
    final collapsedAppBarHeight = topPadding + _collapsedHeaderContentHeight;
    final headerCollapseRange = expandedAppBarHeight - collapsedAppBarHeight;

    return Consumer<DepartmentProvider>(
      builder: (context, provider, child) {
        final isFavorite = provider.isFavorite(widget.department.id);

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: CustomScrollView(
            slivers: [
              // Compact Header
              SliverAppBar(
                expandedHeight: expandedAppBarHeight,
                collapsedHeight: collapsedAppBarHeight,
                toolbarHeight: _collapsedHeaderContentHeight,
                floating: false,
                pinned: true,
                backgroundColor: colorScheme.primary,
                scrolledUnderElevation: 0,
                elevation: 0,
                titleSpacing: 0,
                leadingWidth: 56,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final expansion = headerCollapseRange == 0
                        ? 0.0
                        : ((constraints.maxHeight - collapsedAppBarHeight) /
                                headerCollapseRange)
                            .clamp(0.0, 1.0);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary,
                                colorScheme.tertiary,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: -14,
                          right: -14,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -12,
                          left: -10,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        if (expansion > 0.0)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 8,
                            child: Opacity(
                              opacity: expansion,
                              child: Transform.translate(
                                offset: Offset(0, 8 * (1 - expansion)),
                                child: _buildExpandedHeaderRow(context),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.department.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.0,
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      onPressed: () {
                        provider.toggleFavorite(widget.department.id);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black26,
                      ),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey(isFavorite),
                          color: isFavorite ? Colors.redAccent : Colors.white,
                        ),
                      ),
                      tooltip: isFavorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                    ),
                  ),
                ],
              ),

              // Body Content
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  transform: Matrix4.translationValues(
                      0, -4, 0), // Slight overlap with header
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // About Section
                        _buildSectionHeader(
                            context, 'About', Icons.info_outline),
                        const SizedBox(height: 12),
                        Text(
                          widget.department.description,
                          style: textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        if (widget.department.tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.department.tags
                                .map((tag) => _buildTag(context, tag))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 32),

                        // AI Summary Section - Premium Feature
                        AiSummaryCard(
                          summary: _aiSummary,
                          isLoading: _isLoadingSummary,
                          onGenerate: _generateSummary,
                          onCopy: (text) => _copyToClipboard(context, text),
                        ),
                        const SizedBox(height: 32),

                        // Contact Information
                        _buildSectionHeader(context, 'Contact Information',
                            Icons.contact_phone_outlined),
                        const SizedBox(height: 16),
                        _buildContactSection(context),
                        const SizedBox(height: 32),

                        // Services
                        if (widget.department.services.isNotEmpty) ...[
                          _buildSectionHeader(context, 'Services & Programs',
                              Icons.supervised_user_circle_outlined),
                          const SizedBox(height: 16),
                          _buildServicesSection(context),
                          const SizedBox(height: 32),
                        ],

                        // Location
                        if (widget.department.location != null) ...[
                          _buildSectionHeader(
                              context, 'Location', Icons.location_on_outlined),
                          const SizedBox(height: 16),
                          _buildLocationSection(context),
                          const SizedBox(height: 32),
                        ],

                        // Q&A Assistant
                        _buildQASection(context),

                        // Office Hours
                        if (widget.department.officeHours != null) ...[
                          const SizedBox(height: 32),
                          _buildSectionHeader(context, 'Office Hours',
                              Icons.access_time_outlined),
                          const SizedBox(height: 16),
                          _buildOfficeHoursSection(context),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ],
    );
  }

  Widget _buildExpandedHeaderRow(BuildContext context) {
    return Row(
      children: [
        Hero(
          tag: 'dept_icon_${widget.department.id}',
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
            child: Icon(
              _getCategoryIcon(widget.department.category),
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
        if (widget.department.isPopular) ...[
          const SizedBox(width: 8),
          _buildHeaderStatusChip(
            context,
            label: 'Popular',
            icon: Icons.trending_up,
            background: Colors.orange.shade100,
            foreground: Colors.orange.shade900,
            border: Colors.orange.shade200,
          ),
        ],
        const SizedBox(width: 8),
        _buildHeaderStatusChip(
          context,
          label: widget.department.isActive ? 'Active' : 'Inactive',
          icon: widget.department.isActive ? Icons.check_circle : Icons.cancel,
          background: widget.department.isActive
              ? Colors.green.shade100
              : Colors.grey.shade200,
          foreground: widget.department.isActive
              ? Colors.green.shade900
              : Colors.grey.shade700,
          border: widget.department.isActive
              ? Colors.green.shade200
              : Colors.grey.shade300,
        ),
      ],
    );
  }

  Widget _buildHeaderStatusChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Text(
        tag,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Column(
      children: [
        _buildContactTile(
          context,
          Icons.phone_outlined,
          'Phone',
          widget.department.contactInfo.phone,
          onTap: () => _launchPhone(widget.department.contactInfo.phone),
          isPrimary: true,
        ),
        const SizedBox(height: 12),
        _buildContactTile(
          context,
          Icons.email_outlined,
          'Email',
          widget.department.contactInfo.email,
          onTap: () => _launchEmail(widget.department.contactInfo.email),
        ),
        const SizedBox(height: 12),
        _buildContactTile(
          context,
          Icons.language,
          'Website',
          _extractDomain(widget.department.contactInfo.website),
          onTap: () => _launchWebsite(widget.department.contactInfo.website),
        ),
        if (widget.department.contactInfo.fax != null) ...[
          const SizedBox(height: 12),
          _buildContactTile(
            context,
            Icons.fax_outlined,
            'Fax',
            widget.department.contactInfo.fax!,
          ),
        ],
      ],
    );
  }

  Widget _buildContactTile(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _copyToClipboard(context, value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: isPrimary
              ? Border.all(color: colorScheme.primary.withValues(alpha: 0.2))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPrimary ? colorScheme.primary : colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: isPrimary
                    ? [
                        BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isPrimary
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isPrimary
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: widget.department.services.asMap().entries.map((entry) {
          final isLast = entry.key == widget.department.services.length - 1;
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle,
                    size: 20, color: Colors.green),
                title: Text(entry.value),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOfficeHoursSection(BuildContext context) {
    final theme = Theme.of(context);
    final hours = widget.department.officeHours!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hours.isOpen24x7)
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Open 24/7',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            )
          else
            ...hours.weeklyHours.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key.substring(0, 1).toUpperCase() +
                            entry.key.substring(1),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        entry.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )),
          if (hours.specialInstructions != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hours.specialInstructions!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    final theme = Theme.of(context);
    final location = widget.department.location!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Column(
          children: [
            // Using an image placeholder or map snapshot could be cool here
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              ),
              child: Center(
                child: Icon(
                  Icons.map_outlined,
                  size: 40,
                  color: theme.colorScheme.onTertiaryContainer
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          location.formattedAddress,
                          style:
                              theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _launchMaps(location.formattedAddress),
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQASection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            context, 'Ask AI Assistant', Icons.chat_bubble_outline),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Chat Display Area
              if (_qaHistory.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.forum_outlined,
                          size: 40,
                          color: colorScheme.secondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'Have a question about this department?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Ask our AI assistant for instant help',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    ..._qaHistory.reversed.take(2).map((qa) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(4),
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    qa['question']!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onPrimary),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    qa['answer']!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            colorScheme.onSecondaryContainer),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (_qaHistory.length > 2)
                      TextButton(
                        onPressed: () => _showFullQAHistory(context),
                        child: Text('View all ${_qaHistory.length} messages'),
                      ),
                    const Divider(height: 32),
                  ],
                ),

              const SizedBox(height: 12),

              // Input Area
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        hintText: 'Type your question...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (_) => _askQuestion(),
                      enabled: !_isLoadingAnswer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isLoadingAnswer ? null : _askQuestion,
                      color: colorScheme.onPrimary,
                      icon: _isLoadingAnswer
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary),
                              ))
                          : const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper Methods (Logic kept from original file)

  Future<void> _generateSummary() async {
    if (_isLoadingSummary) return;

    AdManager().showInterstitialAd();

    setState(() {
      _isLoadingSummary = true;
      _aiSummary = null;
    });

    try {
      final departmentData = {
        'name': widget.department.name,
        'description': widget.department.description,
        'category': widget.department.category.displayName,
        'website': widget.department.contactInfo.website,
        'phone': widget.department.contactInfo.phone,
        'address': widget.department.contactInfo.address,
        'services': widget.department.services,
      };

      final summary =
          await OpenAIService.generateDepartmentSummary(departmentData);

      setState(() {
        _aiSummary = summary;
        _isLoadingSummary = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSummary = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate summary: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isLoadingAnswer) return;

    AdManager().showInterstitialAd();

    setState(() {
      _isLoadingAnswer = true;
    });

    try {
      final departmentData = {
        'name': widget.department.name,
        'description': widget.department.description,
        'category': widget.department.category.displayName,
        'website': widget.department.contactInfo.website,
        'phone': widget.department.contactInfo.phone,
        'address': widget.department.contactInfo.address,
        'services': widget.department.services,
      };

      final answer = await OpenAIService.answerContextualQuestion(
        question: question,
        departmentData: departmentData,
      );

      setState(() {
        _qaHistory.add({
          'question': question,
          'answer': answer,
        });
        _questionController.clear();
        _isLoadingAnswer = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAnswer = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get answer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFullQAHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                // Drag handle
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'Q&A History',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _qaHistory.length,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    final qa = _qaHistory.reversed.toList()[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: const Icon(Icons.person, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                child: Text(qa['question']!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 30), // Indent for answer
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                child: Text(qa['answer']!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: Icon(Icons.auto_awesome,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(DepartmentCategory category) {
    switch (category) {
      case DepartmentCategory.health:
        return Icons.health_and_safety;
      case DepartmentCategory.education:
        return Icons.school;
      case DepartmentCategory.transportation:
        return Icons.directions_car;
      case DepartmentCategory.finance:
        return Icons.attach_money;
      case DepartmentCategory.security:
        return Icons.security;
      case DepartmentCategory.environment:
        return Icons.eco;
      case DepartmentCategory.agriculture:
        return Icons.grass;
      case DepartmentCategory.socialServices:
        return Icons.people;
      case DepartmentCategory.defense:
        return Icons.shield;
      case DepartmentCategory.justice:
        return Icons.gavel;
      case DepartmentCategory.commerce:
        return Icons.business;
      case DepartmentCategory.labor:
        return Icons.work;
      case DepartmentCategory.energy:
        return Icons.bolt;
      case DepartmentCategory.housing:
        return Icons.home;
      case DepartmentCategory.veterans:
        return Icons.military_tech;
      case DepartmentCategory.other:
        return Icons.category;
    }
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    } catch (e) {
      return url;
    }
  }

  void _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchWebsite(String website) async {
    final uri =
        Uri.parse(website.startsWith('http') ? website : 'https://$website');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchMaps(String address) async {
    final uri = Uri.parse(
        'https://maps.google.com/search?q=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
