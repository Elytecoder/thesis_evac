# Mobile App Infrastructure - Complete

## 🎉 What's Been Built

All missing infrastructure has been implemented using **mock data only**. The architecture is ready to switch from mock to real API calls by simply changing one flag.

---

## 📁 New Folder Structure

```
lib/
├── main.dart                              # ✅ Updated with Hive initialization
├── core/
│   ├── config/
│   │   ├── api_config.dart                # ✅ API URLs and mock mode toggle
│   │   └── storage_config.dart            # ✅ Storage box names and keys
│   ├── network/
│   │   └── api_client.dart                # ✅ Dio HTTP client wrapper
│   └── storage/
│       └── storage_service.dart           # ✅ Hive offline storage service
├── models/
│   ├── evacuation_center.dart             # (existing)
│   ├── user.dart                          # ✅ NEW
│   ├── route.dart                         # ✅ NEW
│   ├── hazard_report.dart                 # ✅ NEW
│   └── baseline_hazard.dart               # ✅ NEW
├── data/
│   ├── mock_evacuation_centers.dart       # (existing)
│   ├── mock_routes.dart                   # ✅ NEW
│   ├── mock_hazards.dart                  # ✅ NEW
│   └── mock_users.dart                    # ✅ NEW
├── features/
│   ├── authentication/
│   │   └── auth_service.dart              # ✅ NEW - Login/Register/Logout
│   ├── hazards/
│   │   └── hazard_service.dart            # ✅ NEW - Report/View hazards
│   └── routing/
│       └── routing_service.dart           # ✅ NEW - Calculate routes
└── ui/
    └── screens/
        └── map_screen.dart                # (existing - no changes)
```

---

## ✅ New Dependencies Added

Updated `pubspec.yaml` with:

```yaml
# API & Network
dio: ^5.4.0                    # HTTP client
http: ^1.2.0                   # Alternative HTTP

# Local storage (offline support)
hive: ^2.2.3                   # NoSQL local database
hive_flutter: ^1.1.0           # Hive Flutter integration
path_provider: ^2.1.0          # File paths

# State management & utilities
shared_preferences: ^2.2.0     # Key-value storage
```

**Run this to install:**
```powershell
cd c:\Users\elyth\thesis_evac\mobile
flutter pub get
```

---

## 🔧 How to Use the New Services

### 1. **Authentication Service**

```dart
import 'package:mobile/features/authentication/auth_service.dart';

final authService = AuthService();

// Login (currently returns mock user)
try {
  final user = await authService.login('john_doe', 'password123');
  print('Logged in as: ${user.fullName}');
  print('Role: ${user.role}');
} catch (e) {
  print('Login failed: $e');
}

// Register new user
final newUser = await authService.register(
  username: 'jane_doe',
  email: 'jane@example.com',
  password: 'secure123',
  firstName: 'Jane',
  lastName: 'Doe',
);

// Logout
await authService.logout();
```

### 2. **Routing Service**

```dart
import 'package:mobile/features/routing/routing_service.dart';

final routingService = RoutingService();

// Get evacuation centers
final centers = await routingService.getEvacuationCenters();

// Calculate routes (returns 3 routes: safest to riskiest)
final routes = await routingService.calculateRoutes(
  startLat: 12.6699,
  startLng: 123.8758,
  evacuationCenterId: centers[0].id,
  evacuationCenter: centers[0],
);

// Routes are sorted by safety
for (var i = 0; i < routes.length; i++) {
  print('Route ${i + 1}:');
  print('  Distance: ${routes[i].totalDistance}m');
  print('  Risk: ${routes[i].totalRisk}');
  print('  Level: ${routes[i].riskLevel.value}'); // Green/Yellow/Red
}
```

### 3. **Hazard Service**

```dart
import 'package:mobile/features/hazards/hazard_service.dart';

final hazardService = HazardService();

// Submit hazard report
final report = await hazardService.submitHazardReport(
  hazardType: 'flood',
  latitude: 12.6700,
  longitude: 123.8755,
  description: 'Heavy flooding on Main Street',
  photoUrl: 'https://example.com/photo.jpg', // optional
);

print('Report submitted! ID: ${report.id}');
print('Naive Bayes Score: ${report.naiveBayesScore}');
print('Consensus Score: ${report.consensusScore}');
print('Status: ${report.status.value}');

// Get baseline hazards (MDRRMO data)
final baselineHazards = await hazardService.getBaselineHazards();

// MDRRMO only: Get pending reports
final pendingReports = await hazardService.getPendingReports();

// MDRRMO only: Approve/Reject report
await hazardService.approveOrRejectReport(
  reportId: 1,
  approve: true,
  comment: 'Verified by field inspection',
);
```

### 4. **Offline Storage**

```dart
import 'package:mobile/core/storage/storage_service.dart';

final storage = StorageService();

// Save evacuation centers for offline use
await storage.saveEvacuationCenters(
  centers.map((c) => c.toJson()).toList()
);

// Retrieve cached data
final cachedCenters = await storage.getEvacuationCenters();

// Check last sync time
final lastSync = await storage.getLastSyncTime(
  StorageConfig.evacuationCentersBox
);
```

---

## 🎛️ Switching from Mock to Real API

**Step 1:** Open `lib/core/config/api_config.dart`

**Step 2:** Change this line:

```dart
static const bool useMockData = true;  // Change to false
```

**Step 3:** Update the backend URL for your device:

```dart
// For Android emulator:
static const String baseUrl = 'http://10.0.2.2:8000/api';

// For physical device (replace with your computer's IP):
static const String baseUrl = 'http://192.168.x.x:8000/api';
```

