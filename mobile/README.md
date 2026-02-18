# Evacuation Route Mobile App

Flutter mobile application for AI-powered evacuation route recommendation.

## 🎉 Current Status: Infrastructure Complete + Map Foundation

**Latest Update:** February 8, 2026

✅ **Phase 1:** Map foundation with mock evacuation centers  
✅ **Phase 2:** Complete service infrastructure with mock data  
🔄 **Phase 3:** Backend integration (ready, toggle available)  

This app now has **complete infrastructure** using **mock data**. All services (authentication, routing, hazards) are implemented and ready to switch to real API calls.

### What's Implemented

✅ **Map Display**
- OpenStreetMap integration via `flutter_map`
- User location tracking with `geolocator`
- Location permission handling with `permission_handler`

✅ **Evacuation Centers**
- Display 3 mock evacuation centers on map
- Interactive markers with tap functionality
- Center details dialog with selection capability

✅ **Service Infrastructure (NEW!)**
- Authentication service (login/register/logout)
- Routing service (calculate routes, get centers)
- Hazard service (report hazards, get baseline data)
- Offline storage with Hive
- API client with error handling

✅ **Data Models**
- User (with roles: resident/mdrrmo)
- Route (with risk levels: Green/Yellow/Red)
- HazardReport (with ML validation scores)
- BaselineHazard (MDRRMO data)
- EvacuationCenter

✅ **Clean Architecture**
- Modular folder structure (`core/`, `features/`, `models/`, `data/`, `ui/`)
- Service layer pattern
- Mock/Real API toggle
- Offline-first ready

### What's NOT Implemented (Yet)

❌ UI integration (services exist but not connected to UI yet)
❌ Authentication screens (service ready, UI pending)
❌ Route display on map (service returns routes, drawing pending)
❌ Hazard reporting UI (service ready, form pending)
❌ Real-time hazard overlay

**Note:** All backend features are ready via services, just need UI integration!

---

## Project Structure

```
mobile/
├── lib/
│   ├── main.dart                           # Entry point (Hive initialized)
│   ├── core/                                # NEW: Infrastructure
│   │   ├── config/
│   │   │   ├── api_config.dart             # API URLs, mock/real toggle
│   │   │   └── storage_config.dart         # Storage configuration
│   │   ├── network/
│   │   │   └── api_client.dart             # Dio HTTP client
│   │   └── storage/
│   │       └── storage_service.dart        # Hive offline storage
│   ├── models/
│   │   ├── evacuation_center.dart          # Data model
│   │   ├── user.dart                        # NEW
│   │   ├── route.dart                       # NEW
│   │   ├── hazard_report.dart               # NEW
│   │   └── baseline_hazard.dart             # NEW
│   ├── data/
│   │   ├── mock_evacuation_centers.dart    # Mock data (temporary)
│   │   ├── mock_routes.dart                 # NEW
│   │   ├── mock_hazards.dart                # NEW
│   │   └── mock_users.dart                  # NEW
│   ├── features/                            # NEW: Service layer
│   │   ├── authentication/
│   │   │   └── auth_service.dart           # Login/Register/Logout
│   │   ├── routing/
│   │   │   └── routing_service.dart        # Calculate routes
│   │   └── hazards/
│   │       └── hazard_service.dart         # Report/View hazards
│   ├── examples/                            # NEW
│   │   └── service_usage_examples.dart     # Copy-paste code snippets
│   ├── test_services.dart                   # NEW: Test all services
│   └── ui/
│       └── screens/
│           └── map_screen.dart             # Main map screen
├── android/
│   └── app/src/main/AndroidManifest.xml    # Location permissions
├── pubspec.yaml                             # Dependencies (UPDATED)
├── README.md                                # This file (UPDATED)
├── BUILD_SUMMARY.md                         # NEW: Complete build summary
├── INFRASTRUCTURE_COMPLETE.md               # NEW: Technical docs
└── QUICK_START.md                           # NEW: Installation guide
```

---

## Dependencies

```yaml
# Map display
flutter_map: ^7.0.2
latlong2: ^0.9.1

# Location services
geolocator: ^12.0.0
permission_handler: ^11.3.1

# API & Network (NEW)
dio: ^5.4.0
http: ^1.2.0

# Local storage - Offline support (NEW)
hive: ^2.2.3
hive_flutter: ^1.1.0
path_provider: ^2.1.0

# State management & utilities (NEW)
shared_preferences: ^2.2.0
```

---

## How to Run

### Prerequisites

1. **Flutter SDK** installed (3.0.0+)
2. **Android Studio** or **VS Code** with Flutter extension
3. **Android Emulator** or physical device connected

### Steps

```powershell
# Navigate to mobile folder
cd c:\Users\elyth\thesis_evac\mobile

# Install dependencies (IMPORTANT: Run this first!)
flutter pub get

# Run on connected device/emulator
flutter run

# Optional: Test all services
# Add this to your main.dart temporarily:
# import 'test_services.dart';
# Then call: testAllServices();
```

