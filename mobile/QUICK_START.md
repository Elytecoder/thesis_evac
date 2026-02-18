# 🚀 Quick Start Guide - Mobile Infrastructure

## ✅ Installation (One-Time Setup)

```powershell
# Navigate to mobile folder
cd c:\Users\elyth\thesis_evac\mobile

# Install all new dependencies
flutter pub get

# Verify installation
flutter doctor
```

If any issues, run:
```powershell
flutter clean
flutter pub get
```

---

## 🎯 What You Can Do Now

### 1. **Test the App (Existing UI Still Works)**

```powershell
flutter run
```

Your map screen still works exactly as before! All new infrastructure is available but doesn't interfere with existing code.

---

### 2. **Try the Services (In Code)**

Open any Dart file and import:

```dart
// Authentication
import 'package:mobile/features/authentication/auth_service.dart';

// Routing
import 'package:mobile/features/routing/routing_service.dart';

// Hazards
import 'package:mobile/features/hazards/hazard_service.dart';
```

**Quick test in your widget:**

```dart
// Get evacuation centers (returns mock data)
final routing = RoutingService();
final centers = await routing.getEvacuationCenters();
print('Got ${centers.length} centers');

// Calculate routes (returns 3 mock routes)
final routes = await routing.calculateRoutes(
  startLat: 12.6690,
  startLng: 123.8750,
  evacuationCenterId: centers[0].id,
  evacuationCenter: centers[0],
);
print('Route 1: ${routes[0].riskLevel.value}'); // Green/Yellow/Red
```

---

## 📂 File Structure Reference

```
lib/
├── 📱 main.dart                          # Entry point (Hive initialized)
│
├── ⚙️ core/                              # Infrastructure
│   ├── config/
│   │   ├── api_config.dart              # ⭐ Toggle mock/real here
│   │   └── storage_config.dart
│   ├── network/
│   │   └── api_client.dart              # Dio HTTP client
│   └── storage/
│       └── storage_service.dart         # Hive offline storage
│
├── 🎨 models/                            # Data models
│   ├── user.dart
│   ├── route.dart
│   ├── hazard_report.dart
│   ├── baseline_hazard.dart
│   └── evacuation_center.dart
│
├── 💾 data/                              # Mock data
│   ├── mock_users.dart
│   ├── mock_routes.dart
│   ├── mock_hazards.dart
│   └── mock_evacuation_centers.dart
│
├── 🔧 features/                          # Services (business logic)
│   ├── authentication/
│   │   └── auth_service.dart            # Login/Register/Logout
│   ├── routing/
│   │   └── routing_service.dart         # Routes/Centers
│   └── hazards/
│       └── hazard_service.dart          # Report/View hazards
│
├── 📋 examples/
│   └── service_usage_examples.dart      # Copy-paste examples
│
└── 🖼️ ui/
    └── screens/
        └── map_screen.dart              # Your existing map
```

---

## 🔄 Switching to Real Backend

**When your Django backend is running:**

1. Open `lib/core/config/api_config.dart`

2. Change:
   ```dart
   static const bool useMockData = false;  // Changed from true
   ```

3. Update backend URL:
   ```dart
   // Android emulator:
   static const String baseUrl = 'http://10.0.2.2:8000/api';
   
   // Physical device (replace with your PC's IP):
   static const String baseUrl = 'http://192.168.1.100:8000/api';
   ```

4. Done! All services now use real API.

---

## 🧪 Testing Services

### **Test 1: Authentication**

```dart
final auth = AuthService();

// Mock login (no backend needed)
final user = await auth.login('john_doe', 'password');
print('User: ${user.fullName}');
print('Role: ${user.role.value}'); // "resident" or "mdrrmo"
```

### **Test 2: Route Calculation**

```dart
final routing = RoutingService();

// Get centers
final centers = await routing.getEvacuationCenters();

// Calculate routes (takes ~2 seconds - simulated processing)
final routes = await routing.calculateRoutes(
  startLat: 12.6690,
  startLng: 123.8750,
  evacuationCenterId: centers[0].id,
  evacuationCenter: centers[0],
);

// Print results
for (var i = 0; i < routes.length; i++) {
  print('Route ${i + 1}:');
  print('  Distance: ${routes[i].totalDistance}m');
  print('  Risk: ${routes[i].totalRisk}');
  print('  Level: ${routes[i].riskLevel.value}');
}
```

