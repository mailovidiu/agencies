import 'package:cloud_firestore/cloud_firestore.dart';

/// Data models for Government Departments and Agencies

/// Represents a government department or agency
class Department {
  final String id;
  final String name;
  final String shortName;
  final String description;
  final DepartmentCategory category;
  final ContactInfo contactInfo;
  final List<String> services;
  final List<String> keywords;
  final bool isActive;
  final DateTime? lastUpdated;
  final DateTime? createdAt;
  // New fields for enhanced agency management
  final String? logoPath;           // Local path to logo image
  final String? parentDepartmentId; // Reference to parent department
  final List<String> tags;          // Tags for better organization
  final Location? location;         // Geographic location details
  final OfficeHours? officeHours;   // Operating hours information
  final bool isPopular;             // Whether this department is marked as popular

  const Department({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.category,
    required this.contactInfo,
    required this.services,
    required this.keywords,
    this.isActive = true,
    this.lastUpdated,
    this.createdAt,
    this.logoPath,
    this.parentDepartmentId,
    this.tags = const [],
    this.location,
    this.officeHours,
    this.isPopular = false,
  });

  /// Create Department from JSON
  factory Department.fromJson(Map<String, dynamic> json) {
    // Generate ID if not provided
    final departmentId = json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // Handle contact info - support both nested and flat structures
    Map<String, dynamic> contactInfoJson;
    if (json['contactInfo'] != null) {
      contactInfoJson = json['contactInfo'];
    } else {
      // Create contact info from flat structure
      contactInfoJson = {
        'phone': json['phone'] ?? '',
        'email': json['email'] ?? '',
        'website': json['website'] ?? '',
        'address': json['location']?['address'] ?? '',
      };
    }
    
    return Department(
      id: departmentId,
      name: json['name'] ?? '',
      shortName: json['shortName'] ?? '',
      description: json['description'] ?? '',
      category: DepartmentCategory.values.firstWhere(
        (cat) => cat.toString().split('.').last == json['category'],
        orElse: () => DepartmentCategory.other,
      ),
      contactInfo: ContactInfo.fromJson(contactInfoJson),
      services: List<String>.from(json['services'] ?? []),
      keywords: List<String>.from(json['keywords'] ?? []),
      isActive: json['isActive'] ?? true,
      lastUpdated: json['lastUpdated'] != null 
          ? (json['lastUpdated'] is Timestamp 
              ? (json['lastUpdated'] as Timestamp).toDate()
              : DateTime.tryParse(json['lastUpdated']))
          : null,
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(json['createdAt']))
          : DateTime.now(),
      logoPath: json['logoPath'],
      parentDepartmentId: json['parentDepartmentId'],
      tags: List<String>.from(json['tags'] ?? []),
      location: json['location'] != null ? Location.fromJson(json['location']) : null,
      officeHours: json['officeHours'] != null ? OfficeHours.fromJson(json['officeHours']) : null,
      isPopular: json['isPopular'] ?? false,
    );
  }

  /// Convert Department to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'description': description,
      'category': category.toString().split('.').last,
      'contactInfo': contactInfo.toJson(),
      'services': services,
      'keywords': keywords,
      'isActive': isActive,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      if (logoPath != null) 'logoPath': logoPath,
      if (parentDepartmentId != null) 'parentDepartmentId': parentDepartmentId,
      'tags': tags,
      if (location != null) 'location': location!.toJson(),
      if (officeHours != null) 'officeHours': officeHours!.toJson(),
      'isPopular': isPopular,
    };
  }

  /// Create Department from Firestore document
  factory Department.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Department.fromJson({...data, 'id': doc.id});
  }

  /// Convert Department to Firestore format
  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id'); // Firestore document ID is handled separately
    
    // Convert DateTime to Firestore Timestamp
    if (lastUpdated != null) {
      json['lastUpdated'] = Timestamp.fromDate(lastUpdated!);
    }
    if (createdAt != null) {
      json['createdAt'] = Timestamp.fromDate(createdAt!);
    }
    
    return json;
  }

  /// Create a copy with updated values
  Department copyWith({
    String? id,
    String? name,
    String? shortName,
    String? description,
    DepartmentCategory? category,
    ContactInfo? contactInfo,
    List<String>? services,
    List<String>? keywords,
    bool? isActive,
    DateTime? lastUpdated,
    DateTime? createdAt,
    String? logoPath,
    String? parentDepartmentId,
    List<String>? tags,
    Location? location,
    OfficeHours? officeHours,
    bool? isPopular,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      description: description ?? this.description,
      category: category ?? this.category,
      contactInfo: contactInfo ?? this.contactInfo,
      services: services ?? this.services,
      keywords: keywords ?? this.keywords,
      isActive: isActive ?? this.isActive,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
      logoPath: logoPath ?? this.logoPath,
      parentDepartmentId: parentDepartmentId ?? this.parentDepartmentId,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      officeHours: officeHours ?? this.officeHours,
      isPopular: isPopular ?? this.isPopular,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Department && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Department(id: $id, name: $name, shortName: $shortName)';
}

/// Contact information for a department
class ContactInfo {
  final String phone;
  final String email;
  final String website;
  final String address;
  final String? fax;
  final Map<String, String>? socialMedia;

  const ContactInfo({
    required this.phone,
    required this.email,
    required this.website,
    required this.address,
    this.fax,
    this.socialMedia,
  });

  /// Create ContactInfo from JSON
  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      website: json['website'] ?? '',
      address: json['address'] ?? '',
      fax: json['fax'],
      socialMedia: json['socialMedia'] != null 
          ? Map<String, String>.from(json['socialMedia'])
          : null,
    );
  }

  /// Convert ContactInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'email': email,
      'website': website,
      'address': address,
      if (fax != null) 'fax': fax,
      if (socialMedia != null) 'socialMedia': socialMedia,
    };
  }

  /// Create a copy with updated values
  ContactInfo copyWith({
    String? phone,
    String? email,
    String? website,
    String? address,
    String? fax,
    Map<String, String>? socialMedia,
  }) {
    return ContactInfo(
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      fax: fax ?? this.fax,
      socialMedia: socialMedia ?? this.socialMedia,
    );
  }

  @override
  String toString() => 'ContactInfo(phone: $phone, email: $email)';
}

