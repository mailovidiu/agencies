import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/department.dart';
import '../providers/department_provider.dart';
import '../openai/openai_config.dart';

class DepartmentCompareScreen extends StatefulWidget {
  const DepartmentCompareScreen({super.key});

  @override
  State<DepartmentCompareScreen> createState() => _DepartmentCompareScreenState();
}

class _DepartmentCompareScreenState extends State<DepartmentCompareScreen> {
  final List<Department> _selectedDepartments = [];
  String? _comparisonResult;
  bool _isLoadingComparison = false;
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Departments'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          if (_selectedDepartments.length >= 2)
            IconButton(
              onPressed: _isLoadingComparison ? null : _compareSelected,
              icon: const Icon(Icons.compare_arrows),
              tooltip: 'Compare Selected',
            ),
          IconButton(
            onPressed: _selectedDepartments.isEmpty ? null : _clearSelection,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Selection',
          ),
        ],
      ),
      body: Consumer<DepartmentProvider>(
        builder: (context, provider, child) {
          final departments = provider.departments;
          
          if (departments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64),
                  SizedBox(height: 16),
                  Text('No departments available to compare'),
                ],
              ),
            );
          }
          
          return Column(
            children: [
              // Selection Info Banner
              if (_selectedDepartments.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.checklist,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedDepartments.length} department${_selectedDepartments.length == 1 ? '' : 's'} selected',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_selectedDepartments.length >= 2)
                            FilledButton.icon(
                              onPressed: _isLoadingComparison ? null : _compareSelected,
                              icon: _isLoadingComparison
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.auto_awesome),
                              label: const Text('AI Compare'),
                            ),
                        ],
                      ),
                      
                      if (_selectedDepartments.length < 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Select at least 2 departments to enable AI comparison',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              
              // Comparison Result
              if (_comparisonResult != null)
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'AI Comparison Result',
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _copyToClipboard(context, _comparisonResult!),
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copy',
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _comparisonResult = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Close',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Scrollable AI Result Content
                            Expanded(
                              child: SingleChildScrollView(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: SelectableText(
                                    _comparisonResult!,
                                    style: textTheme.bodyMedium?.copyWith(height: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _compareSelected,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Regenerate'),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _shareComparison(),
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              
              // Department List
              Expanded(
                flex: _comparisonResult != null ? 1 : 3,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: departments.length,
                  itemBuilder: (context, index) {
                    final department = departments[index];
                    final isSelected = _selectedDepartments.contains(department);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? colorScheme.primary
                                : colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getCategoryIcon(department.category),
                            color: isSelected 
                                ? colorScheme.onPrimary
                                : colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          department.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              department.category.displayName,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              department.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (department.isPopular)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Popular',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Checkbox(
                              value: isSelected,
                              onChanged: (bool? value) {
                                _toggleDepartmentSelection(department);
                              },
                            ),
                          ],
                        ),
                        onTap: () => _toggleDepartmentSelection(department),
                        isThreeLine: true,
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

  void _toggleDepartmentSelection(Department department) {
    setState(() {
      if (_selectedDepartments.contains(department)) {
        _selectedDepartments.remove(department);
      } else {
        if (_selectedDepartments.length < 5) {
          _selectedDepartments.add(department);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 5 departments can be compared at once'),
            ),
          );
        }
      }
      
      // Clear comparison result when selection changes
      _comparisonResult = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedDepartments.clear();
      _comparisonResult = null;
    });
  }

  Future<void> _compareSelected() async {
    if (_selectedDepartments.length < 2 || _isLoadingComparison) return;

    setState(() {
      _isLoadingComparison = true;
    });

    try {
      final departmentsData = _selectedDepartments.map((dept) => {
        'name': dept.name,
        'description': dept.description,
        'category': dept.category.displayName,
        'services': dept.services,
      }).toList();

      final comparison = await OpenAIService.compareDepartments(departmentsData);
      
      setState(() {
        _comparisonResult = comparison;
        _isLoadingComparison = false;
      });
      
      // Scroll to show comparison result
      // The result will be visible after the selection banner
      
    } catch (e) {
      setState(() {
        _isLoadingComparison = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate comparison: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareComparison() {
    if (_comparisonResult == null) return;
    
    final selectedNames = _selectedDepartments.map((d) => d.name).join(', ');
    final shareText = '''Department Comparison: $selectedNames

$_comparisonResult

Generated by GovApp AI Assistant''';
    
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comparison copied to clipboard'),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
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
}