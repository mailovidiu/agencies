import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/department.dart';
import '../providers/department_provider.dart';

/// Form screen for adding or editing departments
class DepartmentFormScreen extends StatefulWidget {
  final Department? department;
  
  const DepartmentFormScreen({super.key, this.department});
  
  bool get isEditing => department != null;

  @override
  State<DepartmentFormScreen> createState() => _DepartmentFormScreenState();
}

class _DepartmentFormScreenState extends State<DepartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _shortNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _addressController;
  late final TextEditingController _faxController;
  late final TextEditingController _servicesController;
  late final TextEditingController _keywordsController;
  late final TextEditingController _tagsController;
  
  // Location controllers
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _zipCodeController;
  late final TextEditingController _countryController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _mapLinkController;
  
  // Office hours controllers
  late final Map<String, TextEditingController> _hoursControllers;
  late final TextEditingController _holidaysController;
  late final TextEditingController _specialInstructionsController;
  late final TextEditingController _emergencyContactController;
  
  DepartmentCategory _selectedCategory = DepartmentCategory.other;
  bool _isActive = true;
  bool _isOpen24x7 = false;
  String? _parentDepartmentId;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _nameController = TextEditingController();
    _shortNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _websiteController = TextEditingController();
    _addressController = TextEditingController();
    _faxController = TextEditingController();
    _servicesController = TextEditingController();
    _keywordsController = TextEditingController();
    _tagsController = TextEditingController();
    
    // Location controllers
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _zipCodeController = TextEditingController();
    _countryController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _mapLinkController = TextEditingController();
    
    // Office hours controllers
    _hoursControllers = {
      'monday': TextEditingController(),
      'tuesday': TextEditingController(),
      'wednesday': TextEditingController(),
      'thursday': TextEditingController(),
      'friday': TextEditingController(),
      'saturday': TextEditingController(),
      'sunday': TextEditingController(),
    };
    _holidaysController = TextEditingController();
    _specialInstructionsController = TextEditingController();
    _emergencyContactController = TextEditingController();
    
    // Populate with existing data if editing
    if (widget.department != null) {
      _populateForm(widget.department!);
    }
  }

  void _populateForm(Department department) {
    _nameController.text = department.name;
    _shortNameController.text = department.shortName;
    _descriptionController.text = department.description;
    _phoneController.text = department.contactInfo.phone;
    _emailController.text = department.contactInfo.email;
    _websiteController.text = department.contactInfo.website;
    _addressController.text = department.contactInfo.address;
    _faxController.text = department.contactInfo.fax ?? '';
    _servicesController.text = department.services.join(', ');
    _keywordsController.text = department.keywords.join(', ');
    _tagsController.text = department.tags.join(', ');
    
    _selectedCategory = department.category;
    _isActive = department.isActive;
    _parentDepartmentId = department.parentDepartmentId;
    
    // Location data
    if (department.location != null) {
      _cityController.text = department.location!.city ?? '';
      _stateController.text = department.location!.state ?? '';
      _zipCodeController.text = department.location!.zipCode ?? '';
      _countryController.text = department.location!.country ?? '';
      _latitudeController.text = department.location!.latitude?.toString() ?? '';
      _longitudeController.text = department.location!.longitude?.toString() ?? '';
      _mapLinkController.text = department.location!.mapLink ?? '';
    }
    
    // Office hours data
    if (department.officeHours != null) {
      _isOpen24x7 = department.officeHours!.isOpen24x7;
      for (final entry in department.officeHours!.weeklyHours.entries) {
        _hoursControllers[entry.key]?.text = entry.value;
      }
      _holidaysController.text = department.officeHours!.holidays.join(', ');
      _specialInstructionsController.text = department.officeHours!.specialInstructions ?? '';
      _emergencyContactController.text = department.officeHours!.emergencyContact ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Department' : 'Add Department'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _saveDepartment,
            icon: const Icon(Icons.save),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildContactInfoSection(),
              const SizedBox(height: 24),
              _buildLocationSection(),
              const SizedBox(height: 24),
              _buildOfficeHoursSection(),
              const SizedBox(height: 24),
              _buildServicesSection(),
              const SizedBox(height: 24),
              _buildAdditionalInfoSection(),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveDepartment,
                      child: Text(widget.isEditing ? 'Update' : 'Create'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Department Name *',
                hintText: 'e.g., Department of Health',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Department name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shortNameController,
              decoration: const InputDecoration(
                labelText: 'Short Name *',
                hintText: 'e.g., DOH',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Short name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Brief description of the department\'s role and responsibilities',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Description is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DepartmentCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
              ),
              items: DepartmentCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Whether this department is currently active'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildContactInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                hintText: 'e.g., +1-800-123-4567',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                hintText: 'e.g., info@department.gov',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email address is required';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website *',
                hintText: 'e.g., https://department.gov',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.web),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Website is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address *',
                hintText: 'Complete street address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Address is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _faxController,
              decoration: const InputDecoration(
                labelText: 'Fax Number',
                hintText: 'Optional fax number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.print),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State/Province',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _zipCodeController,
                    decoration: const InputDecoration(
                      labelText: 'ZIP/Postal Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '40.7128',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '-74.0060',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mapLinkController,
              decoration: const InputDecoration(
                labelText: 'Map Link',
                hintText: 'Google Maps or other map service link',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficeHoursSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Office Hours',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Open 24/7'),
              subtitle: const Text('Department operates 24 hours a day'),
              value: _isOpen24x7,
              onChanged: (value) {
                setState(() {
                  _isOpen24x7 = value;
                });
              },
            ),
            if (!_isOpen24x7) ...[
              const SizedBox(height: 16),
              ...['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                  .map((day) {
                final dayKey = day.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _hoursControllers[dayKey],
                    decoration: InputDecoration(
                      labelText: day,
                      hintText: 'e.g., 9:00 AM - 5:00 PM or Closed',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }).toList(),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _holidaysController,
              decoration: const InputDecoration(
                labelText: 'Holidays',
                hintText: 'Comma-separated list of holidays when closed',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _specialInstructionsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Special Instructions',
                hintText: 'Additional notes about operating hours',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyContactController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact',
                hintText: 'After-hours emergency contact information',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.emergency),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Services & Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _servicesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Services',
                hintText: 'Comma-separated list of services offered',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _keywordsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Keywords',
                hintText: 'Comma-separated keywords for search',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Comma-separated tags for organization',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Consumer<DepartmentProvider>(
              builder: (context, provider, child) {
                final departments = provider.departments;
                final availableParents = departments.where((dept) => dept.id != widget.department?.id).toList();
                
                return DropdownButtonFormField<String?>(
                  value: _parentDepartmentId,
                  decoration: const InputDecoration(
                    labelText: 'Parent Department',
                    hintText: 'Select a parent department (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None (Top-level department)'),
                    ),
                    ...availableParents.map((dept) {
                      return DropdownMenuItem(
                        value: dept.id,
                        child: Text('${dept.name} (${dept.shortName})'),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _parentDepartmentId = value;
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _saveDepartment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final provider = context.read<DepartmentProvider>();
      
      // Parse coordinates
      double? latitude;
      double? longitude;
      if (_latitudeController.text.isNotEmpty) {
        latitude = double.tryParse(_latitudeController.text);
      }
      if (_longitudeController.text.isNotEmpty) {
        longitude = double.tryParse(_longitudeController.text);
      }
      
      // Create location object
      Location? location;
      if (_addressController.text.isNotEmpty) {
        location = Location(
          address: _addressController.text,
          city: _cityController.text.isNotEmpty ? _cityController.text : null,
          state: _stateController.text.isNotEmpty ? _stateController.text : null,
          zipCode: _zipCodeController.text.isNotEmpty ? _zipCodeController.text : null,
          country: _countryController.text.isNotEmpty ? _countryController.text : null,
          latitude: latitude,
          longitude: longitude,
          mapLink: _mapLinkController.text.isNotEmpty ? _mapLinkController.text : null,
        );
      }
      
      // Create office hours object
      OfficeHours? officeHours;
      final weeklyHours = <String, String>{};
      for (final entry in _hoursControllers.entries) {
        if (entry.value.text.isNotEmpty) {
          weeklyHours[entry.key] = entry.value.text;
        }
      }
      
      if (_isOpen24x7 || weeklyHours.isNotEmpty) {
        officeHours = OfficeHours(
          isOpen24x7: _isOpen24x7,
          weeklyHours: weeklyHours,
          holidays: _holidaysController.text.isNotEmpty
              ? _holidaysController.text.split(',').map((e) => e.trim()).toList()
              : [],
          specialInstructions: _specialInstructionsController.text.isNotEmpty
              ? _specialInstructionsController.text
              : null,
          emergencyContact: _emergencyContactController.text.isNotEmpty
              ? _emergencyContactController.text
              : null,
        );
      }
      
      // Create department object
      final department = Department(
        id: widget.department?.id ?? provider.generateId(),
        name: _nameController.text,
        shortName: _shortNameController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        contactInfo: ContactInfo(
          phone: _phoneController.text,
          email: _emailController.text,
          website: _websiteController.text,
          address: _addressController.text,
          fax: _faxController.text.isNotEmpty ? _faxController.text : null,
        ),
        services: _servicesController.text.isNotEmpty
            ? _servicesController.text.split(',').map((e) => e.trim()).toList()
            : [],
        keywords: _keywordsController.text.isNotEmpty
            ? _keywordsController.text.split(',').map((e) => e.trim()).toList()
            : [],
        isActive: _isActive,
        logoPath: null,
        parentDepartmentId: _parentDepartmentId,
        tags: _tagsController.text.isNotEmpty
            ? _tagsController.text.split(',').map((e) => e.trim()).toList()
            : [],
        location: location,
        officeHours: officeHours,
      );
      
      // Save department
      if (widget.isEditing) {
        await provider.updateDepartment(department);
      } else {
        await provider.addDepartment(department);
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Department updated successfully'
                  : 'Department added successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save department: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _faxController.dispose();
    _servicesController.dispose();
    _keywordsController.dispose();
    _tagsController.dispose();
    
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapLinkController.dispose();
    
    for (final controller in _hoursControllers.values) {
      controller.dispose();
    }
    _holidaysController.dispose();
    _specialInstructionsController.dispose();
    _emergencyContactController.dispose();
    
    super.dispose();
  }
}