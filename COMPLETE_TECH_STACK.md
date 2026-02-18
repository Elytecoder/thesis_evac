# 🛠️ Complete Software Tools & Technologies Used

**Project:** AI-Powered Mobile Evacuation Routing Application for Bulan, Sorsogon

---

## 📱 Mobile Application (Frontend)

### 1. **Flutter Framework**
- **Version:** Latest stable
- **Language:** Dart
- **Purpose:** Cross-platform mobile app development
- **Why Flutter:**
  - ✅ Single codebase for Android & iOS
  - ✅ Fast development with hot reload
  - ✅ Beautiful, native-like UI
  - ✅ Excellent performance
  - ✅ Rich ecosystem of packages
  - ✅ Strong community support

---

### 2. **Flutter Packages/Dependencies**

#### **Networking & API Communication**
1. **`dio` (v5.4.0)**
   - HTTP client for API calls
   - Better error handling than basic http package
   - Supports interceptors for token management
   - Timeout configuration
   
2. **`http` (v1.2.0)**
   - Used specifically for OSRM API calls
   - Simple, lightweight HTTP requests

#### **Maps & Location**
3. **`flutter_map` (v6.1.0)**
   - Interactive map display
   - Based on Leaflet.js
   - Supports custom markers, polylines
   - Works with OpenStreetMap tiles
   
4. **`latlong2` (v0.9.0)**
   - Geographic coordinate calculations
   - Distance calculations
   - Works with flutter_map
   
5. **`geolocator` (v10.1.0)**
   - GPS location tracking
   - Real-time user positioning
   - Background location updates
   
6. **`permission_handler` (v11.2.0)**
   - Request location permissions
   - Handle runtime permissions on Android/iOS

#### **Local Storage (Offline Support)**
7. **`hive` (v2.2.3)**
   - Fast, lightweight NoSQL database
   - Offline data caching
   - Stores routes, evacuation centers, baseline hazards
   - **Why Hive over alternatives:**
     - ✅ Faster than SQLite for key-value storage
     - ✅ No native dependencies
     - ✅ Type-safe
     - ✅ Perfect for caching JSON data
   
8. **`hive_flutter` (v1.1.0)**
   - Hive integration for Flutter
   - Handles initialization
   
9. **`path_provider` (v2.1.2)**
   - Get device storage paths
   - Required for Hive initialization
   
10. **`shared_preferences` (v2.2.2)**
    - Simple key-value storage
    - Stores auth tokens
    - User session data

#### **Media & Files**
11. **`image_picker` (v1.0.7)**
    - Capture photos/videos
    - Select from gallery
    - For hazard report media uploads

#### **State Management**
12. **Built-in StatefulWidget**
    - Simple, effective for this app size
    - No need for complex state management (Provider/Riverpod) yet

---

## 🌐 Backend (API Server)

### 3. **Django Framework**
- **Version:** 4.2+
- **Language:** Python 3.10+
- **Purpose:** RESTful API backend, data processing
- **Why Django:**
  - ✅ "Batteries included" - comes with everything needed
  - ✅ Excellent ORM for database operations
  - ✅ Built-in admin panel for MDRRMO
  - ✅ Strong security features
  - ✅ Perfect for ML integration (Python-based)
  - ✅ Mature, well-documented framework

---

### 4. **Django REST Framework (DRF)**
- **Purpose:** Build RESTful APIs
- **Why DRF:**
  - ✅ Serializers for data validation
  - ✅ ViewSets for rapid API development
  - ✅ Authentication/permissions built-in
  - ✅ Browsable API for testing
  - ✅ Industry standard for Django APIs

---

## 🗄️ Database

### 5. **SQLite (Development/Demo)**
- **Purpose:** Relational database for backend
- **Current Use:** Development and demo phase
- **Why SQLite:**
  - ✅ **Zero configuration** - no server setup needed
  - ✅ **File-based** - entire database in one file
  - ✅ **Perfect for development** and prototyping
  - ✅ **Portable** - easy to backup and move
  - ✅ **Built into Python/Django** - no additional installation
  - ✅ **Sufficient for thesis/demo** purposes

**Database Schema:**
```
Tables:
- users (id, username, email, password, role, full_name, phone)
- evacuation_centers (id, name, latitude, longitude, description, barangay, address, contact_number, status)
- hazard_reports (id, user_id, hazard_type, latitude, longitude, description, photo_url, video_url, status, naive_bayes_score, consensus_score, random_forest_risk, created_at, admin_comment)
- baseline_hazards (id, hazard_type, latitude, longitude, severity, date_recorded)
- road_segments (id, start_lat, start_lng, end_lat, end_lng, risk_level, last_updated)
- ml_models (id, model_type, version, trained_at, accuracy, file_path)
```

---

### **Production Database Recommendation (Future):**

