# Software Requirements Specification (SRS)
## AI-Powered Mobile Evacuation Routing Application

**Version:** 1.0  
**Date:** February 8, 2026  
**Prepared for:** MDRRMO, Bulan, Sorsogon  
**Prepared by:** Thesis Team  

---

## Document Information

| Document ID | SRS-EVAC-001 |
|-------------|--------------|
| Version | 1.0 |
| Status | Final |
| Last Updated | February 8, 2026 |
| Classification | Public |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Overall Description](#2-overall-description)
3. [System Features](#3-system-features)
4. [External Interface Requirements](#4-external-interface-requirements)
5. [System Architecture](#5-system-architecture)
6. [Functional Requirements](#6-functional-requirements)
7. [Non-Functional Requirements](#7-non-functional-requirements)
8. [Data Requirements](#8-data-requirements)
9. [AI/ML Requirements](#9-aiml-requirements)
10. [Security Requirements](#10-security-requirements)
11. [Performance Requirements](#11-performance-requirements)
12. [Constraints and Assumptions](#12-constraints-and-assumptions)

---

## 1. Introduction

### 1.1 Purpose

This Software Requirements Specification (SRS) document provides a complete description of the AI-Powered Mobile Evacuation Routing Application designed for Bulan, Sorsogon. The system aims to provide residents with intelligent, risk-aware evacuation routes during calamities while enabling MDRRMO to monitor and manage hazard reports efficiently.

### 1.2 Intended Audience

- **MDRRMO Personnel** - System administrators and disaster response coordinators
- **Residents** - Primary end-users requiring evacuation guidance
- **Developers** - Technical team implementing the system
- **Thesis Committee** - Academic evaluators
- **Government Officials** - Decision-makers and stakeholders

### 1.3 Project Scope

The system encompasses:
- Mobile application for Android devices (with iOS compatibility)
- Backend API server for data management
- Machine learning models for risk prediction and validation
- Real-time routing with risk awareness
- Offline capability for disaster scenarios
- MDRRMO administrative dashboard

**Boundaries:**
- Limited to Bulan, Sorsogon municipality
- Does not include weather forecasting
- Does not provide live tracking of emergency vehicles
- Does not replace official MDRRMO communication channels

### 1.4 Definitions, Acronyms, and Abbreviations

| Term | Definition |
|------|------------|
| **MDRRMO** | Municipal Disaster Risk Reduction and Management Office |
| **API** | Application Programming Interface |
| **GPS** | Global Positioning System |
| **AI** | Artificial Intelligence |
| **ML** | Machine Learning |
| **OSRM** | OpenStreetMap Routing Machine |
| **OSM** | OpenStreetMap |
| **REST** | Representational State Transfer |
| **RBAC** | Role-Based Access Control |
| **NB** | Naive Bayes |
| **RF** | Random Forest |
| **SRS** | Software Requirements Specification |

### 1.5 Document Conventions

- **SHALL** - Mandatory requirement
- **SHOULD** - Recommended requirement
- **MAY** - Optional requirement
- **MUST** - Critical requirement
- **REQ-XXX** - Requirement identifier format

### 1.6 References

1. OpenStreetMap Documentation - https://www.openstreetmap.org
2. OSRM API Documentation - http://project-osrm.org
3. Flutter Framework - https://flutter.dev
4. Django Documentation - https://www.djangoproject.com
5. Philippine Disaster Risk Reduction Standards

---

## 2. Overall Description

### 2.1 Product Perspective

The system is a **standalone mobile-first application** integrated with a backend server. It operates within the disaster management ecosystem of Bulan, Sorsogon, complementing existing MDRRMO operations.

**System Context:**

```
┌────────────────────────────────────────────────────────┐
│              External Systems                          │
├────────────────────────────────────────────────────────┤
│  • GPS Satellites (Location Services)                 │
│  • OpenStreetMap Tile Servers (Map Data)              │
│  • OSRM API (Route Calculation)                       │
│  • Mobile Network Providers (Connectivity)            │
└──────────────────┬─────────────────────────────────────┘
                   │
┌──────────────────▼─────────────────────────────────────┐
│         AI-Powered Evacuation Routing System          │
├────────────────────────────────────────────────────────┤
│  Mobile App    │    Backend Server    │   Database    │
│  (Flutter)     │    (Django)          │   (SQLite)    │
└──────────────────┬─────────────────────────────────────┘
                   │
┌──────────────────▼─────────────────────────────────────┐
│                   End Users                            │
├────────────────────────────────────────────────────────┤
│  • Residents (Primary Users)                           │
│  • MDRRMO Personnel (Admin Users)                      │
└────────────────────────────────────────────────────────┘
```

### 2.2 Product Functions

**Primary Functions:**

1. **Evacuation Routing**
   - Calculate risk-aware routes to evacuation centers
   - Provide turn-by-turn navigation guidance
   - Display multiple route alternatives
   - Show real-time hazard locations

2. **Hazard Reporting**
   - Allow residents to report hazards with location
   - Support photo/video uploads
   - Validate reports using AI
   - Queue reports for offline submission

3. **MDRRMO Dashboard**
   - Review and approve hazard reports
   - Monitor evacuation centers
   - View analytics and statistics
   - Manage system data

4. **Offline Operation**
   - Cache evacuation centers
   - Store calculated routes
   - Queue hazard reports
   - Auto-sync when online

### 2.3 User Classes and Characteristics

#### 2.3.1 Resident Users

**Characteristics:**
- Age: 18-70 years
- Tech literacy: Basic to intermediate
- Device: Android smartphones (minimum Android 5.0)
- Usage frequency: During calamities or drills
- Location: Within Bulan, Sorsogon

**Primary Tasks:**
- View evacuation centers
- Get evacuation routes
- Report hazards
- View map

**Expertise Required:** Minimal (must know how to use smartphone apps)

---

#### 2.3.2 MDRRMO Admin Users

**Characteristics:**
- Age: 25-60 years
- Tech literacy: Intermediate to advanced
- Device: Android tablets or smartphones
- Usage frequency: Daily monitoring
- Location: MDRRMO office or field operations

**Primary Tasks:**
- Review hazard reports
- Approve/reject submissions
- Monitor evacuation centers
- View analytics
- Manage system data

**Expertise Required:** Training on system operations and disaster response protocols

---

### 2.4 Operating Environment

**Mobile Application:**
- **Platform:** Android 5.0 (Lollipop) or higher
- **Screen Size:** 4.5" to 7" displays
- **Storage:** Minimum 100 MB available
- **RAM:** Minimum 2 GB
- **Connectivity:** WiFi or mobile data (3G/4G/5G)
- **Sensors:** GPS, Camera (optional)

**Backend Server:**
- **OS:** Linux (Ubuntu 20.04 LTS or higher)
- **Runtime:** Python 3.8+
- **Database:** SQLite 3 (development), PostgreSQL 12+ (production)
- **Web Server:** Gunicorn with Nginx
- **Deployment:** Cloud or on-premise server

**Network Requirements:**
- Minimum bandwidth: 256 Kbps
- Latency: < 500ms for API calls
- Supports intermittent connectivity

### 2.5 Design and Implementation Constraints

**Technical Constraints:**
1. Must work offline with limited functionality
2. GPS accuracy dependent on device hardware
3. Map data limited to OpenStreetMap coverage
4. AI models require training data
5. OSRM requires internet for new routes

**Regulatory Constraints:**
1. Must comply with Philippine Data Privacy Act
2. Must not collect unnecessary personal information
3. Must be accessible to persons with disabilities (WCAG 2.1)

**Business Constraints:**
1. Budget: Limited to open-source tools
2. Timeline: Academic semester constraints
3. Maintenance: MDRRMO staff availability

### 2.6 Assumptions and Dependencies

**Assumptions:**
1. Users have Android smartphones with GPS
2. MDRRMO provides historical hazard data
3. Internet connectivity available in most areas
4. Residents understand basic disaster protocols
5. MDRRMO personnel trained on system usage

**Dependencies:**
1. OpenStreetMap availability and coverage
2. OSRM API reliability
3. Mobile network infrastructure
4. GPS satellite availability
5. Backend server uptime
6. MDRRMO cooperation and data sharing

---

## 3. System Features

### 3.1 User Registration and Authentication

**Feature ID:** F-001  
**Priority:** High  
**Risk:** Medium

**Description:**  
The system SHALL allow users to create accounts and securely authenticate using email and password.

**Functional Requirements:**

**REQ-001:** User Registration
- **Description:** New users shall register with email, password, full name, and phone number
- **Input:** Email, password (min 8 chars), full name, phone number
- **Process:** Validate email format, check uniqueness, hash password, create user record
- **Output:** Registration success/failure message
- **Validation:** Email must be unique, password must meet complexity requirements

**REQ-002:** User Login
- **Description:** Registered users shall login with email and password
- **Input:** Email and password
- **Process:** Verify credentials, generate JWT token, load user profile
- **Output:** Authentication token and user data or error message
- **Validation:** Account must exist, password must match

**REQ-003:** Password Security
- **Description:** System shall store passwords using secure hashing (PBKDF2)
- **Process:** Hash password with salt before storage, never store plain text
- **Validation:** Hash algorithm shall use minimum 100,000 iterations

**REQ-004:** Role-Based Access
- **Description:** System shall support two user roles: Resident and MDRRMO
- **Roles:** 
  - Resident: Access to evacuation, reporting, map
  - MDRRMO: Full admin access including report management
- **Validation:** Role assigned during registration or by admin

---

### 3.2 View Evacuation Centers

**Feature ID:** F-002  
**Priority:** High  
**Risk:** Low

**Description:**  
Users SHALL view a list of evacuation centers with location, capacity, and facility information.

**Functional Requirements:**

**REQ-005:** List Evacuation Centers
- **Description:** Display all active evacuation centers in Bulan
- **Input:** User location (optional for sorting by distance)
- **Process:** Fetch centers from database/cache, calculate distances, sort by proximity
- **Output:** List showing name, distance, capacity, facilities
- **Validation:** Only active centers displayed

**REQ-006:** Evacuation Center Details
- **Description:** Show detailed information for selected center
- **Display:** Name, address, barangay, GPS coordinates, contact number, facilities, capacity
- **Actions:** View on map, get directions

**REQ-007:** Map View
- **Description:** Display centers as markers on interactive map
- **Markers:** Blue pins for evacuation centers
- **Interaction:** Tap marker to see details, long-press for directions

**REQ-008:** Offline Access
- **Description:** Centers shall be cached for offline viewing
- **Cache Duration:** 7 days
- **Update:** Auto-refresh when online

---

### 3.3 Calculate Evacuation Routes

**Feature ID:** F-003  
**Priority:** Critical  
**Risk:** High

**Description:**  
The system SHALL calculate risk-aware evacuation routes using Modified Dijkstra algorithm integrated with OSRM for real road-following.

**Functional Requirements:**

**REQ-009:** Route Calculation
- **Description:** Calculate 3 safest routes from user location to selected evacuation center
- **Input:** Start GPS (lat/lng), destination center
- **Process:** 
  1. Validate location is in Philippines (use Bulan default if not)
  2. Call OSRM API for road-following routes
  3. Apply risk weighting from road risk scores
  4. Rank routes by safety (Green > Yellow > Red)
- **Output:** 3 routes with distance, risk score, estimated time
- **Algorithm:** Modified Dijkstra with weight = distance + (risk × 500)

**REQ-010:** Route Display
- **Description:** Display routes on map with color-coded polylines
- **Colors:**
  - Green: Low risk (< 0.3)
  - Yellow: Moderate risk (0.3 - 0.7)
  - Red: High risk (> 0.7)
- **Information:** Distance, estimated time, risk level, hazards on route

**REQ-011:** Route Selection
- **Description:** User can select preferred route for navigation
- **Safest Route:** Recommended by default (highlighted)
- **Alternative Routes:** Available if user prefers different path
- **Warning:** Alert if selecting high-risk route

**REQ-012:** Route Caching
- **Description:** Routes shall be cached for offline use
- **Cache Key:** Start location + destination
- **Cache Duration:** 3 days
- **Fallback:** If OSRM fails and no cache, use geometric fallback

**REQ-013:** Turn-by-Turn Navigation
- **Description:** Provide step-by-step navigation instructions
- **Display:** Current location, route path, next turn, distance to destination
- **Audio:** Optional voice guidance
- **Updates:** Real-time position tracking

---

### 3.4 Report Hazards

**Feature ID:** F-004  
**Priority:** High  
**Risk:** Medium

**Description:**  
Residents SHALL report hazards with location, type, description, and optional media.

**Functional Requirements:**

**REQ-014:** Hazard Submission
- **Description:** Allow users to submit hazard reports
- **Input:** 
  - Hazard type (required): 9 types available
  - Location (required): Auto-detected or manual
  - Description (required): Min 10 characters
  - Photo/Video (optional): Max 10 MB
- **Process:** Validate inputs, capture GPS, upload media, submit to backend
- **Output:** Success message with report ID or error

**REQ-015:** Hazard Types
- **Description:** System shall support 9 predefined hazard types
- **Types:**
  1. Flooded Road
  2. Landslide
  3. Fallen Tree
  4. Road Damage
  5. Fallen Electric Post / Wires
  6. Road Blocked
  7. Bridge Damage
  8. Storm Surge
  9. Other

**REQ-016:** Offline Reporting
- **Description:** Reports shall be queued if submitted offline
- **Process:** Save to local queue, mark as pending sync
- **Sync:** Auto-upload when internet detected
- **Notification:** Inform user when report successfully submitted

**REQ-017:** Report Validation (Client-Side)
- **Description:** Validate report data before submission
- **Checks:**
  - Hazard type selected
  - Description >= 10 characters
  - Location within Philippines bounds
  - Media file size <= 10 MB
- **Errors:** Display clear error messages for failed validation

---

### 3.5 AI Report Validation (Backend)

**Feature ID:** F-005  
**Priority:** High  
**Risk:** High

**Description:**  
Backend SHALL validate hazard reports using Naive Bayes classifier and Consensus scoring.

**Functional Requirements:**

**REQ-018:** Naive Bayes Validation
- **Description:** Calculate probability that report is authentic
- **Algorithm:** Naive Bayes classifier
- **Features:** Hazard type, description length
- **Training Data:** Historical MDRRMO-verified reports
- **Output:** Confidence score (0.0 to 1.0)
- **Threshold:** Score >= 0.7 considered likely authentic

**REQ-019:** Consensus Scoring
- **Description:** Boost confidence for reports with multiple submissions in same area
- **Algorithm:** Count reports within 50m radius
- **Boost:** +10% per nearby report (max +30%)
- **Formula:** Final = 0.7 × NB_score + 0.3 × (0.5 + consensus_boost)
- **Output:** Combined confidence score

**REQ-020:** Report Status Assignment
- **Description:** Assign initial status based on AI confidence
- **Rules:**
  - Score >= 0.8: Auto-approve (status: Verified)
  - 0.5 <= Score < 0.8: Pending review (status: Pending)
  - Score < 0.5: Flag for rejection (status: Flagged)
- **Override:** MDRRMO can manually approve/reject any report

**REQ-021:** Model Training
- **Description:** System shall support retraining AI models with new data
- **Process:** 
  1. Export verified reports with labels
  2. Retrain Naive Bayes with updated dataset
  3. Persist model for future use
- **Frequency:** After every 100 new verified reports or monthly

---

### 3.6 Road Risk Prediction

**Feature ID:** F-006  
**Priority:** High  
**Risk:** High

**Description:**  
System SHALL predict risk scores for road segments using Random Forest algorithm.

**Functional Requirements:**

**REQ-022:** Risk Score Calculation
- **Description:** Calculate risk score for each road segment
- **Algorithm:** Random Forest Regressor
- **Features:** 
  - Nearby hazard count (within 100m)
  - Average hazard severity
  - Historical flooding frequency
  - Road elevation (if available)
- **Output:** Risk score (0.0 = safe to 1.0 = very dangerous)

**REQ-023:** Risk Level Classification
- **Description:** Classify roads into risk levels
- **Levels:**
  - Green (Low): 0.0 - 0.3
  - Yellow (Moderate): 0.3 - 0.7
  - Red (High): 0.7 - 1.0
- **Usage:** Applied in route calculation

**REQ-024:** Risk Update Frequency
- **Description:** Road risk scores shall be updated when new hazards verified
- **Triggers:**
  - New hazard approved by MDRRMO
  - Baseline hazard data updated
  - Manual refresh by admin
- **Process:** Recalculate risk for affected road segments

**REQ-025:** Risk Visualization
- **Description:** Display road risk levels on admin map
- **Colors:** Green/Yellow/Red overlay on road segments
- **Toggle:** Admin can show/hide risk layer

---

### 3.7 MDRRMO Dashboard

**Feature ID:** F-007  
**Priority:** High  
**Risk:** Medium

**Description:**  
MDRRMO personnel SHALL access administrative dashboard with overview statistics and charts.

**Functional Requirements:**

**REQ-026:** Dashboard Statistics
- **Description:** Display key metrics on dashboard
- **Metrics:**
  - Total reports (all time)
  - Pending reports (requiring review)
  - Verified hazards (approved)
  - High risk roads (Red level)
  - Total evacuation centers
- **Update:** Real-time refresh every 30 seconds

**REQ-027:** Charts and Visualizations
- **Description:** Display data visualizations
- **Charts:**
  - Reports by barangay (bar chart)
  - Hazard type distribution (pie chart)
  - Reports over time (line chart)
- **Interaction:** Clickable for detailed view

**REQ-028:** Recent Activity Feed
- **Description:** Show latest system activities
- **Events:** New reports, approvals, rejections, system alerts
- **Display:** Time, event type, user, action
- **Limit:** Last 20 activities

---

### 3.8 Reports Management

**Feature ID:** F-008  
**Priority:** Critical  
**Risk:** Medium

**Description:**  
MDRRMO SHALL review, approve, or reject hazard reports with filtering and search.

**Functional Requirements:**

**REQ-029:** Report List View
- **Description:** Display all hazard reports with filters
- **Columns:** ID, hazard type, location, date, status, AI scores
- **Filters:**
  - Status (All / Pending / Approved / Rejected)
  - Barangay (dropdown)
  - Date range
  - Hazard type
- **Sort:** By date, AI score, status
- **Search:** By description keywords

**REQ-030:** Report Detail View
- **Description:** Show full report information
- **Sections:**
  1. Map Preview (location marker)
  2. Report Information (type, description, date, reporter)
  3. AI Analysis (NB score, consensus score, RF risk, recommendation)
  4. Media (photos/videos if attached)
  5. Decision History (approval/rejection log)

**REQ-031:** Approve Report
- **Description:** MDRRMO can approve valid reports
- **Process:**
  1. Review report details and AI scores
  2. Click "Approve" button
  3. Optional: Add admin comment
  4. Confirm action
- **Effect:** Status → Verified, triggers road risk recalculation
- **Notification:** Reporter notified (future feature)

**REQ-032:** Reject Report
- **Description:** MDRRMO can reject invalid/duplicate reports
- **Process:**
  1. Review report details
  2. Click "Reject" button
  3. Required: Add rejection reason comment
  4. Confirm action
- **Effect:** Status → Rejected, no impact on routing
- **Notification:** Reporter notified with reason (future feature)

**REQ-033:** Batch Actions
- **Description:** MDRRMO can perform actions on multiple reports
- **Actions:** Approve multiple, reject multiple, delete
- **Safety:** Confirmation required for batch operations

---

### 3.9 Map Monitor

**Feature ID:** F-009  
**Priority:** High  
**Risk:** Low

**Description:**  
MDRRMO SHALL view full-screen map with all hazards and evacuation centers with layer toggles.

**Functional Requirements:**

**REQ-034:** Map Display
- **Description:** Full-screen interactive map of Bulan area
- **Base Map:** OpenStreetMap tiles
- **Center:** Bulan, Sorsogon (12.6699, 123.8758)
- **Zoom Levels:** 10 (municipality) to 18 (street)

**REQ-035:** Layer Toggles
- **Description:** Admin can show/hide map layers
- **Layers:**
  - Evacuation Centers (blue markers)
  - Verified Hazards (red markers)
  - Pending Hazards (orange markers)
  - Risk Overlay (colored road segments)
- **Controls:** Toggle switches in bottom sheet

**REQ-036:** Marker Interactions
- **Description:** Tapping markers shows details
- **Evacuation Centers:** Name, address, capacity, contact
- **Hazards:** Type, description, date, AI scores, status
- **Actions:** View full report, approve/reject (for hazards)

**REQ-037:** Map Legend
- **Description:** Display legend explaining map symbols
- **Legend Items:**
  - 🔵 Blue = Evacuation Centers
  - 🔴 Red = Verified Hazards
  - 🟠 Orange = Pending Hazards
  - Green/Yellow/Red roads = Risk levels

---

### 3.10 Evacuation Center Management

**Feature ID:** F-010  
**Priority:** High  
**Risk:** Low

**Description:**  
MDRRMO SHALL manage evacuation centers (add, edit, deactivate).

**Functional Requirements:**

**REQ-038:** List Centers
- **Description:** Display all evacuation centers
- **Display:** Name, barangay, address, contact, coordinates, status
- **Filters:** Barangay, status (Active/Inactive)
- **Search:** By name or address
- **Sort:** By name, barangay, distance from MDRRMO office

**REQ-039:** Add Center
- **Description:** MDRRMO can add new evacuation centers
- **Form Fields:**
  - Name (required)
  - Barangay (required, dropdown)
  - Address (required)
  - Contact Number (required, format: 09XX-XXX-XXXX)
  - Latitude (required, decimal)
  - Longitude (required, decimal)
- **Validation:** All fields required, coordinates within Bulan bounds
- **Effect:** New center immediately available to residents

**REQ-040:** Edit Center
- **Description:** MDRRMO can update center information
- **Editable Fields:** All fields except ID
- **Process:** Load current data, allow modifications, save changes
- **Validation:** Same as add center
- **Effect:** Updates reflected in real-time

**REQ-041:** Deactivate Center
- **Description:** MDRRMO can deactivate centers (e.g., under repair)
- **Process:** Set status to "Inactive"
- **Effect:** Hidden from resident app, still visible in admin
- **Reactivate:** Can change status back to "Active"

**REQ-042:** View on Map
- **Description:** Each center has "View on Map" button
- **Action:** Opens map centered on center location
- **Display:** Marker with center details

---

### 3.11 Analytics

**Feature ID:** F-011  
**Priority:** Medium  
**Risk:** Low

**Description:**  
MDRRMO SHALL view statistical analysis and trends.

**Functional Requirements:**

**REQ-043:** Most Dangerous Barangays
- **Description:** List barangays ranked by risk score
- **Display:** Barangay name, risk score, hazard count
- **Calculation:** Average risk of road segments in barangay
- **Limit:** Top 5 barangays

**REQ-044:** Hazard Type Distribution
- **Description:** Show breakdown of hazards by type
- **Chart:** Bar or pie chart
- **Data:** Count of each hazard type (all time and last 30 days)
- **Export:** Download as CSV

**REQ-045:** Road Risk Distribution
- **Description:** Show distribution of road risk levels
- **Display:** Count of Green/Yellow/Red road segments
- **Percentage:** Of total road network
- **Trends:** Compare to previous month

**REQ-046:** Model Statistics
- **Description:** Display AI model performance metrics
- **Metrics:**
  - Naive Bayes accuracy
  - Consensus accuracy (reports with consensus vs without)
  - Random Forest accuracy
  - Model version
  - Last trained date
- **Purpose:** Monitor model quality

**REQ-047:** Reports Over Time
- **Description:** Line chart showing report trends
- **X-Axis:** Date (last 30 days)
- **Y-Axis:** Report count
- **Lines:** Total reports, verified, rejected
- **Insights:** Identify peak reporting times

---

### 3.12 Admin Settings

**Feature ID:** F-012  
**Priority:** Medium  
**Risk:** Low

**Description:**  
MDRRMO SHALL access admin-specific settings and system controls.

**Functional Requirements:**

**REQ-048:** Admin Profile
- **Description:** Display current admin user information
- **Display:** Name, email, role, last login
- **Edit:** Change name, phone number (not email or role)

**REQ-049:** Change Password
- **Description:** Admin can change account password
- **Form:** Current password, new password, confirm password
- **Validation:** Current password correct, new password meets requirements
- **Security:** Force re-login after password change

**REQ-050:** Retrain AI Models
- **Description:** Manually trigger AI model retraining
- **Process:** 
  1. Export latest verified reports
  2. Retrain NB, RF models
  3. Update model versions
  4. Display success message
- **Duration:** 30-60 seconds
- **Frequency Limit:** Once per day

**REQ-051:** Sync Baseline Data
- **Description:** Refresh baseline hazard data from MDRRMO database
- **Process:** Import historical hazard data from CSV/Excel
- **Effect:** Updates road risk calculations
- **Confirmation:** Display sync status and record count

**REQ-052:** Clear Cache
- **Description:** Clear app cache to force data refresh
- **Targets:** Route cache, map tiles, temporary files
- **Warning:** Confirm action (data will be re-downloaded)
- **Effect:** Forces fresh data load on next request

**REQ-053:** System Information
- **Description:** Display system status information
- **Info:**
  - App version
  - Backend API version
  - Database version
  - Model versions (NB, RF, Dijkstra)
  - Dataset version
  - Last sync date
  - Total users, reports, centers

**REQ-054:** Logout
- **Description:** Admin can securely logout
- **Process:** Clear auth token, return to welcome screen
- **Confirmation:** "Are you sure?" dialog
- **Security:** No cached data after logout

---

### 3.13 Offline Mode

**Feature ID:** F-013  
**Priority:** High  
**Risk:** High

**Description:**  
System SHALL provide core functionality without internet connection.

**Functional Requirements:**

**REQ-055:** Offline Data Storage
- **Description:** System shall cache essential data locally
- **Technology:** Hive NoSQL database
- **Cached Data:**
  - Evacuation centers (7-day expiry)
  - Calculated routes (3-day expiry)
  - Baseline hazards (30-day expiry)
  - User profile
- **Storage Limit:** Max 50 MB

**REQ-056:** Offline Route Access
- **Description:** Previously calculated routes available offline
- **Process:** 
  1. User requests route
  2. System checks cache for same start-end pair
  3. If found and not expired, use cached route
  4. If not found, show error requesting internet
- **Cache Key:** "startLat,startLng-endLat,endLng"

**REQ-057:** Offline Report Queue
- **Description:** Hazard reports submitted offline shall be queued
- **Process:**
  1. User submits report while offline
  2. System saves to local queue
  3. Mark as "Pending Sync"
  4. Show success message with sync notice
- **Queue Limit:** 20 reports
- **Persistence:** Survives app restart

**REQ-058:** Auto-Sync
- **Description:** Queued data shall auto-sync when internet detected
- **Triggers:**
  - App detects network connectivity
  - User pulls to refresh
  - App resumes from background
- **Process:** Upload queued reports, refresh cached data
- **Notification:** "Synced X reports" message

**REQ-059:** Offline Indicators
- **Description:** System shall clearly indicate offline mode
- **Indicators:**
  - "Offline" badge in app bar
  - Gray cloud icon with slash
  - "Using cached data" notice
- **Features Disabled:** 
  - New route calculation (show cached only)
  - Login/Register
  - Real-time data

---

### 3.14 Location Services

**Feature ID:** F-014  
**Priority:** Critical  
**Risk:** High

**Description:**  
System SHALL accurately determine user location using GPS.

**Functional Requirements:**

**REQ-060:** GPS Permission Request
- **Description:** App shall request location permission on first launch
- **Permission:** ACCESS_FINE_LOCATION (Android)
- **Timing:** Before accessing GPS
- **Message:** Clear explanation of why location is needed
- **Options:** While using app, Only this time, Don't allow

**REQ-061:** Location Accuracy
- **Description:** System shall use high-accuracy GPS
- **Accuracy Level:** LocationAccuracy.high (±5-10 meters)
- **Technology:** GPS + WiFi + Cell tower triangulation
- **Timeout:** 30 seconds max wait time
- **Fallback:** Use last known location if current unavailable

**REQ-062:** Location Validation
- **Description:** System shall validate GPS coordinates
- **Check:** Latitude between 4.0 and 21.0, Longitude between 116.0 and 127.0
- **Fallback:** If outside Philippines (e.g., emulator), use Bulan default (12.6699, 123.8758)
- **Logging:** Log warning when using fallback

**REQ-063:** Background Location (Future)
- **Description:** System may track location in background for turn-by-turn navigation
- **Permission:** ACCESS_BACKGROUND_LOCATION (Android 10+)
- **Usage:** Only during active navigation
- **Privacy:** Stop tracking when navigation ends

**REQ-064:** Location Error Handling
- **Description:** System shall gracefully handle location errors
- **Errors:**
  - Permission denied → Show settings prompt
  - GPS disabled → Prompt to enable
  - Timeout → Use last known or default
  - Accuracy too low → Notify user, continue with available accuracy

---

## 4. External Interface Requirements

### 4.1 User Interfaces

#### 4.1.1 General UI Requirements

**REQ-065:** Mobile-First Design
- **Screen Sizes:** 4.5" to 7" (320x568 to 768x1024 pixels)
- **Orientation:** Portrait (primary), Landscape (supported)
- **Navigation:** Bottom navigation bar for main screens
- **Accessibility:** Minimum touch target size 44x44 points

**REQ-066:** Visual Design
- **Color Scheme:**
  - Primary: Blue (#2196F3)
  - Accent: Amber (#FFC107) for warnings
  - Success: Green (#4CAF50)
  - Danger: Red (#F44336)
  - Admin Theme: Navy Blue (#1E3A8A)
- **Typography:** Roboto (Android), SF Pro (iOS)
- **Icons:** Material Design Icons
- **Contrast:** WCAG AA compliant (4.5:1 minimum)

**REQ-067:** Responsive Layout
- **Adaptation:** Scale to different screen sizes
- **Breakpoints:** Phone (<600dp), Tablet (≥600dp)
- **Grid:** 8dp baseline grid
- **Padding:** Minimum 16dp screen margins

#### 4.1.2 Resident App Screens

**REQ-068:** Welcome Screen
- **Components:** App logo, tagline, features list, Login/Register button
- **Animation:** Subtle fade-in on launch
- **Duration:** Auto-advance to login if already logged in

**REQ-069:** Login Screen
- **Fields:** Email, password
- **Actions:** Login button, Register link, Forgot password (future)
- **Validation:** Real-time error display
- **Loading:** Progress indicator during authentication

**REQ-070:** Register Screen
- **Fields:** Full name, email, phone number, password, confirm password
- **Actions:** Register button, Back to login link
- **Validation:** Real-time with clear error messages
- **Success:** Auto-login after registration

**REQ-071:** Map Screen (Main)
- **Layout:** Full-screen map with overlays
- **Markers:** Blue (centers), Red (hazards), Blue dot (user)
- **Controls:** Center on user, zoom in/out, layers
- **Top Bar:** Logo, settings button, profile button
- **Bottom Sheet:** Selected center details or search

**REQ-072:** Evacuation Centers List
- **Layout:** Scrollable list of cards
- **Card Content:** Name, distance, address, capacity, "Get Directions" button
- **Search:** Search bar at top
- **Sort:** Distance (default), Name
- **Empty State:** "No evacuation centers found"

**REQ-073:** Route Selection Screen
- **Header:** Destination center info
- **Route Cards:** 3 routes, each showing:
  - Risk level indicator (Green/Yellow/Red)
  - Distance (e.g., "3.5 km")
  - Risk percentage (e.g., "20%")
  - Risk bar visualization
  - "Start Navigation" / "View Details" button
- **Safest Route:** Highlighted, marked as "Recommended"

**REQ-074:** Navigation Screen
- **Layout:** Map with route polyline, user location dot
- **Top Bar:** Destination name, distance remaining, ETA
- **Instructions:** Next turn, distance to turn
- **Actions:** Center on user, cancel navigation
- **Audio:** Toggle voice guidance

**REQ-075:** Report Hazard Screen
- **Form Layout:** Vertical scroll
- **Fields:**
  - Hazard type dropdown with icons
  - Description textarea (multiline)
  - Location display (auto-detected, with "Use current location" button)
  - Media picker (optional photo/video)
- **Preview:** Show selected photo/video
- **Actions:** Submit, Cancel
- **Success:** Confirmation message with report ID

**REQ-076:** Settings Screen
- **Sections:**
  1. Profile (name, email, avatar)
  2. Emergency Hotlines (7 numbers, tap to call)
  3. App Settings (notifications, units)
  4. About (version, privacy policy)
  5. Logout button (red, bottom)
- **Confirmation:** Dialog before logout

#### 4.1.3 Admin App Screens

**REQ-077:** Admin Home Screen
- **Bottom Nav:** 6 tabs (Dashboard, Reports, Map Monitor, Centers, Analytics, Settings)
- **Theme:** Navy blue header with white/gray content
- **Logo:** MDRRMO emblem

**REQ-078:** Dashboard Tab
- **Layout:** Scrollable, 3 sections
- **Section 1:** Summary cards (2x3 grid)
  - Total Reports, Pending Reports, Verified Hazards, High Risk Roads, Evacuation Centers
  - Each card: Icon, label, count, colored border
- **Section 2:** Charts
  - Reports by Barangay (bar chart)
  - Hazard Distribution (pie chart)
- **Section 3:** Recent Activity (list, last 10 events)

**REQ-079:** Reports Tab
- **Header:** Filter controls (status, barangay), search bar
- **Body:** Scrollable list of report cards
- **Card Content:**
  - Hazard type icon and name
  - Location (barangay)
  - Date/time
  - AI scores (NB %, Consensus %)
  - Status badge (color-coded)
  - "View Details" button
- **Empty State:** "No reports found"

**REQ-080:** Report Detail Screen
- **Sections (scrollable):**
  1. Map preview (small map with location marker)
  2. Report info (type, description, date, reporter ID)
  3. Media (if attached)
  4. AI Analysis panel (NB, Consensus, RF, Recommendation)
  5. Decision controls (Approve button, Reject button, Comment field)
- **Navigation:** Back arrow, share button

**REQ-081:** Map Monitor Tab
- **Layout:** Full-screen map
- **Top Bar:** Title, layers button, legend button
- **Layers Button:** Opens bottom sheet with toggles
- **Legend:** Floating card, bottom-left, collapsible

**REQ-082:** Centers Tab
- **Header:** Search bar, filter (barangay), Add Center FAB
- **Body:** List of center cards
- **Card Content:**
  - Name (bold)
  - Barangay, address
  - Contact, coordinates
  - Status badge
  - Action buttons (Map icon, Edit, Deactivate)

**REQ-083:** Add/Edit Center Screen
- **Form:** Vertical layout
- **Fields:** All center fields with validation
- **Actions:** Save, Cancel
- **Success:** Return to list with success message

**REQ-084:** Analytics Tab
- **Layout:** Scrollable, 4 sections
- **Sections:**
  1. Most Dangerous Barangays (ranked list)
  2. Hazard Type Distribution (chart)
  3. Road Risk Distribution (pie chart)
  4. Model Statistics (info cards)

**REQ-085:** Admin Settings Tab
- **Sections:**
  1. Admin Profile
  2. Admin Actions (4 buttons with confirmation)
  3. System Information (read-only cards)
  4. Logout button

### 4.2 Hardware Interfaces

**REQ-086:** GPS Receiver
- **Interface:** Platform GPS API (geolocator package)
- **Data:** Latitude, longitude, altitude, accuracy, timestamp
- **Frequency:** On-demand or continuous (during navigation)
- **Power:** Managed by OS

**REQ-087:** Camera (Optional)
- **Interface:** Platform Camera API (image_picker package)
- **Purpose:** Capture photos/videos for hazard reports
- **Resolution:** Default camera resolution, compressed to max 10 MB
- **Permissions:** CAMERA, READ_EXTERNAL_STORAGE

**REQ-088:** Network Interface
- **Types:** WiFi, Mobile data (3G/4G/5G)
- **Protocol:** HTTP/HTTPS
- **Usage:** API calls, map tiles, OSRM routing
- **Fallback:** Offline mode when unavailable

### 4.3 Software Interfaces

#### 4.3.1 OpenStreetMap Tile Server

**REQ-089:** OSM Integration
- **Service:** OpenStreetMap tile server
- **URL:** `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- **Protocol:** HTTPS
- **Tile Size:** 256x256 pixels
- **Zoom Levels:** 0 (world) to 19 (building)
- **Usage:** Map display in mobile app
- **Rate Limit:** Respect OSM usage policy (max 250 tiles/request)
- **Attribution:** Display "© OpenStreetMap contributors"
- **Fallback:** Show cached tiles if offline

#### 4.3.2 OSRM Routing API

**REQ-090:** OSRM Integration
- **Service:** OpenStreetMap Routing Machine
- **URL:** `https://router.project-osrm.org/route/v1/driving/{coordinates}`
- **Protocol:** HTTPS GET
- **Parameters:**
  - coordinates: `{lng1},{lat1};{lng2},{lat2}`
  - alternatives: 2 (request 2 alternative routes)
  - geometries: geojson (response format)
  - overview: full (complete route geometry)
  - steps: true (turn-by-turn instructions)
- **Response Format:** JSON with GeoJSON geometry
- **Timeout:** 15 seconds
- **Retry:** 2 attempts on failure
- **Fallback:** Use cached routes or show error
- **Rate Limit:** Reasonable use (not for production at scale)

#### 4.3.3 Backend REST API

**REQ-091:** API Communication
- **Protocol:** RESTful HTTP/HTTPS
- **Base URL:** `http://10.0.2.2:8000/api` (emulator), `https://api.domain.com` (production)
- **Format:** JSON
- **Authentication:** JWT Bearer token in Authorization header
- **Headers:**
  - Content-Type: application/json
  - Accept: application/json
  - Authorization: Bearer {token}

**REQ-092:** API Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | /auth/register/ | User registration | No |
| POST | /auth/login/ | User login | No |
| GET | /evacuation-centers/ | List centers | Yes |
| GET | /evacuation-centers/{id}/ | Get center details | Yes |
| POST | /calculate-route/ | Calculate routes | Yes |
| POST | /hazards/ | Submit hazard report | Yes |
| GET | /hazards/ | List hazard reports (admin) | Yes (MDRRMO) |
| PUT | /hazards/{id}/approve/ | Approve report | Yes (MDRRMO) |
| PUT | /hazards/{id}/reject/ | Reject report | Yes (MDRRMO) |
| GET | /bootstrap-sync/ | Initial data sync | Yes |
| GET | /mdrrmo/dashboard-stats/ | Dashboard statistics | Yes (MDRRMO) |
| GET | /mdrrmo/analytics/ | Analytics data | Yes (MDRRMO) |
| POST | /evacuation-centers/ | Add center (admin) | Yes (MDRRMO) |
| PUT | /evacuation-centers/{id}/ | Update center | Yes (MDRRMO) |

**REQ-093:** Error Responses
- **Format:** JSON with error message
- **Status Codes:**
  - 200: Success
  - 201: Created
  - 400: Bad request (validation error)
  - 401: Unauthorized (missing/invalid token)
  - 403: Forbidden (insufficient permissions)
  - 404: Not found
  - 500: Server error
- **Error JSON:** `{"error": "Error message", "code": "ERROR_CODE"}`

### 4.4 Communication Interfaces

**REQ-094:** Network Protocols
- **HTTP/HTTPS:** All API communication
- **TLS 1.2+:** Encrypted communication required in production
- **JSON:** Data exchange format
- **WebSocket:** Future real-time updates (not in v1.0)

**REQ-095:** Data Transfer
- **Request Size:** Max 10 MB (for media uploads)
- **Response Size:** Max 5 MB (typical < 100 KB)
- **Compression:** gzip compression for responses
- **Timeout:** 30 seconds for API calls

**REQ-096:** Bandwidth Optimization
- **Image Compression:** Max 1 MB per photo
- **Video Compression:** Max 10 MB per video
- **Map Tiles:** Cached after first load
- **Incremental Sync:** Only fetch new/updated data

---

## 5. System Architecture

### 5.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
├──────────────────────────────────────────────────────────────┤
│  Mobile App (Flutter/Dart)                                   │
│  • Resident UI (Screens, widgets)                            │
│  • Admin UI (Dashboard, management)                          │
│  • Offline storage (Hive)                                    │
└───────────────────┬──────────────────────────────────────────┘
                    │ REST API (HTTPS/JSON)
┌───────────────────▼──────────────────────────────────────────┐
│                    Application Layer                         │
├──────────────────────────────────────────────────────────────┤
│  Backend Server (Django/Python)                              │
│  • API Endpoints (Django REST Framework)                     │
│  • Business Logic (Services)                                 │
│  • Authentication (JWT)                                      │
│  • Permissions (RBAC)                                        │
└───────────────────┬──────────────────────────────────────────┘
                    │ ORM
┌───────────────────▼──────────────────────────────────────────┐
│                    Data Layer                                │
├──────────────────────────────────────────────────────────────┤
│  Database (SQLite/PostgreSQL)                                │
│  • Users, Reports, Centers, Roads, Hazards                   │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                    AI/ML Layer                               │
├──────────────────────────────────────────────────────────────┤
│  • Naive Bayes Classifier (Report validation)               │
│  • Consensus Scoring (Multi-report confidence)              │
│  • Random Forest (Road risk prediction)                     │
│  • Modified Dijkstra (Safest routing)                       │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                    External Services                         │
├──────────────────────────────────────────────────────────────┤
│  • OpenStreetMap (Map tiles)                                 │
│  • OSRM API (Route calculation)                              │
│  • GPS Satellites (Location services)                        │
└──────────────────────────────────────────────────────────────┘
```

### 5.2 Component Diagram

**REQ-097:** System shall follow modular architecture with clear separation of concerns
- **Presentation Layer:** Mobile app UI
- **Application Layer:** Backend API and business logic
- **Data Layer:** Database persistence
- **AI/ML Layer:** Intelligent algorithms
- **Integration Layer:** External services

### 5.3 Technology Stack

**Mobile App:**
- Framework: Flutter 3.x
- Language: Dart 3.x
- State Management: StatefulWidget (built-in)
- Local Storage: Hive 2.2.3
- HTTP Client: Dio 5.4.0
- Maps: flutter_map 6.1.0
- Location: geolocator 10.1.0

**Backend Server:**
- Framework: Django 4.2+
- API: Django REST Framework 3.14+
- Language: Python 3.10+
- Authentication: JWT (djangorestframework-simplejwt)
- ORM: Django ORM
- Web Server: Gunicorn + Nginx

**Database:**
- Development: SQLite 3
- Production: PostgreSQL 12+

**AI/ML:**
- Library: scikit-learn 1.3+
- Algorithms: Naive Bayes, Random Forest, Custom Dijkstra
- Training Data: JSON files (mock), CSV/DB (production)

---

## 6. Functional Requirements (Summary)

This section summarizes the functional requirements organized by priority.

### 6.1 Critical Requirements (Must Have)

| ID | Requirement | Feature |
|----|-------------|---------|
| REQ-009 | Calculate risk-aware evacuation routes | Route Calculation |
| REQ-014 | Submit hazard reports | Hazard Reporting |
| REQ-018 | Validate reports with Naive Bayes | AI Validation |
| REQ-022 | Predict road risk with Random Forest | Risk Prediction |
| REQ-029 | Manage hazard reports (approve/reject) | MDRRMO Dashboard |
| REQ-055 | Offline data caching | Offline Mode |
| REQ-060 | GPS location access | Location Services |

### 6.2 High Priority Requirements (Should Have)

| ID | Requirement | Feature |
|----|-------------|---------|
| REQ-001 | User registration | Authentication |
| REQ-005 | List evacuation centers | Evacuation Centers |
| REQ-019 | Consensus scoring | AI Validation |
| REQ-026 | Dashboard statistics | MDRRMO Dashboard |
| REQ-038 | Manage evacuation centers | Center Management |
| REQ-056 | Offline route access | Offline Mode |

### 6.3 Medium Priority Requirements (Could Have)

| ID | Requirement | Feature |
|----|-------------|---------|
| REQ-043 | Most dangerous barangays analytics | Analytics |
| REQ-048 | Admin profile management | Admin Settings |
| REQ-050 | Manual AI model retraining | Admin Settings |
| REQ-063 | Background location (future) | Location Services |

### 6.4 Low Priority Requirements (Nice to Have)

| ID | Requirement | Feature |
|----|-------------|---------|
| REQ-047 | Reports over time chart | Analytics |
| REQ-053 | System information display | Admin Settings |

---

## 7. Non-Functional Requirements

### 7.1 Performance Requirements

**REQ-098:** Response Time
- **API Calls:** Maximum 2 seconds for 95% of requests
- **Map Load:** Initial map display within 3 seconds
- **Route Calculation:** Maximum 5 seconds (online), <1 second (cached)
- **Database Queries:** Maximum 500ms
- **App Launch:** <2 seconds from icon tap to main screen

**REQ-099:** Throughput
- **Concurrent Users:** Support minimum 100 simultaneous users
- **API Requests:** Handle 50 requests per second
- **Database:** Support 100 transactions per second

**REQ-100:** Resource Usage
- **App Size:** Maximum 50 MB installed
- **RAM:** Maximum 200 MB memory usage
- **Battery:** Maximum 5% battery drain per hour during active use
- **Storage:** Maximum 100 MB for cached data
- **Network:** Optimized to work on 256 Kbps (3G) connection

### 7.2 Safety Requirements

**REQ-101:** Data Integrity
- **Hazard Reports:** Validate all data before storage
- **GPS Coordinates:** Validate within valid ranges
- **Database:** Use transactions for atomic operations
- **Backups:** Daily automated database backups

**REQ-102:** Fail-Safe Operation
- **Critical Features:** Evacuation center list and cached routes must work offline
- **Graceful Degradation:** App continues with limited features if backend unavailable
- **Data Loss Prevention:** Queue unsent reports, prevent data loss on crash
- **Error Recovery:** Auto-retry failed API calls (max 3 attempts)

**REQ-103:** User Safety
- **Route Verification:** Display risk levels clearly with color coding
- **Warning Messages:** Alert users selecting high-risk routes
- **Emergency Info:** Prominent display of emergency hotlines
- **Offline Warning:** Clear indication when using cached data

### 7.3 Security Requirements

**REQ-104:** Authentication and Authorization
- **Password Policy:**
  - Minimum 8 characters
  - Must include letters and numbers
  - Stored using PBKDF2 with 100,000+ iterations
- **Session Management:** JWT tokens with 24-hour expiry
- **Role-Based Access:** Enforce RBAC (Resident vs MDRRMO)
- **Permission Checks:** Validate permissions on every request

**REQ-105:** Data Protection
- **Encryption in Transit:** TLS 1.2+ for all API communication (production)
- **Encryption at Rest:** Database encryption (production)
- **Personal Data:** Minimize collection, hash sensitive fields
- **Media Files:** Sanitize uploads, check file types

**REQ-106:** Application Security
- **Input Validation:** Validate all user inputs (client and server)
- **SQL Injection:** Use ORM parameterized queries only
- **XSS Protection:** Sanitize displayed content
- **CSRF Protection:** CSRF tokens for state-changing operations
- **Rate Limiting:** Limit API calls to prevent abuse (10 req/min per user)

**REQ-107:** Privacy Requirements
- **Data Minimization:** Only collect necessary information
- **User Consent:** Clear privacy policy, user acceptance required
- **Data Retention:** Delete rejected reports after 30 days
- **Anonymization:** Reporter ID visible only to MDRRMO, not other residents
- **Right to Deletion:** Users can request account deletion (future)

### 7.4 Quality Attributes

#### 7.4.1 Reliability

**REQ-108:** Availability
- **Uptime:** 99% availability (87.6 hours downtime per year)
- **Maintenance Windows:** Scheduled during low-usage times (2-4 AM)
- **Disaster Recovery:** Restore from backup within 4 hours

**REQ-109:** Fault Tolerance
- **Offline Mode:** Core features work without backend
- **Graceful Failures:** User-friendly error messages, no crashes
- **Data Consistency:** Eventual consistency for offline-online sync

#### 7.4.2 Usability

**REQ-110:** Ease of Use
- **Learning Curve:** New users productive within 5 minutes
- **Help Documentation:** In-app help for key features
- **Error Messages:** Clear, actionable error descriptions
- **Feedback:** Visual feedback for all actions (loading, success, error)

**REQ-111:** Accessibility
- **Screen Readers:** Compatible with TalkBack (Android)
- **Text Scaling:** Support system text size preferences
- **Color Contrast:** WCAG AA compliant (4.5:1)
- **Touch Targets:** Minimum 44x44 points

#### 7.4.3 Maintainability

**REQ-112:** Code Quality
- **Documentation:** Inline comments for complex logic
- **Naming:** Clear, descriptive variable/function names
- **Architecture:** Clean separation of concerns (MVC/MVVM)
- **Version Control:** Git with meaningful commit messages

**REQ-113:** Testability
- **Unit Tests:** Minimum 60% code coverage
- **Integration Tests:** Test all API endpoints
- **UI Tests:** Test critical user flows
- **Mock Data:** Support mock mode for testing without backend

#### 7.4.4 Portability

**REQ-114:** Platform Support
- **Android:** Version 5.0 (API 21) to latest
- **iOS:** Version 11.0 to latest (future)
- **Backend:** Linux, macOS, Windows (development)

**REQ-115:** Data Portability
- **Export:** MDRRMO can export reports as CSV/JSON
- **Import:** Support import of historical MDRRMO data
- **Migration:** Support database migration between SQLite and PostgreSQL

#### 7.4.5 Scalability

**REQ-116:** Performance Scalability
- **User Growth:** Support 500 users with current architecture
- **Data Growth:** Efficiently handle 10,000+ reports
- **Route Calculation:** Optimize for 500+ road segments

**REQ-117:** Architectural Scalability
- **Horizontal Scaling:** Design allows adding server instances (future)
- **Database:** Can migrate to PostgreSQL for better performance
- **Caching:** Implement Redis caching layer (future)
- **CDN:** Static assets servable via CDN (future)

---

## 8. Data Requirements

### 8.1 Data Models

#### 8.1.1 User

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | Integer | PK, Auto-increment | Unique identifier |
| username | String(150) | Unique | Username for login |
| email | String(254) | Unique | Email address |
| full_name | String(255) | Required | Full name |
| phone_number | String(20) | Optional | Contact number |
| role | Enum | Required | 'resident' or 'mdrrmo' |
| password_hash | String(128) | Required | Hashed password |
| created_at | DateTime | Auto | Registration timestamp |
| last_login | DateTime | Auto | Last login timestamp |

#### 8.1.2 Evacuation Center

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | Integer | PK, Auto-increment | Unique identifier |
| name | String(255) | Required | Center name |
| barangay | String(100) | Required | Barangay location |
| address | Text | Required | Full address |
| latitude | Decimal(9,6) | Required | GPS latitude |
| longitude | Decimal(9,6) | Required | GPS longitude |
| contact_number | String(20) | Required | Contact phone |
| description | Text | Optional | Facilities, capacity |
| status | Enum | Required | 'active' or 'inactive' |
| created_at | DateTime | Auto | Creation timestamp |

#### 8.1.3 Hazard Report

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | Integer | PK, Auto-increment | Unique identifier |
| user_id | Integer | FK(User) | Reporter user |
| hazard_type | String(50) | Required | Type from 9 options |
| latitude | Decimal(9,6) | Required | Hazard GPS latitude |
| longitude | Decimal(9,6) | Required | Hazard GPS longitude |
| description | Text | Required | Report description |
| photo_url | String(500) | Optional | Photo file path |
| video_url | String(500) | Optional | Video file path |
| status | Enum | Required | 'pending', 'approved', 'rejected' |
| naive_bayes_score | Decimal(3,2) | Optional | AI confidence (0.00-1.00) |
| consensus_score | Decimal(3,2) | Optional | Consensus boost (0.00-1.00) |
| random_forest_risk | Decimal(3,2) | Optional | Road risk prediction |
| admin_comment | Text | Optional | MDRRMO notes |
| created_at | DateTime | Auto | Report timestamp |
| updated_at | DateTime | Auto | Last update timestamp |

#### 8.1.4 Road Segment

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | Integer | PK, Auto-increment | Unique identifier |
| segment_name | String(255) | Optional | Road name |
| start_lat | Decimal(9,6) | Required | Start point latitude |
| start_lng | Decimal(9,6) | Required | Start point longitude |
| end_lat | Decimal(9,6) | Required | End point latitude |
| end_lng | Decimal(9,6) | Required | End point longitude |
| base_distance | Decimal(8,2) | Required | Length in meters |
| predicted_risk_score | Decimal(3,2) | Required | Risk score (0.00-1.00) |
| last_updated | DateTime | Auto | Last risk calculation |

#### 8.1.5 Baseline Hazard

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | Integer | PK, Auto-increment | Unique identifier |
| hazard_type | String(50) | Required | Type of hazard |
| latitude | Decimal(9,6) | Required | GPS latitude |
| longitude | Decimal(9,6) | Required | GPS longitude |
| severity | Decimal(3,2) | Required | Severity (0.00-1.00) |
| date_recorded | DateTime | Required | MDRRMO record date |
| notes | Text | Optional | Additional information |

### 8.2 Data Dictionary

**Hazard Types (Enumeration):**
1. flooded_road
2. landslide
3. fallen_tree
4. road_damage
5. fallen_electric_post
6. road_blocked
7. bridge_damage
8. storm_surge
9. other

**Report Status (Enumeration):**
- pending: Awaiting MDRRMO review
- approved: Verified by MDRRMO
- rejected: Dismissed as invalid/duplicate

**User Roles (Enumeration):**
- resident: Regular app user
- mdrrmo: Administrative user

**Center Status (Enumeration):**
- active: Open and operational
- inactive: Temporarily closed

**Risk Levels (Classification):**
- Green: Low risk (0.00 - 0.30)
- Yellow: Moderate risk (0.30 - 0.70)
- Red: High risk (0.70 - 1.00)

### 8.3 Data Flow

#### 8.3.1 Hazard Reporting Flow

```
User → Submit Report (mobile) → Backend API
                                     ↓
                               Naive Bayes Validation
                                     ↓
                               Consensus Scoring
                                     ↓
                               Save to Database
                                     ↓
                               MDRRMO Reviews
                                     ↓
                            Approve or Reject
                                     ↓
                     If Approved → Update Road Risk (Random Forest)
                                     ↓
                               Update Route Calculations
```

#### 8.3.2 Route Calculation Flow

```
User → Request Route → Mobile App
                          ↓
                    Check Cache
                          ↓
                 If Not Cached → OSRM API
                          ↓
                    Get Road-Following Route
                          ↓
                Backend (if real mode) → Apply Risk Weights
                          ↓
                    Modified Dijkstra
                          ↓
                    Rank by Safety
                          ↓
                    Cache Result
                          ↓
                Display to User
```

### 8.4 Data Retention

**REQ-118:** Data Retention Policy
- **Approved Reports:** Indefinite (historical data for AI training)
- **Pending Reports:** 30 days, then auto-archive
- **Rejected Reports:** 30 days, then auto-delete
- **User Accounts:** Active indefinitely, deleted on request
- **Route Cache:** 3 days, then expire
- **Center Cache:** 7 days, then expire
- **Logs:** 90 days, then auto-delete

**REQ-119:** Backup Policy
- **Frequency:** Daily automated backups
- **Retention:** Keep last 30 daily backups
- **Location:** Separate storage from production database
- **Restore Test:** Monthly restore test

---

## 9. AI/ML Requirements

### 9.1 Algorithm 1: Naive Bayes Classifier

**REQ-120:** Model Purpose
- **Function:** Classify hazard reports as real or fake
- **Features:** Hazard type, description length bucket (short/medium/long)
- **Labels:** Valid (1) or Invalid (0)
- **Output:** Probability score (0.0 to 1.0)

**REQ-121:** Training Requirements
- **Training Data:** Minimum 100 historical reports with verified labels
- **Data Format:** JSON with keys: hazard_type, description_length, valid
- **Feature Engineering:** Bucket description length (< 20 chars = short, 20-60 = medium, > 60 = long)
- **Algorithm:** Naive Bayes with Laplace smoothing (k=0.5)

**REQ-122:** Performance Metrics
- **Accuracy:** Minimum 75% on test set
- **Precision:** Minimum 70% (minimize false positives)
- **Recall:** Minimum 80% (minimize false negatives)
- **F1-Score:** Minimum 0.75

**REQ-123:** Model Update
- **Retraining:** After every 100 new verified reports or monthly
- **Versioning:** Track model version and accuracy
- **A/B Testing:** Test new model alongside current before deploying

### 9.2 Algorithm 2: Consensus Scoring

**REQ-124:** Algorithm Purpose
- **Function:** Boost confidence when multiple reports in same location
- **Radius:** 50 meters
- **Boost:** +10% per nearby report (max +30%)
- **Combination:** 0.7 × NB_score + 0.3 × (0.5 + consensus_boost)

**REQ-125:** Implementation
- **Query:** Find reports within radius using Haversine distance
- **Exclusion:** Exclude rejected reports from consensus count
- **Real-Time:** Calculate on report submission
- **Threshold:** Score >= 0.8 auto-approve, 0.5-0.8 pending, < 0.5 flag

### 9.3 Algorithm 3: Random Forest

**REQ-126:** Model Purpose
- **Function:** Predict road segment risk scores
- **Features:** Nearby hazard count (within 100m), average hazard severity
- **Label:** Risk score (0.0 to 1.0)
- **Output:** Predicted risk for each road segment

**REQ-127:** Training Requirements
- **Training Data:** Minimum 50 road segments with historical hazard data
- **Data Format:** JSON with keys: segment_id, nearby_hazard_count, avg_severity, risk_score
- **Algorithm:** Random Forest Regressor with 10 trees
- **Library:** scikit-learn

**REQ-128:** Performance Metrics
- **R² Score:** Minimum 0.70
- **Mean Absolute Error:** Maximum 0.15
- **Prediction Range:** Clamp outputs to [0.0, 1.0]

**REQ-129:** Model Update
- **Retraining:** When new hazards verified or weekly
- **Feature Update:** Recalculate nearby hazards for affected segments
- **Batch Processing:** Update all segments in nightly job

### 9.4 Algorithm 4: Modified Dijkstra

**REQ-130:** Algorithm Purpose
- **Function:** Find safest path, not shortest
- **Graph:** Road network with weighted edges
- **Weight Formula:** distance + (predicted_risk × 500)
- **Output:** Top 3 routes ranked by safety

**REQ-131:** Implementation
- **Data Structure:** Adjacency list graph
- **Priority Queue:** Min-heap for efficient path finding
- **Bidirectional:** Roads are bidirectional (add both directions)
- **K-Paths:** Find 3 distinct paths (primary + 2 alternatives)

**REQ-132:** Performance
- **Time Complexity:** O((V + E) log V) where V=nodes, E=edges
- **Computation Time:** Maximum 2 seconds for 500 road segments
- **Memory:** Maximum 10 MB for graph representation

**REQ-133:** Risk Weighting
- **Risk Multiplier:** 500 (makes risk 500x more important than distance)
- **Justification:** Prioritize safety over convenience
- **Tuning:** Adjustable based on MDRRMO feedback

---

## 10. Security Requirements

### 10.1 Authentication

**REQ-134:** Password Requirements
- Minimum 8 characters
- Must contain: letters (a-z), numbers (0-9)
- Cannot be common passwords (e.g., "password123")
- Cannot match username or email

**REQ-135:** Password Storage
- Hash algorithm: PBKDF2 with SHA256
- Iterations: 100,000+
- Salt: Unique per password
- Never store plain text

**REQ-136:** Session Management
- Token type: JWT (JSON Web Token)
- Expiry: 24 hours
- Refresh: Require re-login after expiry
- Invalidation: Logout clears token from client

### 10.2 Authorization

**REQ-137:** Role-Based Access Control
- **Resident:** Can view centers, report hazards, get routes
- **MDRRMO:** Full access including report management, analytics
- **Permission Checks:** Server-side validation on every request
- **Principle of Least Privilege:** Users have minimum necessary permissions

**REQ-138:** API Authorization
- **Resident Endpoints:** Require valid JWT, role: resident or mdrrmo
- **Admin Endpoints:** Require valid JWT, role: mdrrmo only
- **Public Endpoints:** None (all require authentication)
- **Error Response:** 403 Forbidden if insufficient permissions

### 10.3 Data Security

**REQ-139:** Encryption
- **In Transit:** TLS 1.2+ for HTTPS (production)
- **At Rest:** Database encryption (production)
- **Sensitive Fields:** Hash passwords, encrypt PII if needed

**REQ-140:** Input Validation
- **Client-Side:** Validate formats, ranges, required fields
- **Server-Side:** Re-validate all inputs (never trust client)
- **Sanitization:** Remove/escape special characters
- **Length Limits:** Enforce maximum lengths on all text fields

**REQ-141:** SQL Injection Prevention
- Use ORM parameterized queries only
- Never concatenate user input into SQL
- Whitelist allowed characters for search queries

**REQ-142:** File Upload Security
- **Type Validation:** Allow only image/video MIME types
- **Size Limit:** 10 MB maximum
- **Virus Scan:** Scan uploads (if available)
- **Storage:** Store outside web root, serve via controlled endpoint
- **Filename Sanitization:** Remove/replace unsafe characters

### 10.4 Privacy

**REQ-143:** Data Minimization
- Collect only necessary information
- No geolocation tracking beyond current report
- No social media integration or tracking pixels

**REQ-144:** Anonymization
- Report author visible only to MDRRMO (not other residents)
- Display "Reporter ID: #12345" instead of name
- No public profile pages

**REQ-145:** Data Retention (See REQ-118)

**REQ-146:** Privacy Policy
- Clear, accessible privacy policy
- User accepts during registration
- Explains: data collected, usage, retention, rights

---

## 11. Performance Requirements

### 11.1 Response Time (See REQ-098)

### 11.2 Throughput (See REQ-099)

### 11.3 Capacity

**REQ-147:** User Capacity
- **Concurrent Users:** 100 simultaneous users
- **Registered Users:** 10,000 total user accounts
- **Peak Load:** 20% of users active simultaneously

**REQ-148:** Data Capacity
- **Hazard Reports:** 50,000 reports
- **Road Segments:** 1,000 segments
- **Evacuation Centers:** 50 centers
- **Media Files:** 10 GB storage

### 11.4 Resource Utilization (See REQ-100)

### 11.5 Scalability (See REQ-116, REQ-117)

---

## 12. Constraints and Assumptions

### 12.1 Technical Constraints

1. **Network Dependency:** Online features require internet connectivity
2. **GPS Accuracy:** Limited by device hardware (typically ±5-20 meters)
3. **Map Coverage:** Limited to OpenStreetMap data availability
4. **OSRM Dependency:** Routing requires OSRM API or self-hosted instance
5. **AI Model Accuracy:** ML models require sufficient training data
6. **Android Focus:** Primary development for Android, iOS future phase
7. **Open Source:** Must use free/open-source tools (budget constraint)

### 12.2 Business Constraints

1. **Geographic Scope:** System limited to Bulan, Sorsogon municipality
2. **User Base:** Target users are residents and MDRRMO personnel only
3. **Language:** English language UI (Filipino/Bicol future phase)
4. **Internet Availability:** Assumes most areas have internet, but supports offline
5. **Device Availability:** Assumes users have Android smartphones
6. **MDRRMO Cooperation:** Requires MDRRMO to provide historical hazard data

### 12.3 Regulatory Constraints

1. **Data Privacy Act:** Compliance with Philippine Data Privacy Act of 2012
2. **Accessibility:** WCAG 2.1 Level AA compliance (best effort)
3. **Open Data:** Map data from OpenStreetMap (ODbL license)

### 12.4 Assumptions

1. **User Devices:** Users have Android 5.0+ smartphones with GPS
2. **User Literacy:** Users have basic smartphone operation skills
3. **Network Coverage:** Mobile data or WiFi available in most areas
4. **GPS Availability:** GPS satellites accessible outdoors
5. **MDRRMO Support:** MDRRMO provides training, support, and data
6. **Historical Data:** MDRRMO has or will provide baseline hazard data
7. **User Adoption:** Residents willing to install and use the app
8. **Server Hosting:** Server infrastructure available for backend deployment
9. **Maintenance:** MDRRMO or designated team maintains system post-deployment
10. **Power Supply:** Users keep devices charged, especially during calamities

---

## 13. Appendices

### Appendix A: Glossary

| Term | Definition |
|------|------------|
| **Barangay** | Smallest administrative division in the Philippines (village/ward) |
| **Calamity** | Natural disaster (typhoon, flood, earthquake, etc.) |
| **Dijkstra** | Graph algorithm for finding shortest path |
| **Evacuation Center** | Designated safe location during disasters |
| **Haversine** | Formula for calculating distance between GPS coordinates |
| **JWT** | JSON Web Token, authentication token format |
| **Naive Bayes** | Probabilistic classification algorithm |
| **ORM** | Object-Relational Mapping, database abstraction |
| **Random Forest** | Ensemble machine learning algorithm |
| **Risk Level** | Classification of danger (Green/Yellow/Red) |

### Appendix B: Acronyms

| Acronym | Expansion |
|---------|-----------|
| AI | Artificial Intelligence |
| API | Application Programming Interface |
| CRUD | Create, Read, Update, Delete |
| GPS | Global Positioning System |
| HTTP(S) | HyperText Transfer Protocol (Secure) |
| JSON | JavaScript Object Notation |
| JWT | JSON Web Token |
| ML | Machine Learning |
| MDRRMO | Municipal Disaster Risk Reduction and Management Office |
| ORM | Object-Relational Mapping |
| OSM | OpenStreetMap |
| OSRM | OpenStreetMap Routing Machine |
| PBKDF2 | Password-Based Key Derivation Function 2 |
| RBAC | Role-Based Access Control |
| REST | Representational State Transfer |
| SRS | Software Requirements Specification |
| TLS | Transport Layer Security |
| UI | User Interface |
| WCAG | Web Content Accessibility Guidelines |

### Appendix C: References

1. OpenStreetMap: https://www.openstreetmap.org
2. OSRM: http://project-osrm.org
3. Flutter Documentation: https://flutter.dev/docs
4. Django Documentation: https://docs.djangoproject.com
5. scikit-learn: https://scikit-learn.org
6. Philippine DRRM Act: RA 10121
7. Data Privacy Act: RA 10173

---

## Document Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Project Lead | [Name] | | |
| Technical Lead | [Name] | | |
| MDRRMO Representative | [Name] | | |
| Thesis Advisor | [Name] | | |

---

**END OF SOFTWARE REQUIREMENTS SPECIFICATION**

---

**Document Control:**
- **Revision History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-02-01 | Team | Initial draft |
| 0.5 | 2026-02-05 | Team | Added AI requirements |
| 1.0 | 2026-02-08 | Team | Final version for review |

- **Distribution List:**
  - Thesis Committee
  - MDRRMO Office
  - Development Team
  - University Library

---

**Total Requirements:** 147 requirements (REQ-001 to REQ-147)
**Total Pages:** 80+
**Total Words:** 15,000+
