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

class _TaskFinderScreenState extends State<TaskFinderScreen> {
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

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.initialQuery?.trim() ?? '';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DepartmentProvider>();
    final orderedMatches = _orderedMatches();

    return Scaffold(
      appBar: AppBar(
        title: const Text('I Need Help With...'),
      ),
      body: provider.isLoading && provider.allDepartments.isEmpty ||
              _isPreparingData
          ? _buildLoadingState(theme)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchCard(context, provider),
                  const SizedBox(height: 20),
                  if (_statusMessage != null) ...[
                    _buildStatusBanner(context),
                    const SizedBox(height: 16),
                  ],
                  if (_submittedQuery == null)
                    _buildIntroState(context, provider)
                  else if (orderedMatches.isEmpty)
                    _buildEmptyState(context, provider)
                  else
                    _buildResultsState(context, provider, orderedMatches),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading departments and services...',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(
    BuildContext context,
    DepartmentProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final promptChips = provider.taskFinderPromptChips;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.88),
            colorScheme.secondary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Describe your task in plain English',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Examples: "renew my passport", "apply for food assistance", or "student aid for college".',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              decoration: InputDecoration(
                hintText: 'What do you need help with?',
                prefixIcon: const Icon(Icons.search),
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
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'Search',
                          onPressed: _submitSearch,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ],
                    );
                  },
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: promptChips
                  .map(
                    (chip) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildSearchPromptChip(
                        context,
                        label: chip,
                        onPressed: () {
                          _queryController.text = chip;
                          _submitSearch(overrideQuery: chip);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroState(
    BuildContext context,
    DepartmentProvider provider,
  ) {
    final suggestions = [
      'I need food assistance',
      'I want to apply for student aid',
      'My veterans benefits claim is delayed',
      'I need directions to the nearest office',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Try one of these',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...suggestions.map(
          (suggestion) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.bolt),
                title: Text(suggestion),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _queryController.text = suggestion;
                  _submitSearch(overrideQuery: suggestion);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = _statusIsWarning
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;
    final foregroundColor = _statusIsWarning
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _statusIsWarning ? Icons.warning_amber_rounded : Icons.auto_awesome,
            color: foregroundColor,
          ),
          const SizedBox(width: 10),
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

  Widget _buildEmptyState(
    BuildContext context,
    DepartmentProvider provider,
  ) {
    final reason = _result?.reason ??
        'I could not find a matching department for that request.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No strong match yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _showCategoryPicker(context),
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Browse Categories'),
              ),
            ],
          ),
        ),
        if ((_result?.clarifyingQuestion ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildClarifyingCard(context),
        ],
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: provider.taskFinderPromptChips
                .map(
                  (chip) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () {
                        _queryController.text = chip;
                        _submitSearch(overrideQuery: chip);
                      },
                      child: Text(chip),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsState(
    BuildContext context,
    DepartmentProvider provider,
    List<TaskDepartmentMatch> orderedMatches,
  ) {
    final primaryMatch = orderedMatches.first;
    final alternateMatches = orderedMatches.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isAiRefining)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Showing local keyword matches while AI refines the best answer...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
            ),
          ),
        Text(
          'Best match',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _buildMatchCard(
          context,
          provider,
          primaryMatch,
          position: 1,
          isPrimary: true,
        ),
        const SizedBox(height: 18),
        Text(
          'Why this matches',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        AiSummaryCard(
          summary: _result?.reason,
          isLoading: false,
          onGenerate: _retryAiRefinement,
          onCopy: (text) => _copyText(context, text),
          emptyStateText:
              'Tap below to ask AI why this department matches your task.',
          generateButtonLabel: 'Ask AI',
        ),
        const SizedBox(height: 18),
        _buildNextStepsCard(context),
        if ((_result?.clarifyingQuestion ?? '').isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildClarifyingCard(context),
        ],
        if (alternateMatches.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Alternate matches',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    DepartmentProvider provider,
    TaskDepartmentMatch match, {
    required int position,
    bool isPrimary = false,
  }) {
    final department = match.department;
    final colors = CategoryUtils.getGradient(department.category);
    final accentColor = _resolveReadableAccentColor(context, colors.first);
    final isFavorite = provider.isFavorite(department.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.first.withValues(alpha: isPrimary ? 0.16 : 0.1),
            colors.last.withValues(alpha: isPrimary ? 0.12 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  CategoryUtils.getIcon(department.category),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        position == 1 ? 'Primary office' : 'Backup option',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      department.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      department.category.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.72),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            department.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
          if (match.matchedTokens.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: match.matchedTokens
                  .take(4)
                  .map(
                    (token) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        token,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildActionButtons(
              context,
              provider,
              department,
              position: position,
              isFavorite: isFavorite,
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
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open details'),
      ),
    ];

    if (department.contactInfo.phone.trim().isNotEmpty) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _openPhone(department, position),
          icon: const Icon(Icons.call),
          label: const Text('Call'),
        ),
      );
    }

    if (department.contactInfo.website.trim().isNotEmpty) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _openWebsite(department, position),
          icon: const Icon(Icons.language),
          label: const Text('Website'),
        ),
      );
    }

    if (_hasDirections(department)) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _openDirections(department, position),
          icon: const Icon(Icons.directions),
          label: const Text('Directions'),
        ),
      );
    }

    buttons.add(
      OutlinedButton.icon(
        onPressed: () {
          provider.toggleFavorite(department.id);
          _trackResultTap(
            departmentId: department.id,
            position: position,
            actionType: 'save',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFavorite ? 'Removed from saved items' : 'Saved to favorites',
              ),
            ),
          );
        },
        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
        label: Text(isFavorite ? 'Saved' : 'Save'),
      ),
    );

    return buttons;
  }

  Widget _buildSearchPromptChip(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextStepsCard(BuildContext context) {
    final nextSteps = _result?.nextSteps ?? const <String>[];
    if (nextSteps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Best next steps',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...nextSteps.take(3).map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.45,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildClarifyingCard(BuildContext context) {
    final question = _result?.clarifyingQuestion;
    if (question == null || question.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Need one more detail',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _clarifyController,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _answerClarifyingQuestion(),
            decoration: InputDecoration(
              hintText: 'Type a short answer',
              fillColor: Theme.of(context).colorScheme.surface,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _answerClarifyingQuestion,
            icon: const Icon(Icons.send),
            label: const Text('Refine results'),
          ),
        ],
      ),
    );
  }

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
      const SnackBar(
        content: Text('Unable to open that action right now.'),
      ),
    );
  }

  Future<void> _showCategoryPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.builder(
            itemCount: DepartmentCategory.values.length,
            itemBuilder: (context, index) {
              final category = DepartmentCategory.values[index];
              return ListTile(
                leading: Icon(CategoryUtils.getIcon(category)),
                title: Text(category.displayName),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryScreen(category: category),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
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
