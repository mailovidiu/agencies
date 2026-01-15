# Firebase Setup Guide for US Government Departments & Agencies App

This guide provides comprehensive instructions for setting up Firebase integration in your US Government Departments & Agencies app.

## 🔥 Firebase Project Configuration

### Project Information
- **Project ID**: `u-s-departments-and-age-gnkn5k`
- **Package Name**: `com.trendmobileapp.usgovdepandagen`

### Platform Configurations
- **Android**: `1:795440992614:android:fce9430ec7d30d514b78a7`
- **iOS**: `1:795440992614:ios:d67b38e7d56258aa4b78a7`
- **Web**: `1:795440992614:web:2c37255ecb8d0c174b78a7`

## 📁 Firebase Files Overview

### Configuration Files
1. **`firebase.json`** - Main Firebase project configuration
2. **`firestore.rules`** - Security rules for Firestore database
3. **`firestore.indexes.json`** - Database indexes for query optimization
4. **`lib/firebase_options.dart`** - Platform-specific configuration (auto-generated)

### Core Firebase Services
1. **`lib/services/firebase_service.dart`** - Main Firebase service class
2. **`lib/services/firebase_initialization_service.dart`** - Initialization and setup
3. **`lib/services/firebase_admin_service.dart`** - Admin operations
4. **`lib/providers/firebase_auth_provider.dart`** - Authentication state management

### Utilities
1. **`lib/utils/firebase_data_seeder.dart`** - Database seeding with sample data
2. **`lib/utils/data_migration.dart`** - Data migration utilities

## 🔐 Authentication Setup

### Admin Users
The app is configured with admin email authentication. To add admin users:

1. **Update Firestore Security Rules** (`firestore.rules`):
   ```javascript
   // Add your admin emails to this list
   && request.auth.token.email in [
     "ovi@ovi.ro",      // Current admin
     "your@email.com"   // Add your admin emails here
   ];
   ```

2. **Update Auth Service** (`lib/services/auth_service.dart`):
   ```dart
   const adminEmails = <String>[
     "ovi@ovi.ro",      // Current admin
     "your@email.com"   // Add your admin emails here
   ];
   ```

### Enable Authentication in Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/u/0/project/u-s-departments-and-age-gnkn5k/authentication/providers)
2. Enable **Email/Password** authentication
3. Add authorized domains if needed

## 🗄️ Firestore Database Setup

### Collections Structure
```
departments/          # Government departments and agencies
├── [departmentId]/
    ├── name: string
    ├── shortName: string
    ├── description: string
    ├── category: string
    ├── contactInfo: object
    ├── services: array
    ├── keywords: array
    ├── isActive: boolean
    ├── isPopular: boolean
    ├── tags: array
    ├── createdAt: timestamp
    └── lastUpdated: timestamp

users/               # User profiles
├── [userId]/
    ├── email: string
    ├── displayName: string
    ├── createdAt: timestamp
    ├── lastLoginAt: timestamp
    └── isActive: boolean

users/[userId]/favorites/    # User's favorite departments
├── [departmentId]/
    ├── departmentId: string
    └── addedAt: timestamp

users/[userId]/interactions/  # User interaction tracking
├── [interactionId]/
    ├── departmentId: string
    ├── type: string
    ├── timestamp: timestamp
    └── metadata: object

users/[userId]/chatHistory/  # AI chat history
├── [chatId]/
    ├── departmentId: string
    ├── question: string
    ├── answer: string
    ├── timestamp: timestamp
    └── metadata: object

settings/            # App-wide settings
├── app_version/
├── maintenance_mode/
└── max_search_results/

analytics/           # Analytics data
└── departments/
    ├── total_views: number
    ├── total_searches: number
    └── popular_categories: object
```

### Security Rules Summary
- **Departments**: Public read, admin write
- **User data**: Private to individual users
- **Settings**: Authenticated read, admin write
- **Analytics**: Authenticated read, admin write

## 🚀 Deployment Instructions

### 1. Deploy Firestore Rules and Indexes
```bash
# Deploy security rules
firebase deploy --only firestore:rules

# Deploy indexes
firebase deploy --only firestore:indexes
```

### 2. Initialize Sample Data
The app automatically seeds the database with sample data on first run. To manually seed:

```dart
// In your app initialization
final seeder = FirebaseDataSeeder();
await seeder.seedDatabase();
```

### 3. Verify Setup
Use the built-in validation:

```dart
// Check Firebase setup
final adminService = FirebaseAdminService();
final status = await adminService.validateFirestoreSetup();
print('Setup status: $status');
```

## 📊 Sample Data

The app includes comprehensive sample data:

### Departments Included
1. **Department of Health and Human Services** (Popular)
2. **Department of Education** (Popular)  
3. **Environmental Protection Agency**
4. **Department of Transportation**
5. **Department of Veterans Affairs** (Popular)
6. **Department of Defense**
7. **Department of Justice**
8. **Department of the Treasury** (Popular)

### Categories Covered
- Health & Medical
- Education
- Environment  
- Transportation
- Veterans Affairs
- Defense
- Justice & Law
- Finance & Revenue

## 🔧 Configuration Options

### Environment Variables
No environment variables needed - all configuration is in `firebase_options.dart`.

### Feature Flags (in Firestore settings)
- `maintenance_mode`: Enable/disable app maintenance
- `enable_analytics`: Track user interactions
- `max_search_results`: Limit search results

## 🐛 Troubleshooting

### Common Issues

1. **"Missing or insufficient permissions"**
   - Check if Firestore rules are deployed
   - Verify user authentication status
   - Ensure admin email is in the rules

2. **"The query requires an index"**
   - Deploy Firestore indexes: `firebase deploy --only firestore:indexes`
   - Check `firestore.indexes.json` for required indexes

3. **Authentication not working**
   - Enable Email/Password in Firebase Console
   - Check admin emails configuration
   - Verify Firebase project settings

4. **Data not loading**
   - Check network connectivity
   - Verify Firestore rules allow read access
   - Check sample data seeding

### Debug Mode
Enable debug logging:

```dart
// In main.dart
void main() async {
  // Enable Firestore debug logging
  FirebaseFirestore.setLoggingEnabled(true);
  
  // Your initialization code...
}
```

## 📈 Monitoring and Analytics

### Firebase Console Monitoring
- [Authentication](https://console.firebase.google.com/u/0/project/u-s-departments-and-age-gnkn5k/authentication/users)
- [Firestore Database](https://console.firebase.google.com/u/0/project/u-s-departments-and-age-gnkn5k/firestore/data)
- [Usage Analytics](https://console.firebase.google.com/u/0/project/u-s-departments-and-age-gnkn5k/analytics)

### In-App Analytics
The app tracks:
- Department views
- Search queries
- Favorite additions/removals
- AI chat interactions

## 🔄 Data Migration

### From Local Storage
The app automatically migrates existing localStorage data to Firebase on first run.

### Manual Migration
```dart
final migrationUtility = DataMigrationUtility(firebaseRepository);
await migrationUtility.migrateFromLocalStorage();
```

### Export/Import
```dart
// Export data
final adminService = FirebaseAdminService();
final exportData = await adminService.exportDepartmentsAsJson();

// Import data
await adminService.bulkImportDepartments(departments);
```

## 📞 Support

For issues with Firebase setup:
1. Check this documentation first
2. Review Firebase Console for errors
3. Check app logs for detailed error messages
4. Verify all configuration files are properly deployed

---

**Last Updated**: January 2025  
**App Version**: 1.0.0  
**Firebase SDK Version**: Latest