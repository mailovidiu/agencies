import 'dart:async';

import '../models/department.dart';
import '../models/task_finder.dart';
import '../openai/openai_config.dart';
import '../repositories/department_repository.dart';
import '../repositories/firebase_department_repository.dart';
import '../repositories/hybrid_department_repository.dart';

/// Service layer for handling business logic related to departments and agencies
class DepartmentService {
  final DepartmentRepository _repository;
  static const Map<String, double> _taskFieldWeights = {
    'services': 3.0,
    'keywords': 2.0,
    'tags': 1.5,
    'name': 1.0,
    'description': 0.5,
  };
  static const Set<String> _taskStopWords = {
    'a',
    'am',
    'an',
    'and',
    'are',
    'for',
    'help',
    'i',
    'in',
    'is',
    'me',
    'my',
    'need',
    'of',
    'on',
    'the',
    'to',
    'want',
    'with',
  };

  DepartmentService(this._repository);

  /// Get all departments
  Future<List<Department>> getAllDepartments() async {
    try {
      return await _repository.getDepartments();
    } catch (e) {
      throw ServiceException('Failed to fetch departments: $e');
    }
  }

  /// Get departments by category
  Future<List<Department>> getDepartmentsByCategory(
      DepartmentCategory category) async {
    try {
      return await _repository.getDepartmentsByCategory(category);
    } catch (e) {
      throw ServiceException('Failed to fetch departments by category: $e');
    }
  }

  /// Search departments by name or description
  Future<List<Department>> searchDepartments(String query) async {
    try {
      return await _repository.searchDepartments(query);
    } catch (e) {
      throw ServiceException('Failed to search departments: $e');
    }
  }