/// Categories for organizing departments and agencies
enum DepartmentCategory {
  health,
  education,
  transportation,
  finance,
  security,
  environment,
  agriculture,
  socialServices,
  defense,
  justice,
  commerce,
  labor,
  energy,
  housing,
  veterans,
  other;

  /// Get display name for the category
  String get displayName {
    switch (this) {
      case DepartmentCategory.health:
        return 'Health & Medical';
      case DepartmentCategory.education:
        return 'Education';
      case DepartmentCategory.transportation:
        return 'Transportation';
      case DepartmentCategory.finance:
        return 'Finance & Revenue';
      case DepartmentCategory.security:
        return 'Security & Defense';
      case DepartmentCategory.environment:
        return 'Environment';
      case DepartmentCategory.agriculture:
        return 'Agriculture & Food';
      case DepartmentCategory.socialServices:
        return 'Social Services';
      case DepartmentCategory.defense:
        return 'Defense';
      case DepartmentCategory.justice:
        return 'Justice & Law';
      case DepartmentCategory.commerce:
        return 'Commerce & Trade';
      case DepartmentCategory.labor:
        return 'Labor & Employment';
      case DepartmentCategory.energy:
        return 'Energy & Resources';
      case DepartmentCategory.housing:
        return 'Housing & Development';
      case DepartmentCategory.veterans:
        return 'Veterans Affairs';
      case DepartmentCategory.other:
        return 'Other';
    }
  }

