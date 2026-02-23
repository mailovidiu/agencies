import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/department_provider.dart';
import '../models/department.dart';
import 'department_detail_screen.dart';

/// Screen showing recently updated departments — the "What's New" feed
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'What\'s New',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<DepartmentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allDepartments.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final departments = _getRecentlyUpdated(provider.allDepartments);

          if (departments.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: departments.length,
              itemBuilder: (context, index) {
                final department = departments[index];
                return _buildUpdateCard(context, department, provider);
              },
            ),
          );
        },
      ),
    );
  }

  /// Sort departments by lastUpdated, most recent first
  List<Department> _getRecentlyUpdated(List<Department> departments) {
    final sorted = List<Department>.from(departments);
    sorted.sort((a, b) {
      final aDate = a.lastUpdated ?? a.createdAt ?? DateTime(2000);
      final bDate = b.lastUpdated ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  Widget _buildUpdateCard(
    BuildContext context,
    Department department,
    DepartmentProvider provider,
  ) {
    final updateDate = department.lastUpdated ?? department.createdAt;
    final timeAgo = updateDate != null
        ? _formatTimeAgo(updateDate)
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DepartmentDetailScreen(department: department),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: category badge + time ago
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(department.category),
                          size: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          department.category.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Department name
              Text(
                department.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Short name
              Text(
                department.shortName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              // Description preview
              Text(
                department.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Bottom row: tags + arrow
              Row(
                children: [
                  if (department.tags.isNotEmpty) ...[
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: department.tags
                            .take(3)
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.newspaper_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Updates Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When departments are updated, they\'ll appear here so you stay in the loop.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format a DateTime as a human-readable "time ago" string
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
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
        return Icons.account_balance;
      case DepartmentCategory.security:
        return Icons.security;
      case DepartmentCategory.environment:
        return Icons.eco;
      case DepartmentCategory.agriculture:
        return Icons.agriculture;
      case DepartmentCategory.socialServices:
        return Icons.people;
      case DepartmentCategory.defense:
        return Icons.shield;
      case DepartmentCategory.justice:
        return Icons.gavel;
      case DepartmentCategory.commerce:
        return Icons.store;
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
}
