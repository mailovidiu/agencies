import 'department.dart';

class TaskDepartmentMatch {
  final Department department;
  final double score;
  final Map<String, double> fieldScores;
  final List<String> matchedTokens;

  const TaskDepartmentMatch({
    required this.department,
    required this.score,
    required this.fieldScores,
    required this.matchedTokens,
  });

  String get strongestSignal {
    if (fieldScores.isEmpty) {
      return 'department information';
    }

    final sortedEntries = fieldScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    switch (sortedEntries.first.key) {
      case 'services':
        return 'services';
      case 'keywords':
        return 'keywords';
      case 'tags':
        return 'tags';
      case 'name':
        return 'name';
      case 'description':
        return 'description';
      default:
        return 'department information';
    }
  }
}

class TaskFinderResult {
  final String? primaryDepartmentId;
  final List<String> secondaryDepartmentIds;
  final String reason;
  final List<String> nextSteps;
  final String? clarifyingQuestion;
  final bool usedAi;
  final bool usedLocalFallback;

  const TaskFinderResult({
    required this.primaryDepartmentId,
    required this.secondaryDepartmentIds,
    required this.reason,
    required this.nextSteps,
    this.clarifyingQuestion,
    this.usedAi = false,
    this.usedLocalFallback = false,
  });

  TaskFinderResult copyWith({
    String? primaryDepartmentId,
    List<String>? secondaryDepartmentIds,
    String? reason,
    List<String>? nextSteps,
    String? clarifyingQuestion,
    bool? usedAi,
    bool? usedLocalFallback,
  }) {
    return TaskFinderResult(
      primaryDepartmentId: primaryDepartmentId ?? this.primaryDepartmentId,
      secondaryDepartmentIds:
          secondaryDepartmentIds ?? this.secondaryDepartmentIds,
      reason: reason ?? this.reason,
      nextSteps: nextSteps ?? this.nextSteps,
      clarifyingQuestion: clarifyingQuestion ?? this.clarifyingQuestion,
      usedAi: usedAi ?? this.usedAi,
      usedLocalFallback: usedLocalFallback ?? this.usedLocalFallback,
    );
  }

  factory TaskFinderResult.fromJson(Map<String, dynamic> json) {
    return TaskFinderResult(
      primaryDepartmentId: json['primaryId'] as String?,
      secondaryDepartmentIds:
          List<String>.from(json['secondaryIds'] ?? const []),
      reason: (json['reason'] ?? '').toString().trim(),
      nextSteps: List<String>.from(json['nextSteps'] ?? const []),
      clarifyingQuestion: (json['clarifyingQuestion'] as String?)
          ?.trim()
          .replaceAll(RegExp(r'\s+'), ' '),
      usedAi: true,
      usedLocalFallback: false,
    );
  }
}

class TaskFinderSearchResponse {
  final List<TaskDepartmentMatch> matches;
  final TaskFinderResult? result;

  const TaskFinderSearchResponse({
    required this.matches,
    required this.result,
  });
}