  /// Get icon name for the category
  String get iconName {
    switch (this) {
      case DepartmentCategory.health:
        return 'health_and_safety';
      case DepartmentCategory.education:
        return 'school';
      case DepartmentCategory.transportation:
        return 'directions_car';
      case DepartmentCategory.finance:
        return 'attach_money';
      case DepartmentCategory.security:
        return 'security';
      case DepartmentCategory.environment:
        return 'eco';
      case DepartmentCategory.agriculture:
        return 'agriculture';
      case DepartmentCategory.socialServices:
        return 'people';
      case DepartmentCategory.defense:
        return 'shield';
      case DepartmentCategory.justice:
        return 'gavel';
      case DepartmentCategory.commerce:
        return 'business';
      case DepartmentCategory.labor:
        return 'work';
      case DepartmentCategory.energy:
        return 'bolt';
      case DepartmentCategory.housing:
        return 'home';
      case DepartmentCategory.veterans:
        return 'military_tech';
      case DepartmentCategory.other:
        return 'category';
    }
  }
}

/// Geographic location information for a department
class Location {
  final String address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? mapLink;

  const Location({
    required this.address,
    this.city,
    this.state,
    this.zipCode,
    this.country,
    this.latitude,
    this.longitude,
    this.mapLink,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      address: json['address'] ?? '',
      city: json['city'],
      state: json['state'],
      zipCode: json['zipCode'],
      country: json['country'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      mapLink: json['mapLink'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (zipCode != null) 'zipCode': zipCode,
      if (country != null) 'country': country,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (mapLink != null) 'mapLink': mapLink,
    };
  }

  Location copyWith({
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    double? latitude,
    double? longitude,
    String? mapLink,
  }) {
    return Location(
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mapLink: mapLink ?? this.mapLink,
    );
  }

  /// Get formatted address string
  String get formattedAddress {
    final parts = <String>[address];
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    if (zipCode != null) parts.add(zipCode!);
    return parts.join(', ');
  }

  @override
  String toString() => 'Location(address: $address, city: $city, state: $state)';
}

/// Office hours information for a department
class OfficeHours {
  final Map<String, String> weeklyHours; // e.g., {"monday": "9:00 AM - 5:00 PM"}
  final List<String> holidays;           // List of holiday dates or descriptions
  final String? specialInstructions;     // Additional notes about hours
  final bool isOpen24x7;                 // Whether the department operates 24/7
  final String? emergencyContact;        // Contact for after-hours emergencies

  const OfficeHours({
    required this.weeklyHours,
    this.holidays = const [],
    this.specialInstructions,
    this.isOpen24x7 = false,
    this.emergencyContact,
  });

  factory OfficeHours.fromJson(Map<String, dynamic> json) {
    return OfficeHours(
      weeklyHours: Map<String, String>.from(json['weeklyHours'] ?? {}),
      holidays: List<String>.from(json['holidays'] ?? []),
      specialInstructions: json['specialInstructions'],
      isOpen24x7: json['isOpen24x7'] ?? false,
      emergencyContact: json['emergencyContact'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weeklyHours': weeklyHours,
      'holidays': holidays,
      if (specialInstructions != null) 'specialInstructions': specialInstructions,
      'isOpen24x7': isOpen24x7,
      if (emergencyContact != null) 'emergencyContact': emergencyContact,
    };
  }

  OfficeHours copyWith({
    Map<String, String>? weeklyHours,
    List<String>? holidays,
    String? specialInstructions,
    bool? isOpen24x7,
    String? emergencyContact,
  }) {
    return OfficeHours(
      weeklyHours: weeklyHours ?? this.weeklyHours,
      holidays: holidays ?? this.holidays,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      isOpen24x7: isOpen24x7 ?? this.isOpen24x7,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }

  /// Get today's hours based on current day of week
  String getTodaysHours() {
    final today = DateTime.now().weekday;
    final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final todayName = dayNames[today - 1];
    
    if (isOpen24x7) return '24/7';
    return weeklyHours[todayName] ?? 'Closed';
  }

  /// Check if currently open based on current time
  bool get isCurrentlyOpen {
    if (isOpen24x7) return true;
    
    final now = DateTime.now();
    final todayHours = getTodaysHours();
    
    if (todayHours == 'Closed') return false;
    
    // Simple check - in a real app you'd parse the time ranges
    // and compare with current time
    return todayHours.isNotEmpty && todayHours != 'Closed';
  }

  @override
  String toString() => 'OfficeHours(isOpen24x7: \$isOpen24x7, weeklyHours: \$weeklyHours)';
}