**PostgreSQL** (when deploying to production)
- **Why PostgreSQL:**
  - ✅ Production-grade reliability
  - ✅ Better concurrent user handling
  - ✅ Advanced features (PostGIS for geographic data)
  - ✅ Better performance at scale
  - ✅ Supports large datasets
  - ✅ ACID compliant
  
**Migration Path:**
```bash
# Easy migration from SQLite to PostgreSQL
1. Export data from SQLite
2. Update Django settings.py
3. Run migrations
4. Import data to PostgreSQL
```

---

## 🤖 Machine Learning & AI

### 6. **Scikit-learn (sklearn)**
- **Purpose:** ML model training and prediction
- **Models Used:**

#### **a) Naive Bayes Classifier**
- **Purpose:** Validate hazard report authenticity
- **Input:** Report text, location, time, user history
- **Output:** Confidence score (0.0 - 1.0)
- **Why Naive Bayes:**
  - ✅ Fast training and prediction
  - ✅ Works well with text classification
  - ✅ Low computational requirements
  - ✅ Good for real-time validation

#### **b) Random Forest Classifier**
- **Purpose:** Predict road risk levels
- **Input:** Historical hazard data, weather, location features
- **Output:** Risk level (Low/Medium/High)
- **Why Random Forest:**
  - ✅ High accuracy
  - ✅ Handles non-linear relationships
  - ✅ Resistant to overfitting
  - ✅ Feature importance analysis

#### **c) Consensus Algorithm (Custom)**
- **Purpose:** Aggregate multiple user reports
- **Input:** Multiple reports for same location
- **Output:** Consensus confidence score
- **Why Custom Algorithm:**
  - ✅ Specific to crowdsourced data
  - ✅ Weighs user reliability
  - ✅ Handles conflicting reports

### 7. **NumPy**
- **Purpose:** Numerical computations for ML
- **Used for:** Matrix operations, data preprocessing

### 8. **Pandas**
- **Purpose:** Data manipulation and analysis
- **Used for:** Processing training datasets, feature engineering

---

## 🗺️ Routing & Maps

### 9. **OSRM (OpenStreetMap Routing Machine)**
- **API:** https://router.project-osrm.org
- **Purpose:** Real road-following route calculation
- **Why OSRM:**
  - ✅ **Free and open-source**
  - ✅ **Fast routing** - milliseconds response time
  - ✅ **Accurate** - uses actual OpenStreetMap road data
  - ✅ **Multiple alternatives** - provides 2-3 route options
  - ✅ **Production-ready** - used by major companies
  - ✅ **No API key required** (public instance)

**Features:**
- Turn-by-turn directions
- Alternative routes
- Distance and duration calculation
- GeoJSON geometry output

---

### 10. **OpenStreetMap (OSM)**
- **Purpose:** Map tiles and geographic data
- **Why OpenStreetMap:**
  - ✅ **Free** - no usage fees or API keys
  - ✅ **Detailed** - community-maintained road data
  - ✅ **Open data** - can download and host locally if needed
  - ✅ **Global coverage** - includes Bulan, Sorsogon
  - ✅ **Up-to-date** - frequently updated by contributors

**Tile Server:** `https://tile.openstreetmap.org/{z}/{x}/{y}.png`

---

## 🧮 Pathfinding Algorithm

### 11. **Modified Dijkstra's Algorithm**
- **Purpose:** Calculate safest evacuation routes
- **Modification:** Risk-weighted edge costs
- **Implementation:** Django backend (Python)
- **Why Modified Dijkstra:**
  - ✅ Proven shortest-path algorithm
  - ✅ Customizable cost function (distance + risk)
  - ✅ Guarantees optimal path
  - ✅ Efficient for road networks

**Cost Formula:**
```python
cost = distance + (risk_level * weight_factor)
```

---

## 📦 Build Tools & Environment

### 12. **Android Studio / Android SDK**
- **Purpose:** Android app compilation
- **Components:**
  - Android Gradle Plugin (AGP) 8.3.0
  - Gradle 8.4
  - Kotlin 1.9.22
  - Android SDK 33+ (Android 13+)

### 13. **Git**
- **Purpose:** Version control
- **Used for:** Code management, collaboration

### 14. **Visual Studio Code / Cursor IDE**
- **Purpose:** Code editor
- **Extensions:** Flutter, Dart

---

## 🔐 Security & Authentication

### 15. **JWT (JSON Web Tokens)**
- **Purpose:** Stateless authentication
- **Storage:** SharedPreferences (mobile)
- **Why JWT:**
  - ✅ Stateless - no server session storage
  - ✅ Secure - signed tokens
  - ✅ Mobile-friendly
  - ✅ Standard in REST APIs

### 16. **Django Authentication System**
- **Purpose:** User management
- **Features:**
  - Password hashing (PBKDF2)
  - Session management
  - Role-based access control (RBAC)

---

## 📊 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Mobile App (Flutter)                     │
├─────────────────────────────────────────────────────────────┤
│  - UI Layer (Screens, Widgets)                              │
│  - Service Layer (API calls, business logic)                │
│  - Storage Layer (Hive for offline, SharedPreferences)      │
└───────────────────┬─────────────────────────────────────────┘
                    │ HTTP/REST API
                    ↓
