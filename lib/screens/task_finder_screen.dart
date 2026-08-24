import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/department.dart';
import '../models/task_finder.dart';
import '../providers/department_provider.dart';
import '../services/firebase_analytics_service.dart';
import '../utils/category_utils.dart';
import '../widgets/ai_summary_card.dart';
import 'category_screen.dart';
import 'department_detail_screen.dart';

class TaskFinderScreen extends StatefulWidget {
  final String? initialQuery;

  const TaskFinderScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<TaskFinderScreen> createState() => _TaskFinderScreenState();
}

class _TaskFinderScreenState extends State<TaskFinderScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _clarifyController = TextEditingController();
  final FirebaseAnalyticsService _analyticsService = FirebaseAnalyticsService();

  List<TaskDepartmentMatch> _matches = const [];
  TaskFinderResult? _result;
  String? _submittedQuery;
  String? _statusMessage;
  bool _statusIsWarning = false;
  bool _isPreparingData = false;
  bool _isAiRefining = false;
  int _activeSearchId = 0;
  String? _lastClarifySignature;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.initialQuery?.trim() ?? '';

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<DepartmentProvider>();
      if (provider.allDepartments.isEmpty && !provider.isLoading) {
        setState(() {
          _isPreparingData = true;
        });
        await provider.initialize();
        if (!mounted) {
          return;
        }
        setState(() {
          _isPreparingData = false;
        });
      }

      final initialQuery = widget.initialQuery?.trim();
      if (initialQuery != null && initialQuery.isNotEmpty && mounted) {
        await _submitSearch(overrideQuery: initialQuery);
      }
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _clarifyController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<DepartmentProvider>();
    final orderedMatches = _orderedMatches();

    return Scaffold(
      body: provider.isLoading && provider.allDepartments.isEmpty ||
              _isPreparingData
          ? _buildLoadingState(theme, colorScheme)
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(context, colorScheme),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPromptChips(context, provider),
                            const SizedBox(height: 24),
                            if (_statusMessage != null) ...[
                              _buildStatusBanner(context, colorScheme),
                              const SizedBox(height: 20),
                            ],
                            if (_submittedQuery == null)
                              _buildIntroState(context, provider, colorScheme)
                            else if (orderedMatches.isEmpty)
                              _buildEmptyState(context, provider, colorScheme)
                            else
                              _buildResultsState(
                                context,
                                provider,
                                orderedMatches,
                                colorScheme,
                              ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Sliver App Bar ──────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 170,
      floating: false,
      pinned: true,
      stretch: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _buildSearchField(context, colorScheme, inAppBar: true),
        ),
      ),
      title: Text(
        'I Need Help With...',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.primary.withValues(alpha: 0.85),
                colorScheme.tertiary.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Icon(
                  Icons.support_agent,
                  size: 180,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Icon(
                  Icons.search,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loading State ───────────────────────────────────────────────────

  Widget _buildLoadingState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Preparing your assistant...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading departments and services',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Field ────────────────────────────────────────────────────

  Widget _buildSearchField(
    BuildContext context,
    ColorScheme colorScheme, {
    bool inAppBar = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inAppBar
            ? Colors.white
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: inAppBar ? 0.12 : 0.06),
            blurRadius: inAppBar ? 12 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _queryController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submitSearch(),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: inAppBar ? Colors.black87 : null,
            ),
        decoration: InputDecoration(
          hintText: 'Describe what you need help with...',
          hintStyle: TextStyle(
            color: inAppBar
                ? Colors.black38
                : colorScheme.onSurface.withValues(alpha: 0.45),
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: inAppBar ? colorScheme.primary : colorScheme.primary,
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _queryController,
            builder: (context, value, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _queryController.clear();
                        setState(() {
                          _submittedQuery = null;
                          _matches = const [];
                          _result = null;
                          _statusMessage = null;
                          _statusIsWarning = false;
                        });
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: inAppBar
                            ? Colors.black38
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 18,
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      tooltip: 'Search',
                      onPressed: _submitSearch,
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // ── Prompt Chips ────────────────────────────────────────────────────

  Widget _buildPromptChips(
    BuildContext context,
    DepartmentProvider provider,
  ) {
    final chips = provider.taskFinderPromptChips;
    if (chips.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return ActionChip(
            label: Text(
              chip,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            backgroundColor:
                colorScheme.secondaryContainer.withValues(alpha: 0.6),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onPressed: () {
              _queryController.text = chip;
              _submitSearch(overrideQuery: chip);
            },
          );
        },
      ),
    );
  }

  // ── Intro State ─────────────────────────────────────────────────────

  Widget _buildIntroState(
    BuildContext context,
    DepartmentProvider provider,
    ColorScheme colorScheme,
  ) {
    final suggestions = [
      (
        'I need food assistance',
        Icons.restaurant_rounded,
        [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
      ),
      (
        'I want to apply for student aid',
        Icons.school_rounded,
        [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      ),
      (
        'My veterans benefits claim is delayed',
        Icons.military_tech_rounded,
        [const Color(0xFF667eea), const Color(0xFF764ba2)],
      ),
      (
        'I need directions to the nearest office',
        Icons.location_on_rounded,
        [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Try one of these',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...suggestions.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final (text, icon, gradientColors) = entry.value;

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + index * 100),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      _queryController.text = text;
                      _submitSearch(overrideQuery: text);
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                text,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Status Banner ───────────────────────────────────────────────────

  Widget _buildStatusBanner(BuildContext context, ColorScheme colorScheme) {
    final backgroundColor = _statusIsWarning
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer.withValues(alpha: 0.7);
    final foregroundColor = _statusIsWarning
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;
    final iconData = _statusIsWarning
        ? Icons.warning_amber_rounded
        : Icons.auto_awesome_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: foregroundColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: foregroundColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────

  Widget _buildEmptyState(
    BuildContext context,
    DepartmentProvider provider,
    ColorScheme colorScheme,
  ) {
    final reason = _result?.reason ??
        'I could not find a matching department for that request.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No strong match yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showCategoryPicker(context),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Browse Categories'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
        if ((_result?.clarifyingQuestion ?? '').isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildClarifyingCard(context, colorScheme),
        ],
        const SizedBox(height: 16),
        _buildScrollableChipRow(
          provider.taskFinderPromptChips
              .map(
                (chip) => OutlinedButton(
                  onPressed: () {
                    _queryController.text = chip;
                    _submitSearch(overrideQuery: chip);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(chip),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildScrollableChipRow(List<Widget> chips) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < chips.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              chips[index],
            ],
          ],
        ),
      ),
    );
  }

  // ── Results State ───────────────────────────────────────────────────

  Widget _buildResultsState(
    BuildContext context,
    DepartmentProvider provider,
    List<TaskDepartmentMatch> orderedMatches,
    ColorScheme colorScheme,
  ) {
    final primaryMatch = orderedMatches.first;
    final alternateMatches = orderedMatches.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isAiRefining)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'AI is refining results...',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor:
                          colorScheme.primary.withValues(alpha: 0.15),
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Section header
        _buildSectionHeader(
          context,
          icon: Icons.star_rounded,
          title: 'Best match',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),

        // Primary match
        _buildMatchCard(
          context,
          provider,
          primaryMatch,
          position: 1,
          isPrimary: true,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 20),

        // AI explanation
        _buildSectionHeader(
          context,
          icon: Icons.auto_awesome_rounded,
          title: 'Why this matches',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        AiSummaryCard(
          summary: _result?.reason,
          isLoading: false,
          onGenerate: _retryAiRefinement,
          onCopy: (text) => _copyText(context, text),
          emptyStateText:
              'Tap below to ask AI why this department matches your task.',
          generateButtonLabel: 'Ask AI',
        ),
        const SizedBox(height: 20),

        // Next steps
        _buildNextStepsCard(context, colorScheme),

        // Clarifying question
        if ((_result?.clarifyingQuestion ?? '').isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildClarifyingCard(context, colorScheme),
        ],

        // Alternate matches
        if (alternateMatches.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            icon: Icons.swap_horiz_rounded,
            title: 'Other options',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
          ...alternateMatches.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMatchCard(
                    context,
                    provider,
                    entry.value,
                    position: entry.key + 2,
                    colorScheme: colorScheme,
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  // ── Match Card ──────────────────────────────────────────────────────

  Widget _buildMatchCard(
    BuildContext context,
    DepartmentProvider provider,
    TaskDepartmentMatch match, {
    required int position,
    bool isPrimary = false,
    required ColorScheme colorScheme,
  }) {
    final department = match.department;
    final colors = CategoryUtils.getGradient(department.category);
    final accentColor = _resolveReadableAccentColor(context, colors.first);
    final isFavorite = provider.isFavorite(department.id);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPrimary
              ? accentColor.withValues(alpha: 0.25)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isPrimary ? 1.5 : 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient accent bar at top
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: colors.first.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        CategoryUtils.getIcon(department.category),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Position badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPrimary
                                  ? accentColor.withValues(alpha: 0.12)
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              position == 1 ? 'Top result' : 'Alternative',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: isPrimary
                                        ? accentColor
                                        : colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Department name
                          Text(
                            department.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            department.category.displayName,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description
                Text(
                  department.description,
                  maxLines: isPrimary ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                ),

                // Matched tokens
                if (match.matchedTokens.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: match.matchedTokens
                        .take(4)
                        .map(
                          (token) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              token,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                // Action buttons
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildActionButtons(
                    context,
                    provider,
                    department,
                    position: position,
                    isFavorite: isFavorite,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    DepartmentProvider provider,
    Department department, {
    required int position,
    required bool isFavorite,
    required ColorScheme colorScheme,
  }) {
    final buttons = <Widget>[
      FilledButton.icon(
        onPressed: () {
          _trackResultTap(
            departmentId: department.id,
            position: position,
            actionType: 'open',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DepartmentDetailScreen(department: department),
            ),
          );
        },
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: const Text('View details'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ];

    if (department.contactInfo.phone.trim().isNotEmpty) {
      buttons.add(
        _buildCompactActionButton(
          icon: Icons.call_rounded,
          label: 'Call',
          onPressed: () => _openPhone(department, position),
          colorScheme: colorScheme,
        ),
      );
    }

    if (department.contactInfo.website.trim().isNotEmpty) {
      buttons.add(
        _buildCompactActionButton(
          icon: Icons.language_rounded,
          label: 'Website',
          onPressed: () => _openWebsite(department, position),
          colorScheme: colorScheme,
        ),
      );
    }

    if (_hasDirections(department)) {
      buttons.add(
        _buildCompactActionButton(
          icon: Icons.directions_rounded,
          label: 'Directions',
          onPressed: () => _openDirections(department, position),
          colorScheme: colorScheme,
        ),
      );
    }

    buttons.add(
      _buildCompactActionButton(
        icon:
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        label: isFavorite ? 'Saved' : 'Save',
        onPressed: () {
          provider.toggleFavorite(department.id);
          _trackResultTap(
            departmentId: department.id,
            position: position,
            actionType: 'save',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: Text(
                isFavorite ? 'Removed from saved items' : 'Saved to favorites',
              ),
            ),
          );
        },
        colorScheme: colorScheme,
        isActive: isFavorite,
      ),
    );

    return buttons;
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    bool isActive = false,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: isActive ? colorScheme.primary : colorScheme.onSurface,
        side: BorderSide(
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }

  // ── Next Steps Card ─────────────────────────────────────────────────

  Widget _buildNextStepsCard(BuildContext context, ColorScheme colorScheme) {
    final nextSteps = _result?.nextSteps ?? const <String>[];
    if (nextSteps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          icon: Icons.checklist_rounded,
          title: 'Recommended next steps',
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: nextSteps
                .take(3)
                .toList()
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key < nextSteps.take(3).length - 1 ? 14 : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.tertiary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entry.value,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    height: 1.5,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Clarifying Card ─────────────────────────────────────────────────

  Widget _buildClarifyingCard(BuildContext context, ColorScheme colorScheme) {
    final question = _result?.clarifyingQuestion;
    if (question == null || question.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      colorScheme.onSecondaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: colorScheme.onSecondaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Can you clarify?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      colorScheme.onSecondaryContainer.withValues(alpha: 0.85),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _clarifyController,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _answerClarifyingQuestion(),
            decoration: InputDecoration(
              hintText: 'Type a short answer...',
              fillColor: colorScheme.surface,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _answerClarifyingQuestion,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Refine results'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Business Logic (unchanged) ──────────────────────────────────────

  Future<void> _submitSearch({String? overrideQuery}) async {
    final query = (overrideQuery ?? _queryController.text).trim();
    FocusManager.instance.primaryFocus?.unfocus();

    if (query.isEmpty) {
      setState(() {
        _submittedQuery = null;
        _matches = const [];
        _result = null;
        _statusMessage = null;
        _statusIsWarning = false;
      });
      return;
    }

    final provider = context.read<DepartmentProvider>();
    final searchId = ++_activeSearchId;

    if (provider.allDepartments.isEmpty && !provider.isLoading) {
      setState(() {
        _isPreparingData = true;
      });
      await provider.initialize();
      if (!mounted || searchId != _activeSearchId) {
        return;
      }
      setState(() {
        _isPreparingData = false;
      });
    }

    final stopwatch = Stopwatch()..start();
    final localResponse = provider.findDepartmentsForTask(query, limit: 6);

    if (!mounted || searchId != _activeSearchId) {
      return;
    }

    setState(() {
      _submittedQuery = query;
      _matches = localResponse.matches;
      _result = localResponse.result;
      _statusMessage = localResponse.matches.isEmpty
          ? null
          : 'AI is refining the best match. Local keyword results are shown now.';
      _statusIsWarning = false;
      _isAiRefining = localResponse.matches.isNotEmpty;
      _clarifyController.clear();
    });

    _maybeLogClarifyingQuestion(
        query, localResponse.result?.clarifyingQuestion);

    if (localResponse.matches.isEmpty) {
      stopwatch.stop();
      await _analyticsService.logEvent(
        name: 'task_no_result',
        parameters: {'query': query},
      );
      await _logTaskSearch(
        query: query,
        resultCount: 0,
        hadAiRefinement: false,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
      return;
    }

    unawaited(
      _runAiRefinement(
        searchId: searchId,
        query: query,
        localMatches: localResponse.matches,
        stopwatch: stopwatch,
        trackSearchAnalytics: true,
      ),
    );
  }

  Future<void> _retryAiRefinement() async {
    final query = _submittedQuery;
    if (query == null || _matches.isEmpty) {
      return;
    }

    final searchId = ++_activeSearchId;
    setState(() {
      _isAiRefining = true;
      _statusMessage = 'Refreshing the AI explanation for this task...';
      _statusIsWarning = false;
    });

    unawaited(
      _runAiRefinement(
        searchId: searchId,
        query: query,
        localMatches: _matches,
        stopwatch: Stopwatch()..start(),
        trackSearchAnalytics: false,
      ),
    );
  }

  Future<void> _runAiRefinement({
    required int searchId,
    required String query,
    required List<TaskDepartmentMatch> localMatches,
    required Stopwatch stopwatch,
    required bool trackSearchAnalytics,
  }) async {
    var hadAiRefinement = false;

    try {
      final aiResult =
          await context.read<DepartmentProvider>().refineTaskSearchWithAi(
                query: query,
                matches: localMatches,
              );
      hadAiRefinement = aiResult != null;

      if (!mounted || searchId != _activeSearchId) {
        return;
      }

      setState(() {
        _result = aiResult ?? _result;
        _statusMessage = null;
        _statusIsWarning = false;
        _isAiRefining = false;
      });

      _maybeLogClarifyingQuestion(query, aiResult?.clarifyingQuestion);
    } on TimeoutException {
      if (!mounted || searchId != _activeSearchId) {
        return;
      }

      setState(() {
        _statusMessage = 'AI refinement unavailable, showing keyword matches.';
        _statusIsWarning = true;
        _isAiRefining = false;
      });
    } catch (_) {
      if (!mounted || searchId != _activeSearchId) {
        return;
      }

      setState(() {
        _statusMessage = 'AI refinement unavailable, showing keyword matches.';
        _statusIsWarning = true;
        _isAiRefining = false;
      });
    } finally {
      stopwatch.stop();
      if (trackSearchAnalytics &&
          mounted &&
          searchId == _activeSearchId &&
          _submittedQuery == query) {
        await _logTaskSearch(
          query: query,
          resultCount: _orderedMatches().length,
          hadAiRefinement: hadAiRefinement,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    }
  }

  void _maybeLogClarifyingQuestion(String query, String? question) {
    if (question == null || question.isEmpty) {
      return;
    }

    final signature = '$query|$question';
    if (signature == _lastClarifySignature) {
      return;
    }

    _lastClarifySignature = signature;
    unawaited(
      _analyticsService.logEvent(
        name: 'task_clarify_shown',
        parameters: {
          'query': query,
          'clarifying_question': question,
        },
      ),
    );
  }

  Future<void> _answerClarifyingQuestion() async {
    final answer = _clarifyController.text.trim();
    final query = _submittedQuery;
    if (answer.isEmpty || query == null) {
      return;
    }

    await _analyticsService.logEvent(
      name: 'task_clarify_answered',
      parameters: {
        'query': query,
        'answer': answer,
      },
    );

    final refinedQuery = '$query $answer';
    _queryController.text = refinedQuery;
    await _submitSearch(overrideQuery: refinedQuery);
  }

  Future<void> _logTaskSearch({
    required String query,
    required int resultCount,
    required bool hadAiRefinement,
    required int latencyMs,
  }) {
    return _analyticsService.logEvent(
      name: 'task_search',
      parameters: {
        'query': query,
        'result_count': resultCount,
        'had_ai_refinement': hadAiRefinement,
        'latency_ms': latencyMs,
      },
    );
  }

  void _trackResultTap({
    required String departmentId,
    required int position,
    required String actionType,
  }) {
    unawaited(
      _analyticsService.logEvent(
        name: 'task_result_tap',
        parameters: {
          'department_id': departmentId,
          'position': _positionLabel(position),
          'action_type': actionType,
        },
      ),
    );
  }

  List<TaskDepartmentMatch> _orderedMatches() {
    if (_matches.isEmpty) {
      return const [];
    }

    final matchById = <String, TaskDepartmentMatch>{
      for (final match in _matches) match.department.id: match,
    };
    final orderedMatches = <TaskDepartmentMatch>[];
    final primaryId = _result?.primaryDepartmentId;

    if (primaryId != null) {
      final primaryMatch = matchById.remove(primaryId);
      if (primaryMatch != null) {
        orderedMatches.add(primaryMatch);
      }
    }

    for (final secondaryId in _result?.secondaryDepartmentIds ?? const []) {
      final secondaryMatch = matchById.remove(secondaryId);
      if (secondaryMatch != null) {
        orderedMatches.add(secondaryMatch);
      }
    }

    final remainingMatches = matchById.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    orderedMatches.addAll(remainingMatches);

    return orderedMatches.take(3).toList();
  }

  bool _hasDirections(Department department) {
    return department.location != null ||
        department.contactInfo.address.trim().isNotEmpty;
  }

  Future<void> _openPhone(Department department, int position) async {
    final uri = Uri.parse('tel:${department.contactInfo.phone}');
    await _launchUri(
      uri,
      departmentId: department.id,
      position: position,
      actionType: 'call',
    );
  }

  Future<void> _openWebsite(Department department, int position) async {
    final website = department.contactInfo.website.trim();
    final uri = Uri.parse(
      website.startsWith('http') ? website : 'https://$website',
    );
    await _launchUri(
      uri,
      departmentId: department.id,
      position: position,
      actionType: 'website',
    );
  }

  Future<void> _openDirections(Department department, int position) async {
    final address = department.location?.formattedAddress ??
        department.contactInfo.address.trim();
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?q=${Uri.encodeComponent(address)}',
    );
    await _launchUri(
      uri,
      departmentId: department.id,
      position: position,
      actionType: 'directions',
    );
  }

  Future<void> _launchUri(
    Uri uri, {
    required String departmentId,
    required int position,
    required String actionType,
  }) async {
    if (await canLaunchUrl(uri)) {
      _trackResultTap(
        departmentId: departmentId,
        position: position,
        actionType: actionType,
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: const Text('Unable to open that action right now.'),
      ),
    );
  }

  Future<void> _showCategoryPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text(
                  'Browse by category',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: DepartmentCategory.values.length,
                  itemBuilder: (context, index) {
                    final category = DepartmentCategory.values[index];
                    final gradientColors = CategoryUtils.getGradient(category);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          CategoryUtils.getIcon(category),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        category.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CategoryScreen(category: category),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: const Text('Copied to clipboard'),
      ),
    );
  }

  Color _resolveReadableAccentColor(BuildContext context, Color baseColor) {
    final target = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    final amount =
        Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.45;
    return Color.lerp(baseColor, target, amount) ?? baseColor;
  }

  String _positionLabel(int position) {
    switch (position) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${position}th';
    }
  }
}
