import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/department_provider.dart';
import '../models/department.dart';
import '../widgets/department_card.dart';
import 'department_detail_screen.dart';

/// Screen showing all departments for a specific category
class CategoryScreen extends StatefulWidget {
  final DepartmentCategory category;

  const CategoryScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Department> _filteredDepartments = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFilteredDepartments();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilteredDepartments() {
    final provider = context.read<DepartmentProvider>();
    final categoryDepartments = provider.allDepartments
        .where((dept) => dept.category == widget.category)
        .toList();
    
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredDepartments = categoryDepartments;
      } else {
        final query = _searchController.text.toLowerCase();
        _filteredDepartments = categoryDepartments
            .where((dept) =>
                dept.name.toLowerCase().contains(query) ||
                dept.shortName.toLowerCase().contains(query) ||
                dept.description.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _onSearchChanged() {
    _updateFilteredDepartments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category.displayName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              '${_filteredDepartments.length} departments',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DepartmentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.departments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading departments...'),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Category header
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      // Category icon and description
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _getCategoryIcon(widget.category),
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getCategoryDescription(widget.category),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search in ${widget.category.displayName}...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Department list
              Expanded(
                child: _filteredDepartments.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredDepartments.length,
                        itemBuilder: (context, index) {
                          final department = _filteredDepartments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DepartmentCard(
                              department: department,
                              isFavorite: provider.isFavorite(department.id),
                              onFavoriteToggle: () => provider.toggleFavorite(department.id),
                              onTap: () => _navigateToDetail(context, department, provider),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty ? Icons.search_off : Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty 
                  ? 'No departments found'
                  : 'No departments available',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty 
                  ? 'Try adjusting your search terms'
                  : 'Check back later for updates',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, Department department, DepartmentProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DepartmentDetailScreen(
          department: department,
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
        return Icons.agriculture;
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

  String _getCategoryDescription(DepartmentCategory category) {
    switch (category) {
      case DepartmentCategory.health:
        return 'Departments and agencies focused on public health, medical research, and healthcare services.';
      case DepartmentCategory.education:
        return 'Educational institutions, research organizations, and student services.';
      case DepartmentCategory.transportation:
        return 'Transportation infrastructure, aviation, maritime, and surface transportation agencies.';
      case DepartmentCategory.finance:
        return 'Financial regulation, monetary policy, and economic development agencies.';
      case DepartmentCategory.security:
        return 'National security, intelligence, and law enforcement agencies.';
      case DepartmentCategory.environment:
        return 'Environmental protection, natural resource management, and climate agencies.';
      case DepartmentCategory.agriculture:
        return 'Agricultural research, food safety, and rural development agencies.';
      case DepartmentCategory.socialServices:
        return 'Social welfare, human services, and community development programs.';
      case DepartmentCategory.defense:
        return 'Military branches, defense agencies, and national defense organizations.';
      case DepartmentCategory.justice:
        return 'Legal system, courts, law enforcement, and justice administration.';
      case DepartmentCategory.commerce:
        return 'Trade, business development, and commercial regulation agencies.';
      case DepartmentCategory.labor:
        return 'Employment services, worker protection, and labor relations agencies.';
      case DepartmentCategory.energy:
        return 'Energy production, regulation, and research organizations.';
      case DepartmentCategory.housing:
        return 'Housing programs, urban development, and community planning agencies.';
      case DepartmentCategory.veterans:
        return 'Veterans affairs, benefits, healthcare, and support services.';
      case DepartmentCategory.other:
        return 'Miscellaneous government departments and agencies.';
    }
  }
}