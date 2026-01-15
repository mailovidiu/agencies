import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/department_provider.dart';
import '../providers/auth_provider.dart';
import '../models/department.dart';
import 'department_form_screen.dart';
import '../utils/sample_data.dart';

/// Admin screen for managing departments and agencies
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _searchQuery = '';
  DepartmentCategory? _selectedCategory;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DepartmentProvider>().loadDepartments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _showImportDialog,
            tooltip: 'Import Departments',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthProvider>().signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Theme.of(context).colorScheme.onSurface),
                    const SizedBox(width: 8),
                    const Text('Logout'),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DepartmentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.departments.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: provider.refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildHeader(provider),
              _buildSearchAndFilter(),
              Expanded(
                child: _buildDepartmentsList(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewDepartment,
        icon: const Icon(Icons.add),
        label: const Text('Add Department'),
      ),
    );
  }

  Widget _buildHeader(DepartmentProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Departments',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${provider.departments.length}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${provider.getAvailableCategories().length}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search departments...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              context.read<DepartmentProvider>().searchDepartments(value);
            },
          ),
          const SizedBox(height: 16),
          // Category filter
          Consumer<DepartmentProvider>(
            builder: (context, provider, child) {
              final categories = provider.getAvailableCategories();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = null;
                        });
                        provider.filterByCategory(null);
                      },
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category.displayName),
                        selected: _selectedCategory == category,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = selected ? category : null;
                          });
                          provider.filterByCategory(selected ? category : null);
                        },
                      ),
                    )).toList(),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDepartmentsList(DepartmentProvider provider) {
    final departments = provider.filteredDepartments;
    
    if (departments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'No departments found matching your criteria'
                  : 'No departments available',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'Try adjusting your search or filters'
                  : 'Add your first department using the button below',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: departments.length,
        itemBuilder: (context, index) {
          final department = departments[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  department.shortName.substring(0, 2).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                department.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(department.category.displayName),
                  const SizedBox(height: 4),
                  Text(
                    department.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) => _handleDepartmentAction(action, department),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      leading: Icon(Icons.content_copy),
                      title: Text('Duplicate'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
              onTap: () => _editDepartment(department),
            ),
          );
        },
      ),
    );
  }

  void _handleDepartmentAction(String action, Department department) {
    switch (action) {
      case 'edit':
        _editDepartment(department);
        break;
      case 'duplicate':
        _duplicateDepartment(department);
        break;
      case 'delete':
        _deleteDepartment(department);
        break;
    }
  }

  void _addNewDepartment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DepartmentFormScreen(),
      ),
    );
  }

  void _editDepartment(Department department) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DepartmentFormScreen(department: department),
      ),
    );
  }

  void _duplicateDepartment(Department department) {
    final provider = context.read<DepartmentProvider>();
    final duplicatedDepartment = department.copyWith(
      id: provider.generateId(),
      name: '${department.name} (Copy)',
      shortName: '${department.shortName}C',
      lastUpdated: null,
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DepartmentFormScreen(department: duplicatedDepartment),
      ),
    );
  }

  void _deleteDepartment(Department department) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text('Are you sure you want to delete "${department.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await context.read<DepartmentProvider>().deleteDepartment(department.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${department.name} deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete department: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Departments'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Import departments from a JSON file:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Smart Import:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('Departments with matching names will be automatically updated instead of creating duplicates.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Required fields:'),
              const SizedBox(height: 4),
              const Text('• name, shortName, description'),
              const SizedBox(height: 12),
              const Text('Optional fields:'),
              const SizedBox(height: 4),
              const Text('• category, website, email, phone, tags, location, officeHours, services, isPopular, etc.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copySampleJson(),
                      icon: const Icon(Icons.content_copy, size: 16),
                      label: const Text('Copy Sample JSON'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showSampleJson(),
                      icon: const Icon(Icons.preview, size: 16),
                      label: const Text('View Sample'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showFileImportNotAvailable();
            },
            icon: const Icon(Icons.file_upload),
            label: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  void _copySampleJson() async {
    await Clipboard.setData(ClipboardData(text: SampleDataHelper.sampleJsonStructure));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample JSON copied to clipboard!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSampleJson() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sample JSON Format',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      SampleDataHelper.sampleJsonStructure,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _copySampleJson(),
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy to Clipboard'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileImportNotAvailable() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File import functionality is not available'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<ImportResults> _processDepartmentsImport(
    List<dynamic> jsonData, 
    DepartmentProvider provider
  ) async {
    int successful = 0;
    int failed = 0;
    int updated = 0;
    List<String> errors = [];

    for (int i = 0; i < jsonData.length; i++) {
      try {
        final departmentJson = jsonData[i];
        if (departmentJson is! Map<String, dynamic>) {
          throw Exception('Item at index $i is not a valid object');
        }

        // Validate required fields
        if (!departmentJson.containsKey('name') || 
            !departmentJson.containsKey('shortName') ||
            !departmentJson.containsKey('description')) {
          throw Exception('Missing required fields: name, shortName, or description');
        }

        // Parse category
        DepartmentCategory category = DepartmentCategory.other;
        if (departmentJson.containsKey('category')) {
          final categoryStr = departmentJson['category'].toString().toLowerCase();
          category = DepartmentCategory.values.firstWhere(
            (c) => c.name.toLowerCase() == categoryStr,
            orElse: () => DepartmentCategory.other,
          );
        }

        // Parse location
        Location? location;
        if (departmentJson.containsKey('location') && 
            departmentJson['location'] is Map<String, dynamic>) {
          final locJson = departmentJson['location'] as Map<String, dynamic>;
          location = Location(
            address: locJson['address']?.toString() ?? '',
            city: locJson['city']?.toString(),
            state: locJson['state']?.toString(),
            zipCode: locJson['zipCode']?.toString(),
            country: locJson['country']?.toString(),
            latitude: locJson['latitude']?.toDouble(),
            longitude: locJson['longitude']?.toDouble(),
          );
        }

        // Parse office hours
        OfficeHours? officeHours;
        if (departmentJson.containsKey('officeHours') && 
            departmentJson['officeHours'] is Map<String, dynamic>) {
          final hoursJson = departmentJson['officeHours'] as Map<String, dynamic>;
          final weeklyHours = <String, String>{};
          
          for (final entry in hoursJson.entries) {
            if (entry.value is Map<String, dynamic>) {
              final dayHours = entry.value as Map<String, dynamic>;
              if (dayHours.containsKey('open') && dayHours.containsKey('close')) {
                weeklyHours[entry.key] = '${dayHours['open']} - ${dayHours['close']}';
              }
            } else if (entry.value is String) {
              weeklyHours[entry.key] = entry.value.toString();
            }
          }
          
          if (weeklyHours.isNotEmpty) {
            officeHours = OfficeHours(weeklyHours: weeklyHours);
          }
        }

        // Parse tags
        List<String> tags = [];
        if (departmentJson.containsKey('tags') && 
            departmentJson['tags'] is List) {
          tags = (departmentJson['tags'] as List)
              .map((tag) => tag.toString())
              .toList();
        }

        // Parse contact info
        final contactInfo = ContactInfo(
          phone: departmentJson['phone']?.toString() ?? '',
          email: departmentJson['email']?.toString() ?? '',
          website: departmentJson['website']?.toString() ?? '',
          address: location?.address ?? '',
        );

        // Parse services
        List<String> services = [];
        if (departmentJson.containsKey('services') && 
            departmentJson['services'] is List) {
          services = (departmentJson['services'] as List)
              .map((s) => s.toString())
              .toList();
        }

        // Parse keywords (use tags as keywords if not provided)
        List<String> keywords = tags;
        if (departmentJson.containsKey('keywords') && 
            departmentJson['keywords'] is List) {
          keywords = (departmentJson['keywords'] as List)
              .map((k) => k.toString())
              .toList();
        }

        // Generate unique ID - use a combination of timestamp + counter to ensure uniqueness
        final String uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${i.toString().padLeft(4, '0')}';
        
        // Check if department with this name already exists
        final existingDepartments = provider.allDepartments;
        final existingByName = existingDepartments.where((dept) => 
          dept.name.toLowerCase() == departmentJson['name'].toString().toLowerCase() ||
          dept.shortName.toLowerCase() == departmentJson['shortName'].toString().toLowerCase()
        ).toList();
        
        if (existingByName.isNotEmpty) {
          // Ask whether to update existing or skip
          final existingDept = existingByName.first;
          // Update existing department instead of creating new one
          final department = existingDept.copyWith(
            name: departmentJson['name'].toString(),
            shortName: departmentJson['shortName'].toString(),
            description: departmentJson['description'].toString(),
            category: category,
            contactInfo: contactInfo,
            services: services,
            keywords: keywords,
            logoPath: departmentJson['logoPath']?.toString(),
            parentDepartmentId: departmentJson['parentDepartmentId']?.toString(),
            tags: tags,
            location: location,
            officeHours: officeHours,
            isPopular: departmentJson['isPopular'] == true,
            lastUpdated: DateTime.now(),
          );
          
          await provider.updateDepartment(department);
          updated++;
          continue; // Skip to next iteration
        }
        
        // Create new department
        final department = Department(
          id: uniqueId,
          name: departmentJson['name'].toString(),
          shortName: departmentJson['shortName'].toString(),
          description: departmentJson['description'].toString(),
          category: category,
          contactInfo: contactInfo,
          services: services,
          keywords: keywords,
          logoPath: departmentJson['logoPath']?.toString(),
          parentDepartmentId: departmentJson['parentDepartmentId']?.toString(),
          tags: tags,
          location: location,
          officeHours: officeHours,
          isPopular: departmentJson['isPopular'] == true,
          lastUpdated: DateTime.now(),
        );

        // Save department
        await provider.addDepartment(department);
        successful++;

      } catch (e) {
        failed++;
        errors.add('Row ${i + 1}: $e');
      }
    }

    return ImportResults(
      successful: successful,
      updated: updated,
      failed: failed,
      errors: errors,
    );
  }

  void _showImportResults(ImportResults results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Results'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Successfully imported: ${results.successful} new departments'),
              if (results.updated > 0) ...[
                const SizedBox(height: 4),
                Text('Updated existing: ${results.updated} departments'),
              ],
              if (results.failed > 0) ...[
                const SizedBox(height: 8),
                Text('Failed to import: ${results.failed} departments'),
                if (results.errors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Errors:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...results.errors.take(5).map((error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  )),
                  if (results.errors.length > 5)
                    Text('... and ${results.errors.length - 5} more errors'),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Panel Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Managing Departments:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Use the + button to add new departments'),
              Text('• Tap any department to edit it'),
              Text('• Use the menu (⋮) for more actions'),
              Text('• Pull down to refresh the list'),
              SizedBox(height: 16),
              Text(
                'Import Departments:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Use the upload icon to import from JSON'),
              Text('• Supports bulk creation of departments'),
              Text('• See import dialog for JSON format'),
              SizedBox(height: 16),
              Text(
                'Search & Filter:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Search by name, description, or keywords'),
              Text('• Filter by category using the chips'),
              Text('• Combine search and filters for precise results'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class ImportResults {
  final int successful;
  final int updated;
  final int failed;
  final List<String> errors;

  ImportResults({
    required this.successful,
    this.updated = 0,
    required this.failed,
    required this.errors,
  });
}