### Expected Behavior

**Map Screen:**
1. App opens
2. Requests location permission
3. Map loads with OpenStreetMap tiles
4. Blue marker shows your current location
5. Red markers show 3 evacuation centers
6. Tap a red marker → Dialog appears with center details
7. Click "SELECT THIS CENTER" → Console log prints (routing service exists but not integrated yet)

**Services (Running in Background):**
- ✅ Authentication service ready (call `AuthService().login()`)
- ✅ Routing service ready (call `RoutingService().calculateRoutes()`)
- ✅ Hazard service ready (call `HazardService().submitHazardReport()`)
- ✅ All return mock data (no backend needed)

### Testing Services

To test the new infrastructure:

```dart
// In any widget or screen:
import 'package:mobile/test_services.dart';

// Call this to test all services:
await testAllServices();

// Or test individual services:
final auth = AuthService();
final user = await auth.login('test', 'password');
print('User: ${user.fullName}');
```

Check console for output!

---

## Mock Data

### Evacuation Centers

Located in `lib/data/mock_evacuation_centers.dart`:

1. **Bulan Gymnasium** (12.6699, 123.8758)
2. **Bulan National High School** (12.6720, 123.8770)
3. **Barangay Hall Zone 1** (12.6680, 123.8740)

> **Note:** These coordinates are based on Bulan, Sorsogon, Philippines.

---

## Testing

### On Emulator

```powershell
flutter run
```

Location will use default mock location.

### On Physical Device

1. Enable USB debugging
2. Connect device
3. Run `flutter devices` to verify connection
4. Run `flutter run`

Physical device will use actual GPS location.

---

## Future Implementation (Phase 3)

### Backend Integration

Replace mock data with API calls:

```dart
// CURRENT (Mock)
final centers = getMockEvacuationCenters();

// FUTURE (API)
final response = await http.get(
  Uri.parse('http://backend:8000/api/evacuation-centers/'),
  headers: {'Authorization': 'Token $userToken'},
);
final centers = (response.body as List)
    .map((json) => EvacuationCenter.fromJson(json))
    .toList();
```

### Route Calculation

When user selects a center:

```dart
// POST /api/calculate-route/
final response = await http.post(
  Uri.parse('http://backend:8000/api/calculate-route/'),
  headers: {'Authorization': 'Token $userToken'},
  body: jsonEncode({
    'start_lat': userLocation.latitude,
    'start_lng': userLocation.longitude,
    'evacuation_center_id': selectedCenter.id,
  }),
);

// Receive 3 routes with risk levels
final routes = (response.body['routes'] as List)
    .map((json) => RouteData.fromJson(json))
    .toList();

// Draw routes on map (Green/Yellow/Red)
```

### Offline Storage

Use Hive for caching:

```dart
// Save evacuation centers offline
await Hive.box('centers').put('all', centers);

// Retrieve when offline
final cachedCenters = Hive.box('centers').get('all');
```

---

## Troubleshooting

### "Location Permission Denied"

Enable location in device settings:
- Android: Settings → Apps → Evacuation Route → Permissions → Location

### "Map tiles not loading"

Check internet connection. OpenStreetMap requires active internet.

### "Building with plugins requires symlink support"

Run in PowerShell as Administrator:
```powershell
start ms-settings:developers
```
Enable "Developer Mode" in Windows settings.

---

## Code Quality Notes

- ✅ All classes have documentation comments
- ✅ Future implementation clearly marked with `// FUTURE:` comments
- ✅ No hardcoded API URLs (ready for config file)
- ✅ Proper error handling for permissions and location
- ✅ Clean separation: UI, Models, Data

---

## Next Steps

Once backend is ready:

1. **Add Authentication**
   - Login/Register screens
   - Token storage (secure_storage)
   - Auto-login on app start

2. **Connect APIs**
   - Replace mock evacuation centers
   - Implement route calculation
   - Add hazard reporting UI

3. **Offline Support**
   - Cache evacuation centers with Hive
   - Save route history
   - Offline map tiles

4. **Advanced Features**
   - Real-time hazard overlay
   - Push notifications for new hazards
   - Multi-language support

---

## Architecture Decisions

### Why Flutter?
- Cross-platform (Android/iOS from single codebase)
- Rich map libraries (`flutter_map`)
- Active community and good documentation

### Why `flutter_map`?
- Open-source and free
- Works with OpenStreetMap
- Highly customizable
- No API key required

### Why Mock Data First?
- Allows UI development without waiting for backend
- Easier to test UI logic independently
- Clear separation of concerns

---

## 📚 Documentation

- **BUILD_SUMMARY.md** - Complete infrastructure build summary
- **INFRASTRUCTURE_COMPLETE.md** - Full technical documentation
- **QUICK_START.md** - Installation and usage guide
- **lib/examples/service_usage_examples.dart** - Copy-paste code snippets
- **lib/test_services.dart** - Test all services with mock data

---

**Status:** ✅ Infrastructure Complete - Services ready with mock data, UI integration pending