### **Test 3: Hazard Reporting**

```dart
final hazard = HazardService();

// Submit report
final report = await hazard.submitHazardReport(
  hazardType: 'flood',
  latitude: 12.6700,
  longitude: 123.8755,
  description: 'Water level rising on Main St',
);

// Check ML validation scores
print('Naive Bayes: ${report.naiveBayesScore}');  // 0.0 - 1.0
print('Consensus: ${report.consensusScore}');     // 0.0 - 1.0
print('Status: ${report.status.value}');          // "pending"
```

---

## 📝 Common Tasks

### **Task 1: Integrate Routes into Map Screen**

In `map_screen.dart`, after user selects a center:

```dart
final routingService = RoutingService();

// Calculate routes
final routes = await routingService.calculateRoutes(
  startLat: _currentLocation.latitude,
  startLng: _currentLocation.longitude,
  evacuationCenterId: selectedCenter.id,
  evacuationCenter: selectedCenter,
);

// Draw routes on map (flutter_map)
// routes[0] = Green (safest)
// routes[1] = Green/Yellow (alternative)
// routes[2] = Yellow/Red (riskier)
```

### **Task 2: Add Hazard Report Button**

```dart
FloatingActionButton(
  child: Icon(Icons.report),
  onPressed: () async {
    // Show dialog to collect hazard info
    final hazardService = HazardService();
    
    final report = await hazardService.submitHazardReport(
      hazardType: selectedType,
      latitude: _currentLocation.latitude,
      longitude: _currentLocation.longitude,
      description: descriptionController.text,
    );
    
    // Show success message with ML scores
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report submitted! Score: ${report.naiveBayesScore}')),
    );
  },
)
```

### **Task 3: Cache Data for Offline Use**

```dart
import 'package:mobile/core/storage/storage_service.dart';

final storage = StorageService();

// Save evacuation centers
await storage.saveEvacuationCenters(
  centers.map((c) => c.toJson()).toList()
);

// Later, retrieve when offline
final cached = await storage.getEvacuationCenters();
```

---

## 🎓 For Your Thesis

You can now demonstrate:

✅ **Complete mobile architecture** matching backend structure  
✅ **Service layer** with mock data (ready for real API)  
✅ **Offline support** with Hive caching  
✅ **ML integration** (Naive Bayes, Consensus scores returned)  
✅ **Route calculation** with risk levels (Green/Yellow/Red)  
✅ **Role-based access** (Resident vs MDRRMO)  
✅ **Professional folder structure** (core, features, models, data, ui)  

---

## ❓ FAQ

**Q: Will my existing map screen break?**  
A: No! All new code is separate. Your map still works.

**Q: How do I know if mock mode is on?**  
A: Check `lib/core/config/api_config.dart` → `useMockData = true/false`

**Q: Can I test without the backend running?**  
A: Yes! Keep `useMockData = true`. Everything works with mock data.

**Q: How do I display the 3 routes on the map?**  
A: Loop through `routes` list and draw polylines with colors based on `route.riskLevel.value`

**Q: Where are the mock data files?**  
A: In `lib/data/` folder (mock_routes.dart, mock_hazards.dart, etc.)

---

## 🔗 Key Files to Remember

| File | Purpose | When to Edit |
|------|---------|--------------|
| `core/config/api_config.dart` | Toggle mock/real | When switching to backend |
| `features/*/service.dart` | Business logic | Never (unless adding features) |
| `data/mock_*.dart` | Mock data | To customize test data |
| `examples/service_usage_examples.dart` | Copy-paste snippets | When integrating with UI |

---

## ✅ Next Steps

1. ✅ **Run `flutter pub get`** (install dependencies)
2. ✅ **Run `flutter run`** (verify app still works)
3. 🔄 **Optional:** Test services with print statements
4. 🔄 **Optional:** Integrate routing service into map screen
5. 🔄 **Optional:** Add hazard reporting button
6. 🔄 **When backend ready:** Change `useMockData = false`

---

**Status:** All infrastructure complete! Your existing UI works, and new services are ready to use whenever you want.

**Mock Mode:** ✅ Enabled (no backend needed)  
**Real API Mode:** Ready to switch anytime  
**Offline Support:** ✅ Configured  
**Documentation:** ✅ Complete  

🎉 **You're all set!**
