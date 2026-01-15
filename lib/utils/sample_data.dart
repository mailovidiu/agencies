/// Sample data utilities for the Government Departments app
library;

class SampleDataHelper {
  /// Sample JSON structure for importing departments
  static const String sampleJsonStructure = '''
[
  {
    "name": "Department of Health and Human Services",
    "shortName": "HHS",
    "description": "The United States Department of Health and Human Services is a cabinet-level executive branch department of the U.S. federal government created to protect the health of all Americans and providing essential human services.",
    "category": "health",
    "website": "https://www.hhs.gov",
    "email": "info@hhs.gov",
    "phone": "+1-877-696-6775",
    "logoPath": null,
    "parentDepartmentId": null,
    "tags": ["healthcare", "social services", "public health", "medicare", "medicaid"],
    "keywords": ["healthcare", "social services", "public health", "medicare", "medicaid"],
    "services": ["Medicare", "Medicaid", "CDC", "FDA", "NIH"],
    "isPopular": true,
    "location": {
      "address": "200 Independence Avenue SW",
      "city": "Washington",
      "state": "DC",
      "zipCode": "20201",
      "country": "United States",
      "latitude": 38.8877,
      "longitude": -77.0166
    },
    "officeHours": {
      "monday": {"open": "08:00", "close": "17:00"},
      "tuesday": {"open": "08:00", "close": "17:00"},
      "wednesday": {"open": "08:00", "close": "17:00"},
      "thursday": {"open": "08:00", "close": "17:00"},
      "friday": {"open": "08:00", "close": "17:00"}
    }
  },
  {
    "name": "Department of Education",
    "shortName": "ED", 
    "description": "The United States Department of Education is a Cabinet-level department of the United States government. It began operating on May 4, 1980, having been created after the Department of Health, Education, and Welfare was split into the Department of Education and the Department of Health and Human Services.",
    "category": "education",
    "website": "https://www.ed.gov",
    "email": "customerservice@ed.gov",
    "phone": "+1-800-872-5327",
    "logoPath": null,
    "parentDepartmentId": null,
    "tags": ["education", "schools", "students", "financial aid", "teachers"],
    "keywords": ["education", "schools", "students", "financial aid", "teachers"],
    "services": ["Student Aid", "School Improvement", "Special Education", "Career and Technical Education"],
    "isPopular": true,
    "location": {
      "address": "400 Maryland Avenue SW",
      "city": "Washington",
      "state": "DC",
      "zipCode": "20202",
      "country": "United States",
      "latitude": 38.8846,
      "longitude": -77.0179
    },
    "officeHours": {
      "monday": {"open": "08:00", "close": "17:00"},
      "tuesday": {"open": "08:00", "close": "17:00"},
      "wednesday": {"open": "08:00", "close": "17:00"},
      "thursday": {"open": "08:00", "close": "17:00"},
      "friday": {"open": "08:00", "close": "17:00"}
    }
  },
  {
    "name": "Environmental Protection Agency",
    "shortName": "EPA",
    "description": "The Environmental Protection Agency is an independent executive agency of the United States federal government tasked with environmental protection matters.",
    "category": "environment",
    "website": "https://www.epa.gov",
    "email": "headquarters@epa.gov",
    "phone": "+1-202-272-0167",
    "logoPath": null,
    "parentDepartmentId": null,
    "tags": ["environment", "pollution", "air quality", "water quality", "climate"],
    "keywords": ["environment", "pollution", "air quality", "water quality", "climate"],
    "services": ["Air Quality Monitoring", "Water Protection", "Chemical Safety", "Waste Management"],
    "isPopular": false,
    "location": {
      "address": "1200 Pennsylvania Avenue NW",
      "city": "Washington",
      "state": "DC",
      "zipCode": "20460",
      "country": "United States",
      "latitude": 38.8951,
      "longitude": -77.0364
    },
    "officeHours": {
      "monday": {"open": "08:30", "close": "17:00"},
      "tuesday": {"open": "08:30", "close": "17:00"},
      "wednesday": {"open": "08:30", "close": "17:00"},
      "thursday": {"open": "08:30", "close": "17:00"},
      "friday": {"open": "08:30", "close": "17:00"}
    }
  }
]
''';



  /// Valid category values for JSON import
  static const List<String> validCategories = [
    'health',
    'education',
    'transportation',
    'finance',
    'security',
    'environment',
    'agriculture',
    'socialServices',
    'defense',
    'justice',
    'commerce',
    'labor',
    'energy',
    'housing',
    'veterans',
    'other',
  ];

  /// Required fields for JSON import
  static const List<String> requiredFields = [
    'name',
    'shortName', 
    'description',
  ];

  /// Optional fields for JSON import
  static const List<String> optionalFields = [
    'category',
    'website',
    'email',
    'phone',
    'logoUrl',
    'parentDepartmentId',
    'tags',
    'services',
    'location',
    'officeHours',
    'isPopular',
  ];
}