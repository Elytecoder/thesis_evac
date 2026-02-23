# 📚 Simple Guide: Mock Data, Real Data, Caching & Offline Features

**For: Someone with Little Programming Knowledge**

---

## 🎯 Table of Contents
1. [What is Mock Data? (Current System)](#1-what-is-mock-data)
2. [How to Add Real MDRRMO Data](#2-how-to-add-real-mdrrmo-data)
3. [How Caching Works](#3-how-caching-works)
4. [How Offline Mode Works](#4-how-offline-mode-works)
5. [How Sync Works](#5-how-sync-works)
6. [Files and Folders Guide](#6-files-and-folders-guide)

---

## 1. What is Mock Data?

### 📖 Simple Explanation

**Mock data** = **Fake/Dummy/Sample data** that looks like real data but is hardcoded (written directly in the code).

Think of it like **placeholder images** in a website template before you add your own photos.

### ❓ Why Are We Using Mock Data?

Because you **don't have real MDRRMO data yet**, we created fake data so you can:
- ✅ See how the app works
- ✅ Test all features
- ✅ Show it in your thesis defense
- ✅ Demonstrate to MDRRMO what the system can do

---

### 📦 What Mock Data Do We Have?

#### **1. Mock Evacuation Centers**
**File:** `mobile/lib/data/mock_evacuation_centers.dart`

```dart
// This is FAKE data - 5 imaginary evacuation centers
EvacuationCenter(
  id: 1,
  name: 'Bulan Gymnasium',  // Made-up name
  latitude: 12.6699,         // Approximate location in Bulan
  longitude: 123.8758,
  description: 'Main evacuation center with medical facilities',
)
```

**What it represents:**
- 5 evacuation centers in Bulan, Sorsogon
- Each has: name, location (GPS), description
- These are **imaginary** but realistic

---

#### **2. Mock Users**
**File:** `mobile/lib/data/mock_users.dart`

```dart
// FAKE users for testing
Resident User:
- Email: resident@test.com
- Password: password123

Admin User (MDRRMO):
- Email: mdrrmo@bulan.gov.ph
- Password: mdrrmo2024
```

**What it represents:**
- Sample accounts for testing login
- One regular resident, one MDRRMO admin
- In real system, these will be real MDRRMO staff and residents

---

#### **3. Mock Hazard Reports**
**File:** `mobile/lib/features/admin/admin_mock_service.dart`

```dart
// FAKE hazard reports
HazardReport(
  id: 1,
  hazardType: 'flooded_road',
  latitude: 12.6700,
  longitude: 123.8755,
  description: 'Severe flooding on main highway near market',
  status: 'pending',
  naiveBayesScore: 0.92,  // Fake AI confidence score
)
```

**What it represents:**
- Sample hazard reports from residents
- Includes GPS location, description, type
- AI scores (fake numbers to show how it would look)

---

#### **4. Mock Routes**
**Currently NOT used** - We use **OSRM (real routing)** instead!

The app actually calls a real routing service (OSRM) that uses real OpenStreetMap roads. So routes are **already real**, not mock!

---

### 🔄 How the App Currently Works (With Mock Data)

```
User Opens App
      ↓
Logs in with mock account (resident@test.com)
      ↓
App loads mock evacuation centers from code file
      ↓
User selects a center
      ↓
App calls REAL OSRM API to get routes (not mock!)
      ↓
Routes are displayed following real roads
```

---

## 2. How to Add Real MDRRMO Data

### 📥 When You Get Real Data from MDRRMO

Let's say MDRRMO gives you an **Excel file** or **CSV file** with real evacuation centers:

```
Name                        | Latitude  | Longitude | Barangay | Address
----------------------------|-----------|-----------|----------|------------------
San Pascual Elementary      | 12.6705   | 123.8762  | Zone 1   | Barangay Rd...
Bulan Town Hall            | 12.6698   | 123.8755  | Zone 2   | Municipal St...
...
```

---

### 🔧 Step-by-Step: Adding Real Data

#### **Option 1: Simple Way (For Testing)**

**Update the mock data file directly:**

**File to Edit:** `mobile/lib/data/mock_evacuation_centers.dart`

**What to do:**
1. Open the file
2. Delete the fake centers
3. Add real centers from MDRRMO

**Example:**

```dart
// Before (FAKE)
EvacuationCenter(
  id: 1,
  name: 'Bulan Gymnasium',  // Made up
  latitude: 12.6699,
  ...
)

// After (REAL DATA from MDRRMO)
EvacuationCenter(
  id: 1,
  name: 'San Pascual Elementary School',  // Real name from MDRRMO
  latitude: 12.6705,  // Real GPS from MDRRMO
  longitude: 123.8762,  // Real GPS from MDRRMO
  description: 'Primary evacuation center for Zone 1',  // Real info
  barangay: 'San Pascual',
  address: 'Barangay Road, San Pascual',
  contactNumber: '09XX-XXX-XXXX',
)
```

**Save the file** → App now uses real data!

---

#### **Option 2: Proper Way (Database)**

**For production/deployment, data should go in the backend database.**

**Steps:**

1. **Prepare Data File**
   - Get Excel/CSV from MDRRMO
   - Convert to CSV format if not already

2. **Create Database Import Script**
   - **File:** `backend/scripts/import_evacuation_centers.py`
   - This script reads CSV and adds to database

```python
# Simple example script
import csv
import django

# Read CSV file from MDRRMO
with open('mdrrmo_evacuation_centers.csv', 'r') as file:
    reader = csv.DictReader(file)
    
    for row in reader:
        # Create database entry for each center
        EvacuationCenter.objects.create(
            name=row['Name'],
            latitude=float(row['Latitude']),
            longitude=float(row['Longitude']),
            barangay=row['Barangay'],
            address=row['Address'],
            contact_number=row['Contact'],
        )
```

3. **Run the Script**
   ```bash
   python backend/scripts/import_evacuation_centers.py
   ```

4. **Turn OFF Mock Mode**
   - **File:** `mobile/lib/core/config/api_config.dart`
   - Change `useMockData = true` to `useMockData = false`

```dart
// Before
static const bool useMockData = true;  // Using fake data

// After
static const bool useMockData = false;  // Using real database
```

5. **Mobile app now fetches from real database!**

---

### 📊 Types of Real Data You'll Need from MDRRMO

| Data Type | What You Need | File Format | Where It Goes |
|-----------|---------------|-------------|---------------|
| **Evacuation Centers** | Name, GPS, Contact, Capacity | Excel/CSV | Database table: `evacuation_centers` |
| **Historical Hazards** | Type, Location, Date, Severity | Excel/CSV | Database table: `baseline_hazards` |
| **Road Data** | Road names, GPS coordinates | CSV/GeoJSON | Database table: `road_segments` |
| **User Accounts** | MDRRMO staff names, emails | Excel/CSV | Database table: `users` |

---

## 3. How Caching Works

### 🤔 What is Caching?

**Cache** = **Temporary storage** of data on your phone so you don't have to download it again.

**Real-life analogy:**
- Downloading a song (slow, uses internet)
- Playing the downloaded song offline (fast, no internet needed)

---

### 📱 How Caching Works in This App

```
┌─────────────────────────────────────────────────┐
│           When You Have Internet                │
└─────────────────────────────────────────────────┘

Step 1: Open app
Step 2: App downloads data from server
Step 3: App SAVES a copy on your phone (cache)
Step 4: App shows data
```

```
┌─────────────────────────────────────────────────┐
│         When You DON'T Have Internet            │
└─────────────────────────────────────────────────┘

Step 1: Open app
Step 2: App checks: "Is there saved data on phone?"
Step 3: App uses the SAVED copy (cache)
Step 4: App shows data (even without internet!)
```

---

### 💾 What Gets Cached (Saved on Phone)?

1. **Evacuation Centers**
   - All centers are saved when you first open the app
   - Updated every 24 hours (when online)

2. **Calculated Routes**
   - When you get directions to a center, the route is saved
   - Next time (even offline), same route loads instantly

3. **Baseline Hazards**
   - Historical hazard data from MDRRMO
   - Used by AI to predict risks

4. **Road Risk Levels**
   - Which roads are safe/dangerous
   - Updated when new reports come in

---

### 📂 Where is Cache Stored?

**Storage Technology:** **Hive** (a local phone database)

Think of Hive as **small filing cabinets** on your phone:

```
Your Phone Storage
├── Hive Database (Cache)
│   ├── 📁 Box: "evacuation_centers"
│   │   └── [All 5+ centers saved here]
│   ├── 📁 Box: "baseline_hazards" 
│   │   └── [Historical hazards saved here]
│   ├── 📁 Box: "calculated_routes"
│   │   └── [Routes you've used before]
│   └── 📁 Box: "queued_hazard_reports"
│       └── [Reports waiting to be sent]
```

**File Location:** `mobile/lib/core/storage/storage_service.dart`

---

### ⏰ Cache Expiration

**Question:** How long does cached data stay?

**Answer:** Depends on the data type:

| Data Type | Cache Duration | Why? |
|-----------|----------------|------|
| Evacuation Centers | 7 days | Centers don't change often |
| Routes | 3 days | Roads may get blocked |
| Hazard Reports | 1 day | Hazards change frequently |

**What happens after expiration?**
- App tries to download fresh data
- If offline, keeps using old cache

---

### 🔄 Example: Caching in Action

**Scenario 1: First Time User (With Internet)**

```
User: Opens app for first time
App: "No cache found, downloading..."
App: Downloads 5 evacuation centers from server
App: Saves them in Hive cache
App: Shows them to user
User: Sees all 5 centers ✅
```

**Scenario 2: Repeat User (With Internet)**

```
User: Opens app again tomorrow
App: "Cache exists, but let me check for updates..."
App: Downloads latest data from server
App: Updates cache
App: Shows updated data
User: Sees all centers ✅
```

**Scenario 3: Offline User**

```
User: Opens app in area with no signal
App: "No internet, checking cache..."
App: Finds cached centers from yesterday
App: Shows cached data
User: Sees all centers (from cache) ✅
```

**Scenario 4: Offline, No Cache**

```
User: Opens app for first time, no internet
App: "No internet AND no cache..."
App: Shows error: "Please connect to internet for first-time setup"
User: Sees error message ❌
```

---

## 4. How Offline Mode Works

### 🌐 What is Offline Mode?

**Offline Mode** = Using the app **without internet connection**

**What works offline:**
- ✅ View cached evacuation centers
- ✅ View cached routes (you've used before)
- ✅ View the map (if tiles are cached by OS)
- ✅ Report hazards (saved locally, sent later)
- ✅ View your profile

**What doesn't work offline:**
- ❌ Get NEW routes (OSRM needs internet)
- ❌ See new hazard reports from others
- ❌ Login/Register (needs server)
- ❌ See live updates

---

### 🚫 The Challenge: What If User Reports Hazard Offline?

**Problem:**
- User sees flooding
- Reports it in app
- But phone has no internet
- Report cannot be sent to server

**Solution: Queue System**

```
User Reports Hazard (Offline)
      ↓
App saves report in "queue" (waiting list)
      ↓
Report stored in Hive box: "queued_hazard_reports"
      ↓
User continues using app
      ↓
Later, phone gets internet
      ↓
App detects internet is back
      ↓
App automatically sends all queued reports
      ↓
Server receives reports
      ↓
Queue is cleared
```

---

### 📂 Files Handling Offline Mode

#### **1. Storage Service** (Manages cache)
**File:** `mobile/lib/core/storage/storage_service.dart`

**What it does:**
- Saves data to Hive
- Loads data from Hive
- Checks if cache is expired

```dart
// Simplified example
class StorageService {
  // Save evacuation centers to cache
  saveEvacuationCenters(List<Center> centers) {
    // Store in Hive box
  }
  
  // Load evacuation centers from cache
  getEvacuationCenters() {
    // Retrieve from Hive box
  }
}
```

---

#### **2. Hazard Service** (Manages offline reports)
**File:** `mobile/lib/features/hazards/hazard_service.dart`

**What it does:**
- Tries to send report to server
- If offline, saves to queue
- Auto-syncs when internet returns

```dart
// Simplified example
submitHazardReport(report) {
  if (hasInternet) {
    // Send to server immediately
    sendToServer(report);
  } else {
    // Save to queue for later
    saveToQueue(report);
  }
}

// When internet comes back
syncQueuedReports() {
  // Get all reports in queue
  // Send each one to server
  // Clear queue when done
}
```

---

#### **3. Routing Service** (Caches routes)
**File:** `mobile/lib/features/routing/routing_service.dart`

**What it does:**
- Calls OSRM for new routes
- Saves routes to cache
- Uses cached routes when offline

```dart
// Simplified example
calculateRoutes(start, end) {
  try {
    // Try to get route from OSRM (needs internet)
    route = getFromOSRM(start, end);
    
    // Save to cache
    saveToCache(route);
    
    return route;
  } catch (noInternet) {
    // OSRM failed, try cache
    route = loadFromCache(start, end);
    
    if (route exists) {
      return cachedRoute;
    } else {
      // No cache, show error
      throw "No internet and no cached route";
    }
  }
}
```

---

## 5. How Sync Works

### 🔄 What is "Sync"?

**Sync** (Synchronization) = **Matching data** between phone and server

**Like:** Syncing your contacts between phone and Google account

---

### 📤 Types of Sync in This App

#### **1. Download Sync (Server → Phone)**

**When it happens:**
- App starts
- User pulls down to refresh
- Every 24 hours (automatic)

**What gets synced:**
- Latest evacuation centers
- New baseline hazards
- Road risk updates
- MDRRMO announcements (future)

```
Server (has latest data)
      ↓
   Download
      ↓
Phone Cache (now updated)
```

---

#### **2. Upload Sync (Phone → Server)**

**When it happens:**
- User submits hazard report (if online)
- Internet connection restored (if offline)
- Manual "Sync Now" button in settings

**What gets synced:**
- Queued hazard reports
- User profile updates
- App usage logs (future)

```
Phone (has queued reports)
      ↓
   Upload
      ↓
Server (receives reports)
```

---

### 🔄 Sync Process Explained Simply

**Scenario: User Reports Hazard Offline, Then Goes Online**

```
┌────────────────────────────────────────┐
│  9:00 AM - User in area with no signal│
└────────────────────────────────────────┘

User: Reports flooding on Main Street
App: "No internet detected"
App: Saves report in queue
Status: ⏳ Waiting to send

┌────────────────────────────────────────┐
│  10:00 AM - User arrives at town       │
│  (Phone gets internet signal)          │
└────────────────────────────────────────┘

App: "Internet detected!"
App: "Checking for queued reports..."
App: "Found 1 report in queue"
App: "Sending to server..."

Server: "Report received!"
Server: "Running AI validation..."
Server: "Notifying MDRRMO..."

App: "Sync complete!"
App: Removes report from queue
Status: ✅ Sent successfully

User: Sees "Report submitted" notification
```

---

### 🔔 Auto-Sync vs Manual Sync

#### **Auto-Sync** (Automatic)
- Happens in background
- You don't need to do anything
- Triggers:
  - App detects internet after being offline
  - App starts
  - Every 24 hours

#### **Manual Sync** (You press a button)
- In Settings screen: "Sync Now" button
- Useful when:
  - You want to force a refresh
  - You know there's new data
  - Troubleshooting connection issues

---

### 📂 Files Handling Sync

**File:** `mobile/lib/features/hazards/hazard_service.dart`

```dart
// Auto-sync function (simplified)
class HazardService {
  // This runs when internet is detected
  Future<void> syncQueuedReports() async {
    // 1. Get all reports in queue
    List<Report> queuedReports = await getQueue();
    
    if (queuedReports.isEmpty) {
      print("Nothing to sync");
      return;
    }
    
    // 2. Send each report
    for (var report in queuedReports) {
      try {
        // Send to server
        await sendToServer(report);
        
        // Remove from queue
        await removeFromQueue(report);
        
        print("Synced: ${report.description}");
      } catch (error) {
        print("Failed to sync: ${report.description}");
        // Keep in queue, try again later
      }
    }
    
    print("Sync complete!");
  }
}
```

---

## 6. Files and Folders Guide

### 📁 Complete File Structure (Simplified)

```
thesis_evac/
│
├── mobile/                          ← FLUTTER APP
│   ├── lib/
│   │   ├── core/                    ← Core functionality
│   │   │   ├── config/
│   │   │   │   └── api_config.dart           ← 🔑 TURN MOCK MODE ON/OFF HERE
│   │   │   ├── network/
│   │   │   │   └── api_client.dart           ← Handles all server requests
│   │   │   └── storage/
│   │   │       └── storage_service.dart      ← 💾 CACHING HAPPENS HERE
│   │   │
│   │   ├── data/                    ← Mock/Fake Data
│   │   │   ├── mock_evacuation_centers.dart  ← 📌 FAKE CENTERS (Replace with real)
│   │   │   ├── mock_users.dart               ← 👤 FAKE USERS
│   │   │   └── mock_hazards.dart             ← ⚠️ FAKE HAZARDS
│   │   │
│   │   ├── features/                ← Main features
│   │   │   ├── authentication/
│   │   │   │   └── auth_service.dart         ← Login/Register logic
│   │   │   ├── hazards/
│   │   │   │   └── hazard_service.dart       ← 📤 OFFLINE QUEUE & SYNC HERE
│   │   │   └── routing/
│   │   │       └── routing_service.dart      ← 🗺️ ROUTE CACHING HERE
│   │   │
│   │   ├── models/                  ← Data structures
│   │   │   ├── evacuation_center.dart
│   │   │   ├── hazard_report.dart
│   │   │   ├── user.dart
│   │   │   └── route.dart
│   │   │
│   │   └── ui/                      ← Screens (what you see)
│   │       ├── screens/
│   │       └── admin/
│   │
│   └── pubspec.yaml                 ← Dependencies list
│
└── backend/                         ← DJANGO SERVER
    ├── api/
    │   ├── models.py                ← 🗄️ DATABASE STRUCTURE
    │   ├── views.py                 ← API endpoints
    │   └── serializers.py           ← Data validation
    │
    ├── scripts/                     ← Utility scripts
    │   └── import_evacuation_centers.py  ← 📥 IMPORT REAL DATA HERE
    │
    └── db.sqlite3                   ← 💾 DATABASE FILE (All real data stored here)
```

---

### 🗂️ Detailed File Descriptions

#### **🔑 Most Important Files**

---

### **1. `api_config.dart` - The Master Switch**

**Location:** `mobile/lib/core/config/api_config.dart`

**Purpose:** Controls whether app uses MOCK data or REAL data

**What's inside:**
```dart
class ApiConfig {
  // 🔑 THE SWITCH - Change this!
  static const bool useMockData = true;  // true = mock, false = real
  
  // Server address
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  
  // API endpoints
  static const String evacuationCentersEndpoint = '/evacuation-centers/';
  static const String reportHazardEndpoint = '/report-hazard/';
  ...
}
```

**When to change:**
- Keep `true` during development/testing
- Change to `false` when you have real data and backend server running

---

### **2. `storage_service.dart` - Cache Manager**

**Location:** `mobile/lib/core/storage/storage_service.dart`

**Purpose:** Saves and loads data from phone storage (Hive)

**Key functions:**
```dart
// Save evacuation centers to cache
saveEvacuationCenters(centers) { ... }

// Load evacuation centers from cache
getEvacuationCenters() { ... }

// Save routes to cache (for offline)
saveCalculatedRoutes(routeKey, routes) { ... }

// Get cached routes
getCalculatedRoutes(routeKey) { ... }

// Clear old cache (expired data)
clearOldRouteCaches() { ... }
```

**Think of it as:** The filing cabinet manager for your phone

---

### **3. `hazard_service.dart` - Report Handler & Sync**

**Location:** `mobile/lib/features/hazards/hazard_service.dart`

**Purpose:** 
- Submit hazard reports
- Queue reports when offline
- Sync reports when online

**Key functions:**
```dart
// Submit report (online or offline)
submitHazardReport(report) {
  if (online) {
    sendToServer(report);
  } else {
    queueForLater(report);
  }
}

// Sync all queued reports
syncQueuedReports() {
  // Send all reports in queue to server
}
```

**This is where:** Offline → Online magic happens

---

### **4. `routing_service.dart` - Route Calculator & Cache**

**Location:** `mobile/lib/features/routing/routing_service.dart`

**Purpose:**
- Calculate routes using OSRM
- Cache routes for offline use
- Use cached routes when offline

**Key functions:**
```dart
// Calculate routes
calculateRoutes(start, end) {
  try {
    // Try OSRM (needs internet)
    routes = getFromOSRM(start, end);
    cacheRoutes(routes);
    return routes;
  } catch {
    // OSRM failed, try cache
    return getCachedRoutes(start, end);
  }
}

// Cache routes
_cacheRoutes(routeKey, routes) { ... }

// Get cached routes
_getCachedRoutes(routeKey) { ... }
```

---

### **5. Mock Data Files - Replace These With Real Data**

#### **`mock_evacuation_centers.dart`**
**Location:** `mobile/lib/data/mock_evacuation_centers.dart`

**Current content:** 5 fake evacuation centers

**How to update with real MDRRMO data:**
```dart
// Current (FAKE)
List<EvacuationCenter> getMockEvacuationCenters() {
  return [
    EvacuationCenter(
      id: 1,
      name: 'Bulan Gymnasium',  // ← Fake name
      latitude: 12.6699,         // ← Approximate GPS
      ...
    ),
  ];
}

// Updated (REAL DATA from MDRRMO)
List<EvacuationCenter> getMockEvacuationCenters() {
  return [
    EvacuationCenter(
      id: 1,
      name: 'San Pascual Elementary School',  // ← Real name from MDRRMO
      latitude: 12.6705,                      // ← Real GPS from MDRRMO
      longitude: 123.8762,
      barangay: 'San Pascual',
      address: 'Barangay Road, San Pascual',
      contactNumber: '09XX-XXX-XXXX',
      description: 'Primary evacuation center, capacity 500',
    ),
    // Add more real centers from MDRRMO...
  ];
}
```

---

#### **`mock_users.dart`**
**Location:** `mobile/lib/data/mock_users.dart`

**Current content:** 2 fake users (resident + admin)

**How to update:**
```dart
// Add real MDRRMO staff
User getMdrrmoUser() {
  return User(
    id: 1,
    username: 'mdrrmo_admin',
    email: 'admin@bulan-mdrrmo.gov.ph',  // Real email
    fullName: 'Juan dela Cruz',          // Real name
    role: UserRole.mdrrmo,
    phone: '09XX-XXX-XXXX',              // Real contact
  );
}
```

---

### **6. Backend Files - Where Real Data Goes**

#### **`models.py` - Database Structure**
**Location:** `backend/api/models.py`

**Purpose:** Defines what data is stored in database

**Example:**
```python
class EvacuationCenter(models.Model):
    name = models.CharField(max_length=200)
    latitude = models.FloatField()
    longitude = models.FloatField()
    barangay = models.CharField(max_length=100)
    address = models.TextField()
    contact_number = models.CharField(max_length=20)
    status = models.CharField(max_length=20, default='active')
```

**Think of it as:** The blueprint for your database tables

---

#### **`db.sqlite3` - The Actual Database**
**Location:** `backend/db.sqlite3`

**Purpose:** Stores ALL real data (when not using mock)

**What's inside:**
- Table: `evacuation_centers`
- Table: `hazard_reports`
- Table: `users`
- Table: `baseline_hazards`
- Table: `road_segments`

**How to view:**
- Use SQLite browser (free software)
- Or Django admin panel: `http://localhost:8000/admin`

---

## 📝 Summary: Mock vs Real Data

### **Current System (Mock Mode)**

```
┌─────────────────────────────────────┐
│         Mobile App (Flutter)        │
├─────────────────────────────────────┤
│  api_config.dart:                   │
│    useMockData = true ✅            │
│                                     │
│  Data comes from:                   │
│    ├── mock_evacuation_centers.dart│
│    ├── mock_users.dart              │
│    └── mock_hazards.dart            │
│                                     │
│  Routing:                           │
│    └── OSRM API (REAL!) ✅         │
└─────────────────────────────────────┘

Backend Server: NOT USED (mock mode)
```

---

### **Future System (Real Mode)**

```
┌─────────────────────────────────────┐
│         Mobile App (Flutter)        │
├─────────────────────────────────────┤
│  api_config.dart:                   │
│    useMockData = false ✅           │
│                                     │
│  Data comes from:                   │
│    └── Backend Server API           │
└──────────────┬──────────────────────┘
               │ HTTP Requests
               ↓
┌─────────────────────────────────────┐
│        Backend Server (Django)      │
├─────────────────────────────────────┤
│  Data comes from:                   │
│    └── db.sqlite3 (Database)        │
│                                     │
│  Database contains:                 │
│    ├── Real MDRRMO evacuation data  │
│    ├── Real user accounts           │
│    ├── Real hazard reports          │
│    └── Real historical data         │
└─────────────────────────────────────┘
```

---

## 🎯 Quick Reference: Where to Find Things

| What You Want | File/Folder |
|---------------|-------------|
| **Turn mock mode ON/OFF** | `mobile/lib/core/config/api_config.dart` |
| **Replace fake evacuation centers** | `mobile/lib/data/mock_evacuation_centers.dart` |
| **Add fake users for testing** | `mobile/lib/data/mock_users.dart` |
| **See how caching works** | `mobile/lib/core/storage/storage_service.dart` |
| **See offline queue logic** | `mobile/lib/features/hazards/hazard_service.dart` |
| **See route caching** | `mobile/lib/features/routing/routing_service.dart` |
| **Import real MDRRMO data** | Create: `backend/scripts/import_data.py` |
| **View real database** | `backend/db.sqlite3` (use SQLite browser) |
| **Database structure** | `backend/api/models.py` |

---

## 🚀 Step-by-Step: From Mock to Real

### **Phase 1: Current (Thesis Demo)**
✅ Use mock data  
✅ Test all features  
✅ Show to MDRRMO  
✅ Present in defense  

### **Phase 2: Getting Real Data**
📋 Get Excel/CSV from MDRRMO with:
  - Evacuation centers list
  - Historical hazard data
  - Road network data
  - MDRRMO staff accounts

### **Phase 3: Import Real Data**
1. Create import script
2. Run script to populate database
3. Verify data in Django admin
4. Test API endpoints

### **Phase 4: Switch to Real Mode**
1. Change `useMockData = true` to `false`
2. Start backend server
3. Mobile app now uses real data
4. Test thoroughly

### **Phase 5: Deploy**
🌐 Host backend on server  
📱 Publish mobile app  
👥 MDRRMO starts using  
📊 Collect real reports  

---

## ❓ Common Questions

**Q: Do I need to code to add real data?**  
A: For small amounts, no - just edit mock files. For large amounts, yes - create import script (we can help).

**Q: Will offline mode work with real data?**  
A: Yes! Caching works the same with mock or real data.

**Q: How much data can be cached?**  
A: Depends on phone storage. Typically 10-50 MB is fine. That's thousands of reports!

**Q: What if user's phone runs out of space?**  
A: App will clear old cache automatically. Critical data (queued reports) is kept.

**Q: Can I test offline mode now?**  
A: Yes! Turn off internet on emulator and try using the app.

**Q: Where are cached files stored physically?**  
A: Android: `/data/data/com.thesis.evacuation.mobile/`  
But Hive manages this automatically, you don't need to access it manually.

---

## 📚 Further Learning

If you want to understand more:

1. **Read these files in order:**
   - `api_config.dart` (simplest)
   - `mock_evacuation_centers.dart` (see mock data structure)
   - `storage_service.dart` (see caching)
   - `hazard_service.dart` (see sync logic)

2. **Try these experiments:**
   - Turn off internet, see what still works
   - Change mock data, see changes in app
   - Clear app data, see cache rebuild

3. **Watch for these console messages:**
   - `"Routes cached successfully"` ← Caching worked
   - `"Using cached routes (offline mode)"` ← Using cache
   - `"Sync complete!"` ← Sync finished

---

**Need help with any of this?** Just ask! 😊

Remember: You don't need to understand all the code. Just know:
- 📁 Where mock data is
- 🔄 How to replace it with real data
- 💾 That caching happens automatically
- 📤 That sync happens automatically

The system handles the complex parts for you!