┌─────────────────────────────────────────────────────────────┐
│                  Backend (Django + DRF)                     │
├─────────────────────────────────────────────────────────────┤
│  - API Endpoints (ViewSets, Serializers)                    │
│  - Business Logic (Routing, ML prediction)                  │
│  - ORM (Database access)                                    │
└───────────────────┬─────────────────────────────────────────┘
                    │ SQL Queries
                    ↓
┌─────────────────────────────────────────────────────────────┐
│                    Database (SQLite)                        │
├─────────────────────────────────────────────────────────────┤
│  - Users, Reports, Centers, Roads, Hazards                  │
└─────────────────────────────────────────────────────────────┘

External Services:
┌────────────────┐        ┌──────────────────┐
│  OSRM API      │◄───────┤  Backend         │
│  (Routing)     │        └──────────────────┘
└────────────────┘

┌────────────────┐        ┌──────────────────┐
│  OpenStreetMap │◄───────┤  Mobile App      │
│  (Map Tiles)   │        └──────────────────┘
└────────────────┘
```

---

## 🌐 Offline Support Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Hive Local Storage                  │
├─────────────────────────────────────────────────────────┤
│  Box: evacuation_centers                                │
│  Box: baseline_hazards                                  │
│  Box: road_segments                                     │
│  Box: calculated_routes (cached from OSRM)             │
│  Box: queued_hazard_reports (pending sync)             │
└─────────────────────────────────────────────────────────┘

Online Mode:
1. Fetch from API → Cache in Hive → Use data

Offline Mode:
1. Check Hive cache → Use cached data

Auto-Sync:
1. Detect internet connection
2. Sync queued reports to backend
3. Update cached data
```

---

## 📈 Why This Tech Stack?

### **1. Cost-Effective**
- ✅ All free and open-source tools
- ✅ No licensing fees
- ✅ Can run on minimal hardware

### **2. Scalable**
- ✅ Easy to migrate from SQLite to PostgreSQL
- ✅ Django handles high traffic well
- ✅ Can deploy to cloud (AWS, Google Cloud, Heroku)

### **3. Maintainable**
- ✅ Popular technologies with good documentation
- ✅ Large communities for support
- ✅ Easy to find developers familiar with these tools

### **4. Suitable for Thesis**
- ✅ Well-documented for academic writing
- ✅ Established methodologies
- ✅ Proven in production systems

### **5. Future-Proof**
- ✅ Active development and updates
- ✅ Modern best practices
- ✅ Can evolve with project needs

---

## 🔄 Development vs Production Setup

### **Current (Development/Thesis)**
- SQLite database
- Public OSRM API
- Public OpenStreetMap tiles
- Mock data for testing
- Local development server

### **Future (Production)**
- PostgreSQL database
- Self-hosted OSRM server (for reliability)
- Tile caching server
- Real hazard data
- Cloud deployment (AWS/Google Cloud)
- Load balancer
- CDN for map tiles
- Monitoring and logging

---

## 📚 Summary Table

| Category | Tool | Purpose | Why Chosen |
|----------|------|---------|------------|
| **Mobile Framework** | Flutter/Dart | Cross-platform app | Fast development, beautiful UI |
| **Mobile Maps** | flutter_map + OSM | Map display | Free, customizable |
| **Mobile Location** | Geolocator | GPS tracking | Accurate, reliable |
| **Mobile Storage** | Hive | Offline cache | Fast, lightweight |
| **Mobile Auth** | SharedPreferences | Token storage | Simple, secure |
| **Backend Framework** | Django | API server | Batteries-included, Python-based |
| **API Framework** | Django REST Framework | REST API | Industry standard |
| **Database (Dev)** | SQLite | Data storage | Zero setup, portable |
| **Database (Prod)** | PostgreSQL | Data storage | Production-grade |
| **ML Library** | Scikit-learn | AI models | Easy to use, powerful |
| **Routing API** | OSRM | Road-following routes | Free, fast, accurate |
| **Map Data** | OpenStreetMap | Geographic data | Free, detailed |
| **Algorithm** | Modified Dijkstra | Safest path | Proven, customizable |
| **Build Tool** | Gradle | Android compilation | Android standard |

---

## 🎯 Key Advantages of This Stack

1. **Zero Cost** - All tools are free and open-source
2. **Offline-First** - Works without internet using Hive cache
3. **Real-Time** - Fast routing and location updates
4. **Scalable** - Can grow from thesis to production
5. **AI-Powered** - Multiple ML models for intelligent decisions
6. **Cross-Platform** - Single codebase for Android & iOS
7. **Well-Documented** - Easy to write thesis documentation
8. **Industry-Standard** - Technologies used in real-world apps

---

**Total Technologies:** 16+ tools working together seamlessly! 🚀