  TaskFinderSearchResponse findDepartmentsForTask(
    List<Department> departments,
    String query, {
    int limit = 6,
  }) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const TaskFinderSearchResponse(matches: [], result: null);
    }

    final matches = rankDepartmentsForTask(
      departments,
      trimmedQuery,
      limit: limit,
    );

    return TaskFinderSearchResponse(
      matches: matches,
      result: buildLocalTaskFinderResult(trimmedQuery, matches),
    );
  }

  List<TaskDepartmentMatch> rankDepartmentsForTask(
    List<Department> departments,
    String query, {
    int limit = 6,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final queryTokens = _tokenizeTaskQuery(query);
    if (queryTokens.isEmpty) {
      return [];
    }

    final matches = <TaskDepartmentMatch>[];

    for (final department in departments) {
      final matchedTokens = <String>{};
      final fieldScores = <String, double>{};
      var totalScore = 0.0;

      final servicesScore = _scoreTaskField(
        values: department.services,
        queryTokens: queryTokens,
        normalizedQuery: normalizedQuery,
        weight: _taskFieldWeights['services']!,
        matchedTokens: matchedTokens,
      );
      if (servicesScore > 0) {
        fieldScores['services'] = servicesScore;
        totalScore += servicesScore;
      }

      final keywordsScore = _scoreTaskField(
        values: department.keywords,
        queryTokens: queryTokens,
        normalizedQuery: normalizedQuery,
        weight: _taskFieldWeights['keywords']!,
        matchedTokens: matchedTokens,
      );
      if (keywordsScore > 0) {
        fieldScores['keywords'] = keywordsScore;
        totalScore += keywordsScore;
      }

      final tagsScore = _scoreTaskField(
        values: department.tags,
        queryTokens: queryTokens,
        normalizedQuery: normalizedQuery,
        weight: _taskFieldWeights['tags']!,
        matchedTokens: matchedTokens,
      );
      if (tagsScore > 0) {
        fieldScores['tags'] = tagsScore;
        totalScore += tagsScore;
      }

      final nameScore = _scoreTaskField(
        values: [department.name, department.shortName],
        queryTokens: queryTokens,
        normalizedQuery: normalizedQuery,
        weight: _taskFieldWeights['name']!,
        matchedTokens: matchedTokens,
      );
      if (nameScore > 0) {
        fieldScores['name'] = nameScore;
        totalScore += nameScore;
      }

      final descriptionScore = _scoreTaskField(
        values: [department.description],
        queryTokens: queryTokens,
        normalizedQuery: normalizedQuery,
        weight: _taskFieldWeights['description']!,
        matchedTokens: matchedTokens,
      );
      if (descriptionScore > 0) {
        fieldScores['description'] = descriptionScore;
        totalScore += descriptionScore;
      }

      if (totalScore < 0.12) {
        continue;
      }

      matches.add(
        TaskDepartmentMatch(
          department: department,
          score: totalScore,
          fieldScores: fieldScores,
          matchedTokens: matchedTokens.toList()..sort(),
        ),
      );
    }

    matches.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return a.department.name.compareTo(b.department.name);
    });

    return matches.take(limit).toList();
  }

  TaskFinderResult buildLocalTaskFinderResult(
    String query,
    List<TaskDepartmentMatch> matches,
  ) {
    if (matches.isEmpty) {
      return TaskFinderResult(
        primaryDepartmentId: null,
        secondaryDepartmentIds: const [],
        reason:
            'I could not find a strong local match for "$query". Try a simpler task description like "renew my passport" or "apply for food assistance".',
        nextSteps: const [
          'Try a more specific task or program name.',
          'Use one of the suggested prompt chips below.',
          'Browse departments by category if you are not sure which office applies.',
        ],
        clarifyingQuestion:
            'What kind of government help do you need: benefits, documents, jobs, housing, health, or veterans services?',
        usedAi: false,
        usedLocalFallback: true,
      );
    }

    final primaryMatch = matches.first;
    final secondaryMatches = matches.skip(1).take(2).toList();
    final matchedTerms = primaryMatch.matchedTokens.take(3).join(', ');
    final reason = matchedTerms.isEmpty
        ? '${primaryMatch.department.name} is the strongest local match based on its ${primaryMatch.strongestSignal}.'
        : '${primaryMatch.department.name} is the strongest local match because its ${primaryMatch.strongestSignal} align with "$matchedTerms".';

    return TaskFinderResult(
      primaryDepartmentId: primaryMatch.department.id,
      secondaryDepartmentIds:
          secondaryMatches.map((match) => match.department.id).toList(),
      reason: reason,
      nextSteps: _buildDefaultNextSteps(primaryMatch.department),
      clarifyingQuestion: _shouldAskClarifyingQuestion(matches)
          ? _buildClarifyingQuestion(primaryMatch, secondaryMatches)
          : null,
      usedAi: false,
      usedLocalFallback: true,
    );
  }

  Future<TaskFinderResult?> refineTaskSearchWithAi({
    required String query,
    required List<TaskDepartmentMatch> matches,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (query.trim().isEmpty || matches.isEmpty) {
      return null;
    }

    final candidates = matches.take(6).map((match) {
      final department = match.department;
      return {
        'id': department.id,
        'name': department.name,
        'services': department.services,
        'keywords': department.keywords,
        'category': department.category.displayName,
      };
    }).toList();

    final response = await OpenAIService.routeTaskToDepartment(
      task: query,
      candidateDepartments: candidates,
    ).timeout(timeout);

    final allowedIds =
        candidates.map((candidate) => candidate['id'] as String).toSet();
    final aiResult = TaskFinderResult.fromJson(response);
    final aiExplicitlyDeclinedPrimary =
        response.containsKey('primaryId') && response['primaryId'] == null;
    final sanitizedPrimary = aiResult.primaryDepartmentId != null &&
            allowedIds.contains(aiResult.primaryDepartmentId)
        ? aiResult.primaryDepartmentId
        : null;
    final sanitizedSecondary = aiResult.secondaryDepartmentIds
        .where(allowedIds.contains)
        .where((id) => id != sanitizedPrimary)
        .take(2)
        .toList();

    final localFallback = buildLocalTaskFinderResult(query, matches);

    return TaskFinderResult(
      primaryDepartmentId: aiExplicitlyDeclinedPrimary
          ? null
          : sanitizedPrimary ?? localFallback.primaryDepartmentId,
      secondaryDepartmentIds: aiExplicitlyDeclinedPrimary
          ? const []
          : sanitizedSecondary.isEmpty && sanitizedPrimary != null
              ? localFallback.secondaryDepartmentIds
              : sanitizedSecondary,
      reason:
          aiResult.reason.isNotEmpty ? aiResult.reason : localFallback.reason,
      nextSteps: aiResult.nextSteps.take(3).toList().isNotEmpty
          ? aiResult.nextSteps.take(3).toList()
          : localFallback.nextSteps,
      clarifyingQuestion: aiResult.clarifyingQuestion,
      usedAi: true,
      usedLocalFallback: false,
    );
  }

  /// Add a new department
  Future<void> addDepartment(Department department) async {
    try {
      // Validate department data
      _validateDepartment(department);

      // Check if department with same ID already exists
      final existing = await _repository.getDepartmentById(department.id);
      if (existing != null) {
        throw ServiceException(
            'Department with ID ${department.id} already exists');
      }

      // Add timestamp
      final departmentToAdd = department.copyWith(lastUpdated: DateTime.now());
      await _repository.addDepartment(departmentToAdd);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to add department: $e');
    }
  }

  /// Update an existing department
  Future<void> updateDepartment(Department department) async {
    try {
      _validateDepartment(department);

      // Check if department exists
      final existing = await _repository.getDepartmentById(department.id);
      if (existing == null) {
        throw ServiceException(
            'Department with ID ${department.id} does not exist');
      }

      // Update with new timestamp
      final departmentToUpdate =
          department.copyWith(lastUpdated: DateTime.now());
      await _repository.updateDepartment(departmentToUpdate);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to update department: $e');
    }
  }

  /// Delete a department
  Future<void> deleteDepartment(String id) async {
    try {
      // Check if department exists
      final existing = await _repository.getDepartmentById(id);
      if (existing == null) {
        throw ServiceException('Department with ID $id does not exist');
      }

      await _repository.deleteDepartment(id);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to delete department: $e');
    }
  }

  /// Generate a unique ID for new departments
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Validate department data
  void _validateDepartment(Department department) {
    if (department.name.trim().isEmpty) {
      throw ServiceException('Department name cannot be empty');
    }
    if (department.shortName.trim().isEmpty) {
      throw ServiceException('Department short name cannot be empty');
    }
    if (department.description.trim().isEmpty) {
      throw ServiceException('Department description cannot be empty');
    }
    if (department.contactInfo.email.isNotEmpty &&
        !_isValidEmail(department.contactInfo.email)) {
      throw ServiceException('Invalid email format');
    }
  }

  /// Simple email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// Get department details by ID
  Future<Department?> getDepartmentById(String id) async {
    try {
      return await _repository.getDepartmentById(id);
    } catch (e) {
      throw ServiceException('Failed to fetch department details: $e');
    }
  }

  /// Get favorite departments
  Future<List<Department>> getFavoriteDepartments(
      List<String> favoriteIds) async {
    try {
      final departments = await _repository.getDepartments();
      return departments
          .where((dept) => favoriteIds.contains(dept.id))
          .toList();
    } catch (e) {
      throw ServiceException('Failed to fetch favorite departments: $e');
    }
  }

  /// Get popular departments
  Future<List<Department>> getPopularDepartments() async {
    try {
      // Use repository's optimized getPopularDepartments method if available
      if (_repository case FirebaseDepartmentRepository firebaseRepo) {
        return await firebaseRepo.getPopularDepartments();
      } else if (_repository case HybridDepartmentRepository hybridRepo) {
        return await hybridRepo.getPopularDepartments();
      } else {
        // Fallback for other repositories
        final departments = await _repository.getDepartments();
        return departments.where((dept) => dept.isPopular).toList();
      }
    } catch (e) {
      throw ServiceException('Failed to fetch popular departments: $e');
    }
  }

  bool get hasPendingSyncWrites {
    if (_repository case HybridDepartmentRepository hybridRepo) {
      return hybridRepo.hasPendingWrites;
    }
    return false;
  }

  int get pendingSyncWritesCount {
    if (_repository case HybridDepartmentRepository hybridRepo) {
      return hybridRepo.pendingWritesCount;
    }
    return 0;
  }

  String get writeSyncStatusLabel {
    if (_repository case HybridDepartmentRepository hybridRepo) {
      switch (hybridRepo.lastWriteSyncStatus) {
        case WriteSyncStatus.pending:
          return 'pending';
        case WriteSyncStatus.synced:
          return 'synced';
      }
    }
    return 'synced';
  }

  String? get lastWriteSyncMessage {
    if (_repository case HybridDepartmentRepository hybridRepo) {
      return hybridRepo.lastWriteSyncMessage;
    }
    return null;
  }

  Future<void> retryPendingSyncWrites() async {
    if (_repository case HybridDepartmentRepository hybridRepo) {
      await hybridRepo.flushPendingOperations();
    }
  }

  /// Create multiple departments (for batch import)
  Future<void> createDepartments(List<Department> departments) async {
    try {
      // Validate each department
      for (final department in departments) {
        _validateDepartment(department);
      }

      // Add timestamps and create departments
      final departmentsToAdd = departments
          .map((dept) => dept.copyWith(lastUpdated: DateTime.now()))
          .toList();

      await _repository.createDepartments(departmentsToAdd);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to create departments: $e');
    }
  }

  List<String> _tokenizeTaskQuery(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 2 && !_taskStopWords.contains(token))
        .toSet()
        .toList();
  }

  double _scoreTaskField({
    required List<String> values,
    required List<String> queryTokens,
    required String normalizedQuery,
    required double weight,
    required Set<String> matchedTokens,
  }) {
    final normalizedValues = values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList();
    if (normalizedValues.isEmpty) {
      return 0;
    }

    final fieldTokens = normalizedValues
        .expand((value) => value.split(RegExp(r'[^a-z0-9]+')))
        .where((token) => token.isNotEmpty)
        .toList();
    if (fieldTokens.isEmpty) {
      return 0;
    }

    var score = 0.0;
    for (final token in queryTokens) {
      final hasExactMatch = fieldTokens.contains(token);
      final hasPartialMatch = !hasExactMatch &&
          fieldTokens.any(
            (fieldToken) =>
                fieldToken.contains(token) ||
                (token.length >= 5 && token.contains(fieldToken)),
          );

      if (hasExactMatch) {
        matchedTokens.add(token);
        score += 1.0;
      } else if (hasPartialMatch) {
        matchedTokens.add(token);
        score += 0.65;
      }
    }

    if (normalizedQuery.length >= 4 &&
        normalizedValues.any((value) => value.contains(normalizedQuery))) {
      matchedTokens.addAll(queryTokens);
      score += 0.75;
    }

    return weight * (score / fieldTokens.length);
  }

  List<String> _buildDefaultNextSteps(Department department) {
    final nextSteps = <String>[
      'Open the department details to review the available programs and requirements.',
    ];

    if (department.contactInfo.website.trim().isNotEmpty) {
      nextSteps.add(
          'Visit the official website for forms, eligibility, and application instructions.');
    }

    if (department.contactInfo.phone.trim().isNotEmpty) {
      nextSteps.add(
          'Call the office directly if you need help with the next step or current status.');
    } else if (department.location != null ||
        department.contactInfo.address.trim().isNotEmpty) {
      nextSteps.add('Get directions to the office if you need in-person help.');
    }

    return nextSteps.take(3).toList();
  }

  bool _shouldAskClarifyingQuestion(List<TaskDepartmentMatch> matches) {
    if (matches.isEmpty) {
      return true;
    }

    final primaryScore = matches.first.score;
    if (primaryScore < 0.35) {
      return true;
    }

    if (matches.length > 1 && matches[1].score >= primaryScore * 0.82) {
      return true;
    }

    return false;
  }

  String _buildClarifyingQuestion(
    TaskDepartmentMatch primaryMatch,
    List<TaskDepartmentMatch> secondaryMatches,
  ) {
    if (secondaryMatches.isNotEmpty) {
      final alternate = secondaryMatches.first.department.shortName.isNotEmpty
          ? secondaryMatches.first.department.shortName
          : secondaryMatches.first.department.name;
      final primaryName = primaryMatch.department.shortName.isNotEmpty
          ? primaryMatch.department.shortName
          : primaryMatch.department.name;
      return 'Is this closer to $primaryName or $alternate?';
    }

    if (primaryMatch.matchedTokens.isNotEmpty) {
      final topic = primaryMatch.matchedTokens.take(2).join(' or ');
      return 'Do you need to apply, check status, or find an office for $topic?';
    }

    return 'Do you need to apply, check status, or find a local office?';
  }
}

/// Custom exception for service layer errors
class ServiceException implements Exception {
  final String message;
  ServiceException(this.message);

  @override
  String toString() => 'ServiceException: $message';
}
