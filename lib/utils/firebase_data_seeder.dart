import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/department.dart';

/// Utility class to seed Firebase with initial sample data
/// for the US Government Departments and Agencies app
class FirebaseDataSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seed Firebase with comprehensive sample data
  Future<void> seedDatabase() async {
    try {
      print('🌱 Starting Firebase data seeding...');
      
      // Check if data already exists
      final existingDepts = await _firestore.collection('departments').limit(1).get();
      if (existingDepts.docs.isNotEmpty) {
        print('📊 Database already contains data, skipping seed');
        return;
      }

      // Seed departments
      await _seedDepartments();
      
      // Seed app settings
      await _seedAppSettings();
      
      print('✅ Firebase data seeding completed successfully');
    } catch (e) {
      print('❌ Firebase data seeding failed: $e');
      rethrow;
    }
  }

  /// Seed departments collection with sample government departments
  Future<void> _seedDepartments() async {
    final departments = _getSampleDepartments();
    final batch = _firestore.batch();
    
    print('📋 Seeding ${departments.length} departments...');
    
    for (final department in departments) {
      final docRef = _firestore.collection('departments').doc(department.id);
      batch.set(docRef, department.toFirestore());
    }
    
    await batch.commit();
    print('✅ Departments seeded successfully');
  }

  /// Seed app settings collection
  Future<void> _seedAppSettings() async {
    print('⚙️ Seeding app settings...');
    
    final settings = {
      'app_version': {
        'key': 'app_version',
        'value': '1.0.0',
        'description': 'Current version of the US Government Departments app',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'maintenance_mode': {
        'key': 'maintenance_mode',
        'value': false,
        'description': 'Whether the app is in maintenance mode',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'max_search_results': {
        'key': 'max_search_results',
        'value': 100,
        'description': 'Maximum number of search results to return',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'enable_analytics': {
        'key': 'enable_analytics',
        'value': true,
        'description': 'Whether to track user interactions for analytics',
        'updatedAt': FieldValue.serverTimestamp(),
      }
    };

    final batch = _firestore.batch();
    
    for (final entry in settings.entries) {
      final docRef = _firestore.collection('settings').doc(entry.key);
      batch.set(docRef, entry.value);
    }
    
    await batch.commit();
    print('✅ App settings seeded successfully');
  }

  /// Get sample departments data
  List<Department> _getSampleDepartments() {
    return [
      Department(
        id: 'hhs',
        name: 'Department of Health and Human Services',
        shortName: 'HHS',
        description: 'The United States Department of Health and Human Services is a cabinet-level executive branch department of the U.S. federal government with the goal of protecting the health of all Americans and providing essential human services.',
        category: DepartmentCategory.health,
        contactInfo: const ContactInfo(
          phone: '(202) 690-7000',
          email: 'info@hhs.gov',
          website: 'https://www.hhs.gov',
          address: '200 Independence Avenue SW, Washington, DC 20201',
        ),
        services: const [
          'Medicare and Medicaid administration',
          'Disease prevention and health promotion',
          'Food and drug safety',
          'Medical research funding',
          'Social services coordination'
        ],
        keywords: const ['health', 'medicare', 'medicaid', 'CDC', 'FDA', 'NIH', 'healthcare', 'medical research'],
        isActive: true,
        isPopular: true,
        tags: const ['healthcare', 'social-services', 'research'],
        createdAt: DateTime(2024, 1, 15, 10, 0),
        lastUpdated: DateTime(2024, 1, 15, 10, 0),
      ),
      Department(
        id: 'ed',
        name: 'Department of Education',
        shortName: 'ED',
        description: 'The United States Department of Education is a Cabinet-level department of the United States government. It began operating on May 4, 1980, having been created after the Department of Health, Education, and Welfare was split into the Department of Education and the Department of Health and Human Services.',
        category: DepartmentCategory.education,
        contactInfo: const ContactInfo(
          phone: '(202) 401-2000',
          email: 'info@ed.gov',
          website: 'https://www.ed.gov',
          address: '400 Maryland Avenue SW, Washington, DC 20202',
        ),
        services: const [
          'Federal student aid administration',
          'Educational research and statistics',
          'Civil rights enforcement in education',
          'Special education support',
          'Teacher preparation programs'
        ],
        keywords: const ['education', 'student loans', 'grants', 'schools', 'universities', 'teachers', 'learning'],
        isActive: true,
        isPopular: true,
        tags: const ['education', 'students', 'funding'],
        createdAt: DateTime(2024, 1, 15, 10, 15),
        lastUpdated: DateTime(2024, 1, 15, 10, 15),
      ),
      Department(
        id: 'epa',
        name: 'Environmental Protection Agency',
        shortName: 'EPA',
        description: 'The Environmental Protection Agency is an independent executive agency of the United States federal government tasked with environmental protection matters.',
        category: DepartmentCategory.environment,
        contactInfo: const ContactInfo(
          phone: '(202) 564-4700',
          email: 'info@epa.gov',
          website: 'https://www.epa.gov',
          address: '1200 Pennsylvania Avenue NW, Washington, DC 20460',
        ),
        services: const [
          'Air quality monitoring',
          'Water pollution control',
          'Chemical safety regulation',
          'Waste management oversight',
          'Environmental research'
        ],
        keywords: const ['environment', 'pollution', 'air quality', 'water', 'chemicals', 'climate', 'sustainability'],
        isActive: true,
        isPopular: false,
        tags: const ['environment', 'regulation', 'protection'],
        createdAt: DateTime(2024, 1, 15, 10, 30),
        lastUpdated: DateTime(2024, 1, 15, 10, 30),
      ),
      Department(
        id: 'dot',
        name: 'Department of Transportation',
        shortName: 'DOT',
        description: 'The United States Department of Transportation is a federal Cabinet department of the U.S. government concerned with transportation.',
        category: DepartmentCategory.transportation,
        contactInfo: const ContactInfo(
          phone: '(202) 366-4000',
          email: 'info@dot.gov',
          website: 'https://www.transportation.gov',
          address: '1200 New Jersey Avenue SE, Washington, DC 20590',
        ),
        services: const [
          'Highway system maintenance',
          'Aviation safety regulation',
          'Public transit funding',
          'Railroad oversight',
          'Maritime transportation'
        ],
        keywords: const ['transportation', 'highways', 'aviation', 'trains', 'public transit', 'infrastructure', 'safety'],
        isActive: true,
        isPopular: false,
        tags: const ['transportation', 'infrastructure', 'safety'],
        createdAt: DateTime(2024, 1, 15, 10, 45),
        lastUpdated: DateTime(2024, 1, 15, 10, 45),
      ),
      Department(
        id: 'va',
        name: 'Department of Veterans Affairs',
        shortName: 'VA',
        description: 'The United States Department of Veterans Affairs is a government-run military veteran benefit system with Cabinet-level status.',
        category: DepartmentCategory.veterans,
        contactInfo: const ContactInfo(
          phone: '(202) 461-4800',
          email: 'info@va.gov',
          website: 'https://www.va.gov',
          address: '810 Vermont Avenue NW, Washington, DC 20420',
        ),
        services: const [
          'Veteran healthcare',
          'Disability compensation',
          'Education benefits',
          'Home loans',
          'Career counseling'
        ],
        keywords: const ['veterans', 'healthcare', 'benefits', 'disability', 'education', 'military', 'service'],
        isActive: true,
        isPopular: true,
        tags: const ['veterans', 'benefits', 'healthcare'],
        createdAt: DateTime(2024, 1, 15, 11, 0),
        lastUpdated: DateTime(2024, 1, 15, 11, 0),
      ),
      Department(
        id: 'dod',
        name: 'Department of Defense',
        shortName: 'DoD',
        description: 'The United States Department of Defense is an executive branch department of the federal government charged with coordinating and supervising all agencies and functions of the government directly related to national security and the United States Armed Forces.',
        category: DepartmentCategory.defense,
        contactInfo: const ContactInfo(
          phone: '(703) 571-3343',
          email: 'info@defense.gov',
          website: 'https://www.defense.gov',
          address: '1400 Defense Pentagon, Washington, DC 20301',
        ),
        services: const [
          'National defense operations',
          'Military personnel management',
          'Defense research and development',
          'Intelligence coordination',
          'International security cooperation'
        ],
        keywords: const ['defense', 'military', 'security', 'armed forces', 'pentagon', 'national security'],
        isActive: true,
        isPopular: false,
        tags: const ['defense', 'military', 'security'],
        createdAt: DateTime(2024, 1, 15, 11, 15),
        lastUpdated: DateTime(2024, 1, 15, 11, 15),
      ),
      Department(
        id: 'doj',
        name: 'Department of Justice',
        shortName: 'DOJ',
        description: 'The United States Department of Justice is a federal executive department of the United States government tasked with the enforcement of federal law and administration of justice in the United States.',
        category: DepartmentCategory.justice,
        contactInfo: const ContactInfo(
          phone: '(202) 514-2000',
          email: 'info@justice.gov',
          website: 'https://www.justice.gov',
          address: '950 Pennsylvania Avenue NW, Washington, DC 20530',
        ),
        services: const [
          'Federal law enforcement',
          'Civil rights protection',
          'Immigration enforcement',
          'Federal prosecution',
          'Legal counsel to government'
        ],
        keywords: const ['justice', 'FBI', 'law enforcement', 'civil rights', 'immigration', 'prosecution'],
        isActive: true,
        isPopular: false,
        tags: const ['justice', 'law-enforcement', 'civil-rights'],
        createdAt: DateTime(2024, 1, 15, 11, 30),
        lastUpdated: DateTime(2024, 1, 15, 11, 30),
      ),
      Department(
        id: 'treasury',
        name: 'Department of the Treasury',
        shortName: 'Treasury',
        description: 'The Department of the Treasury is the national treasury and finance department of the federal government of the United States.',
        category: DepartmentCategory.finance,
        contactInfo: const ContactInfo(
          phone: '(202) 622-2000',
          email: 'info@treasury.gov',
          website: 'https://www.treasury.gov',
          address: '1500 Pennsylvania Avenue NW, Washington, DC 20220',
        ),
        services: const [
          'Federal revenue collection',
          'Currency and coin production',
          'Government debt management',
          'Financial regulation',
          'Economic policy development'
        ],
        keywords: const ['treasury', 'IRS', 'taxes', 'currency', 'finance', 'revenue', 'economic policy'],
        isActive: true,
        isPopular: true,
        tags: const ['finance', 'taxes', 'economy'],
        createdAt: DateTime(2024, 1, 15, 11, 45),
        lastUpdated: DateTime(2024, 1, 15, 11, 45),
      ),
    ];
  }

  /// Seed additional test data for development purposes
  Future<void> seedDevelopmentData() async {
    try {
      print('🧪 Seeding additional development data...');
      
      // Create test user interaction data
      await _seedTestInteractions();
      
      // Create test analytics data
      await _seedTestAnalytics();
      
      print('✅ Development data seeded successfully');
    } catch (e) {
      print('❌ Development data seeding failed: $e');
    }
  }

  /// Seed test user interactions
  Future<void> _seedTestInteractions() async {
    // This would require an actual user ID, so we'll skip for now
    print('⚠️ Skipping user interactions (no test user available)');
  }

  /// Seed test analytics data
  Future<void> _seedTestAnalytics() async {
    final analyticsData = {
      'departments': {
        'total_views': 1250,
        'total_searches': 380,
        'popular_categories': {
          'health': 45,
          'education': 38,
          'veterans': 32,
          'transportation': 28,
          'environment': 25,
        },
        'last_updated': FieldValue.serverTimestamp(),
      }
    };

    final batch = _firestore.batch();
    
    for (final entry in analyticsData.entries) {
      final docRef = _firestore.collection('analytics').doc(entry.key);
      batch.set(docRef, entry.value);
    }
    
    await batch.commit();
    print('✅ Analytics data seeded successfully');
  }

  /// Clear all seeded data (for testing purposes)
  Future<void> clearSeedData() async {
    try {
      print('🧹 Clearing seed data...');
      
      final batch = _firestore.batch();
      
      // Clear departments
      final deptSnapshot = await _firestore.collection('departments').get();
      for (final doc in deptSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Clear settings
      final settingsSnapshot = await _firestore.collection('settings').get();
      for (final doc in settingsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Clear analytics
      final analyticsSnapshot = await _firestore.collection('analytics').get();
      for (final doc in analyticsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('✅ Seed data cleared successfully');
    } catch (e) {
      print('❌ Failed to clear seed data: $e');
    }
  }

  /// Get seeding statistics
  Future<Map<String, int>> getSeedingStats() async {
    try {
      final stats = <String, int>{};
      
      final collections = ['departments', 'settings', 'analytics'];
      
      for (final collection in collections) {
        final snapshot = await _firestore.collection(collection).get();
        stats[collection] = snapshot.docs.length;
      }
      
      return stats;
    } catch (e) {
      print('Error getting seeding stats: $e');
      return {};
    }
  }
}