**That's it!** All services will automatically start using real API calls.

---

## 🔍 What Each Service Does

### **AuthService** (`features/authentication/auth_service.dart`)
- ✅ Login with username/password
- ✅ Register new users (residents only)
- ✅ Logout
- ✅ Token management (save/retrieve/clear)
- ✅ Check if user is logged in
- **Mock**: Returns `MockUsers.getResidentUser()` or `MockUsers.getMdrrmoUser()`
- **Real**: POST to `/api/auth/login/` and `/api/auth/register/`

### **RoutingService** (`features/routing/routing_service.dart`)
- ✅ Get all evacuation centers
- ✅ Calculate 3 safest routes using Modified Dijkstra
- ✅ Get evacuation center by ID
- ✅ Bootstrap sync (initial data download)
- **Mock**: Returns `getMockRoutes()` with 3 color-coded routes
- **Real**: POST to `/api/calculate-route/`

### **HazardService** (`features/hazards/hazard_service.dart`)
- ✅ Submit hazard reports (with optional photo/video URLs)
- ✅ Get baseline hazards (MDRRMO data)
- ✅ Get pending reports (MDRRMO only)
- ✅ Approve/reject reports (MDRRMO only)
- **Mock**: Returns simulated ML scores (Naive Bayes, Consensus)
- **Real**: POST to `/api/report-hazard/`

### **StorageService** (`core/storage/storage_service.dart`)
- ✅ Hive initialization
- ✅ Cache evacuation centers
- ✅ Cache baseline hazards
- ✅ Cache road segments
- ✅ Save/retrieve user data
- ✅ Clear cache
- ✅ Track last sync time

---

## 📊 Mock Data Available

### **Users** (`data/mock_users.dart`)
- Resident: `john_doe` (john@example.com)
- MDRRMO: `mdrrmo_admin` (admin@mdrrmo.gov.ph)

### **Routes** (`data/mock_routes.dart`)
- 3 routes with different risk levels (Green, Green, Yellow)
- Realistic coordinates based on start/end points
- Includes distance, risk score, and weight

### **Hazards** (`data/mock_hazards.dart`)
- 5 baseline hazards: flood, landslide, fire, storm surge
- Located in Bulan, Sorsogon area
- Severity scores: 0.55 - 0.80

### **Evacuation Centers** (`data/mock_evacuation_centers.dart`)
- 3 centers: Gymnasium, School, Barangay Hall
- Real coordinates in Bulan, Sorsogon

---

## 🧪 Testing the New Features

### Test Authentication
```dart
// In your UI or test file:
final auth = AuthService();
final user = await auth.login('test', 'password');
print('User: ${user.fullName}, Role: ${user.role}');
```

### Test Route Calculation
```dart
final routing = RoutingService();
final centers = await routing.getEvacuationCenters();
final routes = await routing.calculateRoutes(
  startLat: 12.6690,
  startLng: 123.8750,
  evacuationCenterId: centers[0].id,
  evacuationCenter: centers[0],
);
print('Got ${routes.length} routes');
print('Safest route: ${routes[0].riskLevel.value}');
```

### Test Hazard Reporting
```dart
final hazard = HazardService();
final report = await hazard.submitHazardReport(
  hazardType: 'flood',
  latitude: 12.6700,
  longitude: 123.8755,
  description: 'Test report',
);
print('Report ID: ${report.id}');
print('Validation scores: NB=${report.naiveBayesScore}, CS=${report.consensusScore}');
```

---

## 🔄 Integration with Existing Map Screen

Your existing `map_screen.dart` doesn't need any changes yet. When you're ready to integrate:

```dart
// In map_screen.dart, replace:
final centers = getMockEvacuationCenters();

// With:
final routingService = RoutingService();
final centers = await routingService.getEvacuationCenters();

// When user selects a center:
final routes = await routingService.calculateRoutes(
  startLat: currentLocation.latitude,
  startLng: currentLocation.longitude,
  evacuationCenterId: selectedCenter.id,
  evacuationCenter: selectedCenter,
);

// Display routes on map with colors:
// - Green route (routes[0]) - safest
// - Yellow route (routes[2]) - moderate risk
```

---

## 📝 Next Steps

1. **Install dependencies:**
   ```powershell
   flutter pub get
   ```

2. **Test the app:**
   ```powershell
   flutter run
   ```

3. **Gradually integrate services into UI:**
   - Start with routing service (easiest)
   - Then add hazard reporting button
   - Finally add authentication screens

4. **When backend is ready:**
   - Change `ApiConfig.useMockData` to `false`
   - Update `baseUrl` with correct IP
   - Test all endpoints

---

## 🚀 What You Have Now

✅ Complete service layer with mock data  
✅ All models (User, Route, HazardReport, BaselineHazard)  
✅ API client ready for real backend  
✅ Offline storage with Hive  
✅ Easy toggle between mock and real data  
✅ Clean architecture (features, core, data, models)  
✅ No UI changes needed yet  

**Status:** Infrastructure complete! Ready to integrate with UI whenever you want.

---

## 💡 Key Design Decisions

1. **Mock Mode First**: All services work with mock data by default
2. **Single Toggle**: Change `ApiConfig.useMockData` to switch to real API
3. **No UI Changes**: Your existing map screen still works
4. **Clean Services**: Each service is independent and testable
5. **Offline Ready**: Hive storage initialized and ready to use
6. **Thesis-Ready**: Professional architecture matching backend structure

---

**Questions?** All services follow the same pattern:
- Check `ApiConfig.useMockData`
- If true → return mock data
- If false → call real API

This makes it super easy to test locally first, then connect to backend later!
