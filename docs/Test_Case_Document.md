# Test Case Document
## AI-Powered Mobile Evacuation Routing Application

**Version:** 4.0
**Date:** April 17, 2026
**Project:** Thesis — Evacuation Routing System for Bulan, Sorsogon
**Test Lead:** [Name]

---

## Document Information

| Document ID | TEST-EVAC-001 |
|-------------|---------------|
| Version | 4.0 |
| Status | Updated |
| Last Updated | April 18, 2026 |
| Classification | Internal |

### Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-02-05 | Team | Initial draft |
| 0.5 | 2026-02-07 | Team | Added UAT cases |
| 1.0 | 2026-02-08 | Team | Final version |
| 2.0 | 2026-04-13 | Team | Added navigation, confirmation, notification, media, and QA-patch test cases; updated affected existing cases; removed obsolete Risk Overlay cases; removed phone number from registration cases |
| 3.0 | 2026-04-17 | Team | QA Patch 2: replaced voice navigation TCs (TC-NAV-004/005/006) with compass heading TC (TC-NAV-012); updated TC-NAV-001 for real-time compass rotation; updated TC-NAV-007 (visual only); removed voice UAT survey question; added TC-NOTIF-006 (deleted report graceful dialog); added TC-ADMIN-016 (soft delete integrity); updated QA Patch Coverage table; total updated to 118 |
| 4.0 | 2026-04-18 | Team | Routing consistency + graduated hazard influence: added TC-NAV-013 (backend polyline in navigation), TC-NAV-014 (OSRM turn-instructions only), TC-NAV-015 (rerouting via backend first), TC-AI-009 (perpendicular distance impact), TC-AI-010 (flood gradual decay), TC-AI-011 (road_blocked 25 m impassable); updated QA Patch Coverage table; 118 → 124 test cases |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Test Strategy](#2-test-strategy)
3. [Test Environment](#3-test-environment)
4. [Authentication Test Cases](#4-authentication-test-cases)
5. [Evacuation Centers Test Cases](#5-evacuation-centers-test-cases)
6. [Routing Test Cases](#6-routing-test-cases)
7. [Hazard Reporting Test Cases](#7-hazard-reporting-test-cases)
8. [Admin Dashboard Test Cases](#8-admin-dashboard-test-cases)
9. [AI Algorithm Test Cases](#9-ai-algorithm-test-cases)
10. [Offline Mode Test Cases](#10-offline-mode-test-cases)
11. [Performance Test Cases](#11-performance-test-cases)
12. [Security Test Cases](#12-security-test-cases)
13. [Integration Test Cases](#13-integration-test-cases)
14. [Live Navigation Test Cases](#14-live-navigation-test-cases)
15. [Hazard Confirmation Test Cases](#15-hazard-confirmation-test-cases)
16. [Notification Test Cases](#16-notification-test-cases)
17. [Media Handling Test Cases](#17-media-handling-test-cases)
18. [User Acceptance Test Cases](#18-user-acceptance-test-cases)
19. [Test Metrics and Reporting](#19-test-metrics-and-reporting)

---

## 1. Introduction

### 1.1 Purpose

This document provides comprehensive test cases for the AI-Powered Mobile Evacuation Routing Application. It covers functional, non-functional, integration, and user acceptance testing for both the Resident and MDRRMO environments.

### 1.2 Scope

**In Scope:**
- Mobile app functionality (Android) — Resident and MDRRMO modes
- Backend API endpoints
- AI/ML algorithms (Naive Bayes, Consensus, Random Forest, Modified Dijkstra)
- Offline capabilities and sync
- Admin dashboard (MDRRMO)
- Live navigation (map rotation, GPS tracking, voice guidance, rerouting)
- Hazard confirmation system
- Notification system (MDRRMO)
- Media handling (upload, preview, fullscreen)
- Integration with external services (OSRM, OSM)

**Out of Scope:**
- iOS testing (future phase)
- Load testing beyond 100 concurrent users
- Backend server infrastructure testing
- Third-party service testing (OSRM, OSM)

### 1.3 Test Objectives

1. Verify all functional requirements are met
2. Ensure system performs within acceptable limits
3. Validate security measures
4. Confirm offline capabilities
5. Test AI algorithm accuracy
6. Verify MDRRMO admin functions
7. Ensure data integrity
8. Validate user experience
9. Confirm live navigation accuracy (rotation, voice, rerouting)
10. Validate hazard confirmation and notification flows

### 1.4 Definitions

| Term | Definition |
|------|------------|
| **DUT** | Device Under Test |
| **SUT** | System Under Test |
| **UAT** | User Acceptance Testing |
| **TC** | Test Case |
| **P0** | Critical Priority (Blocker) |
| **P1** | High Priority |
| **P2** | Medium Priority |
| **P3** | Low Priority |
| **NB** | Naive Bayes score |
| **RF** | Random Forest score |
| **OSRM** | Open Source Routing Machine |

---

## 2. Test Strategy

### 2.1 Test Levels

1. **Unit Testing** — Individual components/functions
2. **Integration Testing** — Component interactions
3. **System Testing** — Complete system functionality
4. **User Acceptance Testing** — End-user validation

### 2.2 Test Types

- **Functional Testing** — Feature correctness
- **Non-Functional Testing** — Performance, usability
- **Security Testing** — Authentication, authorization, data protection
- **Regression Testing** — Ensure existing features still work after QA patches
- **Smoke Testing** — Basic functionality check
- **Compatibility Testing** — Different Android versions

### 2.3 Test Approach

**Manual Testing:**
- UI/UX testing
- Exploratory testing
- UAT with MDRRMO

**Automated Testing:**
- Unit tests (Dart test framework)
- API tests (Postman/Newman)
- Integration tests (Flutter integration test)

### 2.4 Entry and Exit Criteria

**Entry Criteria:**
- Code development complete
- Build deployed to test environment
- Test data prepared
- Test environment ready

**Exit Criteria:**
- All P0 and P1 test cases passed
- 95% P2 test cases passed
- All critical bugs fixed
- Test coverage >= 80%
- UAT sign-off obtained

### 2.5 Test Deliverables

1. Test plan document
2. Test case document (this document)
3. Test execution report
4. Bug reports
5. Test metrics summary
6. UAT sign-off

---

## 3. Test Environment

### 3.1 Mobile Test Environment

**Device Configurations:**

| Device | OS Version | Screen Size | RAM | Notes |
|--------|------------|-------------|-----|-------|
| Samsung Galaxy A52 | Android 12 | 6.5" (1080×2400) | 6 GB | Mid-range |
| Google Pixel 4a | Android 13 | 5.81" (1080×2340) | 6 GB | Stock Android |
| Android Emulator | Android 11 | 5.4" (1080×1920) | 2 GB | Min spec |
| Android Emulator | Android 13 | 6.7" (1440×3200) | 8 GB | High-end |
| Xiaomi Redmi 9 | Android 10 | 6.53" (1080×2340) | 4 GB | Budget device |

**Network Configurations:**
- WiFi (high speed: 10+ Mbps)
- 4G LTE (medium speed: 1–5 Mbps)
- 3G (low speed: 256 Kbps – 1 Mbps)
- Offline mode (no connectivity)
- Intermittent connectivity (simulate poor network)

### 3.2 Backend Test Environment

**Server:**
- OS: Ubuntu 20.04 LTS
- Python: 3.10
- Django: 4.2
- Database: SQLite (test), PostgreSQL (staging)
- Web Server: Gunicorn

**Test Data:**
- 5 evacuation centers
- 20 users (10 residents, 2 MDRRMO)
- 50 hazard reports (various statuses)
- 100 road segments
- 30 baseline hazards

### 3.3 Test Accounts

| Username | Email | Password | Role | Purpose |
|----------|-------|----------|------|---------|
| resident1 | resident@test.com | password123 | Resident | General testing |
| resident2 | resident2@test.com | password123 | Resident | Multi-user / confirmation testing |
| resident3 | resident3@test.com | password123 | Resident | Confirmation threshold testing |
| mdrrmo_admin | mdrrmo@bulan.gov.ph | mdrrmo2024 | MDRRMO | Admin testing |
| mdrrmo_test | mdrrmo2@bulan.gov.ph | mdrrmo2024 | MDRRMO | Admin testing 2 |

---

## 4. Authentication Test Cases

### TC-AUTH-001: User Registration (Resident)

**Priority:** P1
**Type:** Functional
**Precondition:** App installed, on welcome screen

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap "Login / Register" button | Navigate to login screen |
| 2 | Tap "Register" link | Navigate to registration screen |
| 3 | Verify form fields | Full Name, Email, Password, Confirm Password fields visible; no Phone Number field |
| 4 | Enter valid full name: "Juan Dela Cruz" | Field accepts input |
| 5 | Enter valid email: "juan.test@email.com" | Field accepts input |
| 6 | Enter password: "password123" | Password masked, field accepts |
| 7 | Enter confirm password: "password123" | Password masked, field accepts |
| 8 | Tap "Register" button | Loading indicator appears |
| 9 | Wait for response | Success message: "Registration successful" |
| 10 | Check navigation | Navigate to map screen (auto-login) |
| 11 | Verify user logged in | User name displays in profile |

**Expected:** Registration successful without phone number, user auto-logged in
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked
**Notes:** Phone number field was removed from registration. Backend accepts empty phone_number.

---

### TC-AUTH-002: User Registration — Duplicate Email

**Priority:** P1
**Type:** Functional (Negative)
**Precondition:** User with email "resident@test.com" already exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open registration screen | Registration form displayed (no phone field) |
| 2 | Enter full name: "Test User" | Field accepts input |
| 3 | Enter email: "resident@test.com" (existing) | Field accepts input |
| 4 | Enter password: "password123" | Field accepts input |
| 5 | Enter confirm password: "password123" | Field accepts input |
| 6 | Tap "Register" button | Loading indicator appears |
| 7 | Wait for response | Error message: "Email already exists" |
| 8 | Verify still on registration screen | Form still visible, fields retain values |

**Expected:** Error message, registration blocked
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AUTH-003: User Registration — Weak Password

**Priority:** P2
**Type:** Functional (Negative)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open registration screen | Registration form displayed |
| 2 | Enter all required fields (name, email) | Fields accept input |
| 3 | Enter password: "1234" (too short) | Field accepts input |
| 4 | Enter confirm password: "1234" | Field accepts input |
| 5 | Tap "Register" button | Error: "Password must be at least 8 characters" |
| 6 | Verify not registered | Registration blocked |

**Expected:** Validation error, registration blocked
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AUTH-004: User Login — Valid Credentials

**Priority:** P0
**Type:** Functional
**Precondition:** User "resident@test.com" exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open app, navigate to login screen | Login form displayed |
| 2 | Enter email: "resident@test.com" | Field accepts input |
| 3 | Enter password: "password123" | Password masked |
| 4 | Tap "Login" button | Loading indicator appears |
| 5 | Wait for authentication | Success message: "Welcome, [Name]!" |
| 6 | Check navigation | Navigate to map screen |
| 7 | Verify session | User logged in, profile accessible |

**Expected:** Login successful, map screen displayed
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AUTH-005: User Login — Invalid Password

**Priority:** P1
**Type:** Functional (Negative)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open login screen | Login form displayed |
| 2 | Enter email: "resident@test.com" | Field accepts input |
| 3 | Enter password: "wrongpassword" | Password masked |
| 4 | Tap "Login" button | Loading indicator appears |
| 5 | Wait for response | Error: "Invalid credentials" |
| 6 | Verify not logged in | Still on login screen |

**Expected:** Error message, login blocked
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AUTH-006: User Logout

**Priority:** P1
**Type:** Functional
**Precondition:** User logged in

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Settings screen | Settings menu displayed |
| 2 | Scroll to bottom | Logout button visible (red) |
| 3 | Tap "Logout" button | Confirmation dialog: "Are you sure?" |
| 4 | Tap "Yes" | Loading indicator briefly |
| 5 | Wait for logout | Navigate to welcome screen |
| 6 | Verify session cleared | Cannot access protected screens |
| 7 | Check back button behavior | Cannot navigate back to map screen |

**Expected:** Logout successful, session cleared
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AUTH-007: Admin Login — Role-Based Routing

**Priority:** P1
**Type:** Functional
**Precondition:** MDRRMO user exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open login screen | Login form displayed |
| 2 | Enter email: "mdrrmo@bulan.gov.ph" | Field accepts input |
| 3 | Enter password: "mdrrmo2024" | Password masked |
| 4 | Tap "Login" button | Loading indicator appears |
| 5 | Wait for authentication | Success message displayed |
| 6 | Check navigation | Navigate to Admin Home Screen (not map) |
| 7 | Verify UI | Bottom navigation with tabs visible |
| 8 | Check tabs | Dashboard, Reports, Map Monitor, Centers, Analytics, Settings |

**Expected:** Admin logged in, admin interface displayed
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 5. Evacuation Centers Test Cases

### TC-CENTER-001: View Evacuation Centers Panel (Collapsible)

**Priority:** P0
**Type:** Functional
**Precondition:** User logged in, at least 3 centers exist

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to map screen | Map displayed, bottom panel visible |
| 2 | Verify panel visible at bottom | "Nearby Evacuation Centers" header shown with count badge |
| 3 | Verify panel is expanded by default | List of centers visible below header |
| 4 | Check center card content | Shows: name, distance (km) |
| 5 | Verify distance calculation | Distance calculated from user location |
| 6 | Scroll list | List scrollable if > 3 centers |

**Expected:** All centers displayed correctly
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CENTER-002: View Center Details

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From centers panel, tap "View Routes" on a center | Route selection screen opens |
| 2 | Verify center name shown | Name displayed |
| 3 | Check GPS coordinates used | Latitude/longitude used for routing |
| 4 | Verify routes calculated | Route options shown |

**Expected:** Center correctly used for route calculation
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CENTER-003: Centers on Map

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to map screen | Map displayed with user location |
| 2 | Verify center markers | Red markers with location icon for each center |
| 3 | Count markers | Matches number of centers |
| 4 | Tap a center marker | Routes calculated or panel highlights center |
| 5 | Zoom in/out | Markers remain visible at appropriate zoom |

**Expected:** All centers displayed as markers
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CENTER-004: Offline Centers Access

**Priority:** P1
**Type:** Functional (Offline)
**Precondition:** Centers cached (accessed once online)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Turn off WiFi and mobile data | Device offline |
| 2 | Open app (if closed) or stay in app | App functions |
| 3 | Navigate to map screen | Bottom panel shows |
| 4 | Verify centers displayed | All cached centers visible |
| 5 | Check distances | Calculated from current GPS |
| 6 | Verify "Offline" indicator | OfflineBanner widget visible at top |

**Expected:** Centers accessible offline from cache
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CENTER-005: Collapsible Panel Toggle

**Priority:** P1
**Type:** Functional
**Precondition:** User on map screen, panel visible and expanded

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Observe panel at bottom | Panel expanded, showing center list |
| 2 | Tap the drag handle bar at the top of the panel | Panel animates to collapsed state |
| 3 | Verify collapsed state | Center list hidden, only header + count badge visible |
| 4 | Verify chevron icon | Chevron icon points downward when collapsed |
| 5 | Check FAB position | Recenter FAB moves up to ~84px from bottom (not overlapping panel) |
| 6 | Tap the drag handle bar again | Panel expands with smooth animation |
| 7 | Verify expanded state | Center list fully visible again (220px height) |
| 8 | Verify chevron icon | Chevron icon points upward when expanded |
| 9 | Alternatively: tap the chevron icon | Same toggle behavior |

**Expected:** Panel collapses/expands with 300ms ease-in-out animation
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CENTER-006: Collapse Panel During Route Selection

**Priority:** P2
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Collapse the panel | Panel collapsed |
| 2 | Tap an evacuation center marker on the map | Route calculation begins |
| 3 | Verify panel state does not interfere | No UI overlap |
| 4 | After route selected, check panel | Bottom sheet replaced by active navigation bar |

**Expected:** Panel collapse state does not block center selection
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 6. Routing Test Cases

### TC-ROUTE-001: Calculate Route — Online (OSRM)

**Priority:** P0
**Type:** Functional
**Precondition:** User logged in, internet available, GPS active

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From map screen, select evacuation center | Center selected |
| 2 | Tap "View Routes" button | Loading indicator: "Calculating routes..." |
| 3 | Wait for route calculation (max 5 sec) | Route displayed on map |
| 4 | Verify route color | Color-coded by risk level (green/orange/red) |
| 5 | Check route details | Shows: distance (km), estimated time |
| 6 | Verify polyline on map | Route follows real roads |
| 7 | Tap "Start Navigation" | Navigate to live navigation screen |

**Expected:** Routes calculated via OSRM, displayed correctly
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-002: Route Display — Risk Color Coding

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Calculate route to a center | Route displayed |
| 2 | Identify safest route | Green polyline |
| 3 | Check risk classification | Green: safe, Orange: caution, Red: high risk |
| 4 | Verify risk bar (if displayed) | Horizontal bar filled to risk % |

**Expected:** Routes color-coded by risk level correctly
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-003: Start Navigation

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Calculate route, tap "Start Navigation" | Navigate to LiveNavigationScreen |
| 2 | Verify map display | Map with route polyline, user location marker |
| 3 | Check destination banner | Shows: "Destination: [Name]", barangay, distance remaining |
| 4 | Verify user marker | Blue marker at current GPS position |
| 5 | Check route line | Colored polyline from user to destination |
| 6 | Verify instruction bar | Turn-by-turn banner at top |
| 7 | Press Android back button | Exit confirmation dialog appears |
| 8 | Tap "Continue Navigation" | Dialog closes, navigation resumes |

**Expected:** Navigation screen displays correctly with all overlays
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-004: Route Caching

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Calculate route online (first time) | Route calculated via OSRM |
| 2 | Return to map | Back button |
| 3 | Turn off internet | Device offline |
| 4 | Request same route again | Loading indicator |
| 5 | Wait for response | Route displays from cache |
| 6 | Check route accuracy | Same route as before |

**Expected:** Route cached, accessible offline
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-005: Route Calculation Failure (No Internet, No Cache)

**Priority:** P1
**Type:** Functional (Negative)
**Precondition:** First time requesting route, device offline

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Turn off internet | Device offline |
| 2 | Open app, select center | Center details |
| 3 | Tap "View Routes" | Loading indicator |
| 4 | Wait for response (10–15 sec) | Error message displayed |
| 5 | Verify error text | Clear message about no internet connection |
| 6 | Verify no routes shown | Empty state or error screen, no broken lines |

**Expected:** Clear error message, no broken routes
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-006: Location Validation (Emulator Default)

**Priority:** P1
**Type:** Functional
**Precondition:** Using Android emulator with default GPS (USA location)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open app on emulator | Map loads |
| 2 | Check user location | Blue dot at Bulan, Sorsogon (not USA) |
| 3 | Verify fallback logic active | Out-of-range coordinates replaced with Bulan default (12.6699, 123.8758) |
| 4 | Request route to center | Route calculation starts |
| 5 | Check route validity | Route follows roads in Bulan, not USA |

**Expected:** App detects invalid location, uses Bulan default
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-007: Multiple Route Options

**Priority:** P2
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Calculate routes to center | Routes displayed |
| 2 | Compare distances | Routes may have different distances |
| 3 | Verify safest route highlighted | Lowest risk marked clearly |
| 4 | Tap "Start Navigation" on safest | Navigation begins |

**Expected:** Multiple distinct routes with varying risk/distance
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 7. Hazard Reporting Test Cases

### TC-HAZARD-001: Submit Hazard Report — Complete

**Priority:** P0
**Type:** Functional
**Precondition:** User logged in, online, location permission granted

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From map, tap "Report Hazard" button | Navigate to Report Hazard screen |
| 2 | Tap hazard type from grid | 9 hazard type tiles shown |
| 3 | Select: "Flooded Road" | Tile highlighted with border color |
| 4 | Enter description: "Main highway near market severely flooded, water level rising" | Text area accepts input (>10 chars) |
| 5 | Verify location | Current GPS location displayed |
| 6 | Observe "Attach Media (Optional)" section | Header and constraints hint visible without overflow |
| 7 | Optional: Tap "Add Photo" | Camera/gallery picker opens |
| 8 | Select photo | Photo preview: thumbnail + filename + remove button |
| 9 | Tap "Submit Report" button | Loading indicator |
| 10 | Wait for response | Success: "Report submitted successfully" |
| 11 | Check navigation | Return to map screen |

**Expected:** Report submitted successfully, no layout overflow
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-002: Submit Report — Missing Required Fields

**Priority:** P1
**Type:** Functional (Negative)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Report Hazard screen | Form displayed |
| 2 | Leave hazard type unselected | No tile highlighted |
| 3 | Enter description: "Test" (< 10 chars) | Text accepted |
| 4 | Tap "Submit Report" | Validation errors displayed |
| 5 | Verify error messages | "Please select hazard type" and "Description must be at least 10 characters" |
| 6 | Report not submitted | Still on form screen |

**Expected:** Validation errors, submission blocked
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-003: Submit Report — Offline Queue

**Priority:** P1
**Type:** Functional (Offline)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Turn off internet | Device offline |
| 2 | Open Report Hazard screen | Form displayed |
| 3 | Fill all required fields | Hazard type, description |
| 4 | Tap "Submit Report" | Processing |
| 5 | Check response | Success: "Report queued for submission when online" |
| 6 | Verify report saved locally | In offline queue |
| 7 | Turn on internet | Device online |
| 8 | Wait or trigger sync | Auto-sync starts |
| 9 | Verify report submitted | Removed from queue |

**Expected:** Report queued offline, auto-synced when online
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-004: Report with Media Upload — Image

**Priority:** P2
**Type:** Functional
**Precondition:** Camera/gallery permission granted

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Report Hazard screen | Form displayed |
| 2 | Fill hazard type and description | Required fields complete |
| 3 | Tap "Add Photo" button | Image picker opens |
| 4 | Select photo from gallery | Photo selected |
| 5 | Verify photo preview | 60×60 thumbnail displayed in green preview box |
| 6 | Check constraints hint text | "JPG or PNG, max 2 MB" or "JPG/PNG max 2 MB · MP4 max 10 MB / 10 s" — wraps cleanly, no overflow |
| 7 | Tap "Submit Report" | Upload starts |
| 8 | Verify success | Report submitted with photo |

**Expected:** Photo uploaded successfully; header row does not overflow on small screens
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-005: Report Form Layout — Small Screen (Overflow Check)

**Priority:** P1
**Type:** Functional (UI)
**Precondition:** Test on smallest supported screen (5.4" emulator, 1080×1920)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Report Hazard screen on small screen | Form renders |
| 2 | Scroll to "Attach Media (Optional)" section | Section visible |
| 3 | Observe the header row | "Attach Media (Optional)" on the left, constraints hint on the right |
| 4 | Verify no pixel overflow | No yellow/black overflow stripe, no clipped text |
| 5 | Verify constraints hint wraps | Text wraps to 2 lines if needed |
| 6 | Verify alignment | Both items align correctly in row |

**Expected:** No overflow error, text wraps gracefully
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-006: Hazard Type Selection — All Types

**Priority:** P2
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Report Hazard screen | Form displayed |
| 2 | Observe hazard type grid | 9 tiles in a 3-column grid |
| 3 | Verify all types present | Flooded Road, Landslide, Fallen Tree, Road Damage, Fallen Electric Post, Road Blocked, Bridge Damage, Storm Surge, Other |
| 4 | Check icons | Each type has unique icon and label |
| 5 | Select "Landslide" | Tile border and background color changes to highlight |
| 6 | Select "Other" | Previous deselected, Other highlighted |

**Expected:** All 9 hazard types selectable with visual feedback
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-007: View Own Pending Report on Map

**Priority:** P1
**Type:** Functional
**Precondition:** User has submitted a pending report

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Submit a hazard report | Report submitted, status: pending |
| 2 | Return to map screen | Map visible |
| 3 | Locate the report marker | Yellow circle marker at report location |
| 4 | Tap the marker | Popup shows report details |
| 5 | Verify "Pending Review" badge | Orange badge visible |
| 6 | Verify "Delete Report" button visible | Only for own pending reports |

**Expected:** Own pending reports visible as yellow markers; deletable
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 8. Admin Dashboard Test Cases

### TC-ADMIN-001: Dashboard Statistics Display

**Priority:** P1
**Type:** Functional
**Precondition:** MDRRMO user logged in

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as MDRRMO user | Admin home screen displayed |
| 2 | Verify on Dashboard tab (default) | Dashboard content visible |
| 3 | Check summary cards | Cards displayed in grid |
| 4 | Verify "Total Reports" card | Shows total count |
| 5 | Verify "Pending Reports" card | Shows pending count |
| 6 | Verify "Verified Hazards" card | Shows approved count |
| 7 | Verify "High Risk Roads" card | Shows count of road segments with risk score ≥ 0.7 |
| 8 | Verify "Evacuation Centers" card | Shows active center count |
| 9 | Check card design | Icon, label, count, colored border |

**Expected:** All statistics displayed correctly; High Risk Roads reflects real road segment data
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-002: High Risk Roads Tile — Real-Time Update

**Priority:** P1
**Type:** Functional
**Precondition:** At least one road segment exists with predicted_risk_score field

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Note current "High Risk Roads" count on dashboard | Record current value |
| 2 | Navigate to Reports tab | Reports list visible |
| 3 | Approve a hazard report in a new area | Report status changes to "Approved" |
| 4 | Navigate back to Dashboard | Dashboard refreshes |
| 5 | Check "High Risk Roads" tile | Count reflects segments where predicted_risk_score ≥ 0.7 |
| 6 | Verify the count is not hardcoded/stale | Value changes if road risk data changes |

**Expected:** High Risk Roads tile queries real RoadSegment.predicted_risk_score data
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-003: View Reports List

**Priority:** P0
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From dashboard, tap Reports tab | Reports screen displayed |
| 2 | Verify report list | All reports shown |
| 3 | Check report card content | Hazard type, location, date, AI scores, status |
| 4 | Verify status badges | Color-coded: Orange (Pending), Green (Approved), Red (Rejected) |
| 5 | Check AI scores | NB % and Consensus % displayed |
| 6 | Tap "View Details" | Navigate to detail screen |
| 7 | Verify no barangay filter | No barangay dropdown in filter row |

**Expected:** All reports listed; barangay filter absent; filtering by status only
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-004: Filter Reports by Status

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On Reports tab, locate filter | Status dropdown only (no barangay filter) |
| 2 | Tap filter dropdown | Options: All, Pending, Approved, Rejected |
| 3 | Select "Pending" | Dropdown closes |
| 4 | Verify list updates | Only pending reports shown |
| 5 | Select "Approved" filter | Only approved reports shown |
| 6 | Select "All" | All reports shown again |

**Expected:** Status filter works; no barangay filter present
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-005: Approve Hazard Report

**Priority:** P0
**Type:** Functional
**Precondition:** At least 1 pending report exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On Reports tab, find pending report | Report with "Pending" badge |
| 2 | Tap "View Details" | Report detail screen |
| 3 | Scroll to AI Analysis section | NB, Consensus, RF scores displayed with clean labels |
| 4 | Verify no threshold debug text | "Thresholds: ≥0.80 auto-approve · ..." text NOT present |
| 5 | Scroll to Decision Controls | Approve and Reject buttons visible |
| 6 | Optional: Add admin comment | Comment field accepts text |
| 7 | Tap "Approve" button | Confirmation dialog |
| 8 | Confirm action | Processing indicator |
| 9 | Wait for response | Success: "Report approved" |
| 10 | Check status update | Badge changes to "Approved" (Green) |

**Expected:** Report approved; threshold debug text absent; status updated
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-006: Reject Hazard Report

**Priority:** P1
**Type:** Functional
**Precondition:** At least 1 pending report exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open pending report details | Report detail screen |
| 2 | Scroll to Decision Controls | Reject button visible |
| 3 | Tap "Reject" button | Comment field or dialog appears |
| 4 | Enter rejection reason: "Duplicate report" | Comment accepted |
| 5 | Confirm rejection | Processing |
| 6 | Wait for response | Success: "Report rejected" |
| 7 | Check status update | Badge changes to "Rejected" (Red) |

**Expected:** Report rejected with comment, status updated
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-007: Restore Rejected Report (No Reason Required)

**Priority:** P1
**Type:** Functional
**Precondition:** At least 1 rejected report exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On Reports tab, filter by "Rejected" | Rejected reports shown |
| 2 | Open a rejected report | Report detail screen |
| 3 | Locate "Restore" button | Button visible |
| 4 | Tap "Restore" button | Simple confirmation dialog appears |
| 5 | Verify dialog content | "Restore this report?" with [Cancel] [Restore] buttons |
| 6 | Verify NO reason text field in dialog | No text input required |
| 7 | Tap "Restore" | Processing |
| 8 | Wait for response | Report status changes to "Pending" |
| 9 | Verify backend receives default reason | "Restored by MDRRMO" sent silently |

**Expected:** One-tap restore with no reason required; simple confirmation only
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-008: Technical Details UI in Report Detail

**Priority:** P2
**Type:** Functional (UI)
**Precondition:** MDRRMO viewing an approved or pending report with AI scores

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open any hazard report details | Report detail screen |
| 2 | Scroll to "Technical Details" or "AI Analysis" section | Section visible |
| 3 | Verify labels are human-readable | e.g., "Naive Bayes Score", "Consensus Score", "Final Score" |
| 4 | Check spacing | Adequate padding between rows |
| 5 | Verify numeric values formatted | Percentage (e.g., "72%") not raw decimal |
| 6 | Confirm NO debug text | No "Thresholds: ≥0.80 auto-approve · 0.50–0.79 pending · <0.50 reject" text |
| 7 | Scroll entire screen | No overflow, no clipped content |

**Expected:** Clean, readable technical details without debug strings
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-009: Map Monitor — Layer Toggles

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From admin home, tap Map Monitor tab | Full-screen map displayed |
| 2 | Verify default layers | Markers visible by default |
| 3 | Tap "Layers" icon | Bottom sheet with toggles opens |
| 4 | Check toggle options | Evacuation Centers, Verified Hazards, Pending Hazards (no Risk Overlay toggle) |
| 5 | Verify Risk Overlay toggle is ABSENT | It was removed as it was non-functional |
| 6 | Toggle OFF "Evacuation Centers" | Blue markers disappear |
| 7 | Toggle ON "Evacuation Centers" | Blue markers reappear |
| 8 | Toggle OFF "Pending Hazards" | Pending markers disappear |
| 9 | Verify state persists | Toggles remember state when bottom sheet reopened |

**Expected:** Layer toggles work; Risk Overlay toggle absent; no non-functional controls
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-010: Add Evacuation Center

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap Centers tab | Centers management screen |
| 2 | Verify NO barangay filter dropdown | Barangay filter absent |
| 3 | Tap "Add Center" FAB | Add Center form screen |
| 4 | Enter name: "New Evacuation Center" | Field accepts input |
| 5 | Select barangay: "Zone 1" | Dropdown selection |
| 6 | Enter address: "123 Main St" | Field accepts input |
| 7 | Enter contact: "09171234567" | Field accepts input |
| 8 | Enter latitude: "12.6705" | Field accepts input |
| 9 | Enter longitude: "123.8762" | Field accepts input |
| 10 | Tap "Save" button | Processing |
| 11 | Wait for response | Success: "Center added successfully" |
| 12 | Verify in list | New center appears |
| 13 | Check resident app | New center visible to residents |

**Expected:** Center added; no barangay filter present
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-011: Delete Evacuation Center

**Priority:** P1
**Type:** Functional
**Precondition:** MDRRMO logged in, at least one center exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Centers tab | List of centers displayed |
| 2 | Locate a center card | Center card visible |
| 3 | Identify delete (trash) icon on center card | Trash icon button visible |
| 4 | Tap the trash icon | Confirmation dialog appears |
| 5 | Verify dialog content | "Delete [Center Name]?" with [Cancel] [Delete] buttons |
| 6 | Tap "Cancel" | Dialog closes, center still in list |
| 7 | Tap trash icon again | Confirmation dialog appears again |
| 8 | Tap "Delete" | Processing indicator |
| 9 | Wait for response | Success message displayed |
| 10 | Verify center removed from list | Center no longer in list |
| 11 | Check resident app | Deleted center no longer visible to residents |

**Expected:** Center deleted with confirmation; removed from all views
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-012: Edit Evacuation Center

**Priority:** P2
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On Centers tab, find a center | Center card displayed |
| 2 | Tap "Edit" button | Edit form opens |
| 3 | Verify pre-filled data | Current center data shown |
| 4 | Modify name: "Updated Name" | Field updates |
| 5 | Modify contact: "09187654321" | Field updates |
| 6 | Tap "Update" button | Processing |
| 7 | Wait for response | Success: "Center updated" |
| 8 | Verify changes | Updated info displayed in list |

**Expected:** Center updated successfully
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-013: User Management — No Barangay Filter

**Priority:** P1
**Type:** Functional
**Precondition:** MDRRMO logged in

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to User Management (Settings or admin section) | User list displayed |
| 2 | Observe filter controls | Status filter visible only |
| 3 | Verify NO barangay filter | No barangay dropdown present |
| 4 | Filter by status: "Active" | Only active users shown |
| 5 | Filter by status: "All" | All users shown |

**Expected:** User management uses status filter only; no barangay filter
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-014: Admin Settings — No Sync Baseline Data Button

**Priority:** P2
**Type:** Functional
**Precondition:** MDRRMO logged in

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Settings tab | Admin settings screen |
| 2 | Scroll through all settings sections | All action cards visible |
| 3 | Verify "Sync Baseline Data" is ABSENT | No such button or section visible |
| 4 | Verify other settings still present | Retrain AI Models, Logout, etc. |

**Expected:** Sync Baseline Data button removed; other settings intact
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-015: Analytics — Most Dangerous Barangays

**Priority:** P2
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap Analytics tab | Analytics screen displayed |
| 2 | Scroll to "Most Dangerous Barangays" | Section visible |
| 3 | Verify list displayed | Top barangays shown |
| 4 | Check data format | Barangay name, risk score, hazard count |
| 5 | Verify sorting | Sorted by risk score (highest first) |
| 6 | Check risk scores | Values between 0.0 and 1.0 |

**Expected:** Analytics data displayed correctly
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-016: Admin Logout

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap Settings tab | Admin settings screen |
| 2 | Scroll to bottom | Logout button visible (red) |
| 3 | Tap "Logout" button | Confirmation dialog |
| 4 | Tap "Cancel" | Dialog closes, still logged in |
| 5 | Tap "Logout" again | Confirmation dialog |
| 6 | Tap "Confirm" | Processing |
| 7 | Wait for logout | Navigate to welcome screen |
| 8 | Verify session cleared | Cannot access admin screens |

**Expected:** Admin logout successful
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-017: Report Soft Delete — Data Integrity

**Priority:** P0
**Type:** Functional
**Precondition:** MDRRMO logged in; an approved hazard report exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Reports tab, find an approved report | Report visible in list |
| 2 | Open report detail | Report detail screen loads |
| 3 | Tap "Delete" and confirm deletion | Success response; report removed from list |
| 4 | Verify report no longer shows in Reports list | Report absent from all list views |
| 5 | Verify dashboard stats decreased | Total/Verified Hazards count updated |
| 6 | Attempt GET /api/reports/{id}/ for deleted report (API call) | Returns 404 |
| 7 | Check AI validation endpoint | Deleted report NOT included in Naive Bayes features |
| 8 | Check route risk calculation | Deleted report NOT contributing to road risk scores |
| 9 | Verify report is NOT in map markers | No marker on admin map for deleted report |

**Expected:** Soft delete removes report from all operational queries; is_deleted=True in DB; report inaccessible via API
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 9. AI Algorithm Test Cases

### TC-AI-001: Naive Bayes — Valid Report (High Confidence)

**Priority:** P1
**Type:** Functional (Algorithm)
**Precondition:** Model trained with data

| Step | Action | Test Input | Expected Output |
|------|--------|------------|-----------------|
| 1 | Submit report via API | `{"hazard_type": "flooded_road", "description": "Severe flooding on main highway near market"}` | Report accepted |
| 2 | Check Naive Bayes score | Extract from response | Score >= 0.70 |
| 3 | Verify classification | Check logs | Classified as likely valid |

**Expected:** NB score >= 0.70, classified as valid
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-002: Naive Bayes — Invalid Report (Low Confidence)

**Priority:** P1
**Type:** Functional (Algorithm)

| Step | Action | Test Input | Expected Output |
|------|--------|------------|-----------------|
| 1 | Submit suspicious report | `{"hazard_type": "other", "description": "Test"}` | Report accepted (but flagged) |
| 2 | Check Naive Bayes score | Extract from response | Score < 0.5 |
| 3 | Verify status | Check report status | "Pending" for manual review |

**Expected:** Low NB score, report requires manual review
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-003: Consensus Scoring — Multiple Reports

**Priority:** P1
**Type:** Functional (Algorithm)
**Precondition:** No existing reports at test location

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Submit report 1 at (12.6700, 123.8755) | NB score: ~0.70 |
| 2 | Submit report 2 at (12.6701, 123.8756) (≈30 m away) | NB score: ~0.75 |
| 3 | Check consensus for report 2 | Nearby report count: 1 |
| 4 | Verify score boosted | Report 2 consensus score > base NB score |
| 5 | Submit 3 more reports within 100m | Consensus count: 4 total |
| 6 | Verify increased confidence | Score approaches 1.0 with more reports |

**Expected:** Consensus boosts confidence for nearby corroborating reports
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-004: Random Forest — Road Risk Prediction

**Priority:** P1
**Type:** Functional (Algorithm)
**Precondition:** Model trained, road segments exist

| Step | Action | Test Input | Expected Output |
|------|--------|------------|-----------------|
| 1 | Provide high-risk segment features | `{"nearby_hazard_count": 5, "avg_severity": 0.8}` | Risk score: 0.7–0.9 |
| 2 | Verify classification | Check risk level | "Red" (High Risk) |
| 3 | Test low-risk segment | `{"nearby_hazard_count": 0, "avg_severity": 0.1}` | Risk score: 0.0–0.3 (Green) |

**Expected:** RF predicts high risk for high-hazard segments, low risk otherwise
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-005: Modified Dijkstra — Safest Route

**Priority:** P0
**Type:** Functional (Algorithm)
**Precondition:** Road network with varying risk scores

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Set up test road network | 2 routes: Route A (2 km, risk 0.9), Route B (4 km, risk 0.1) |
| 2 | Calculate weights | A: 2 + (0.9 × 500) = 452; B: 4 + (0.1 × 500) = 54 |
| 3 | Run Modified Dijkstra | Start and end nodes defined |
| 4 | Verify route selection | Route B chosen (lower weight despite longer distance) |
| 5 | Check risk level | Route B classified as "Green" |

**Expected:** Algorithm selects safer route despite longer distance
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-006: AI Model Retraining

**Priority:** P2
**Type:** Functional
**Precondition:** Admin logged in

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Admin Settings | Settings screen |
| 2 | Find "Retrain AI Models" button | Button visible |
| 3 | Tap "Retrain AI Models" | Confirmation dialog |
| 4 | Confirm action | Processing indicator |
| 5 | Wait for retraining | Success message |
| 6 | Verify new predictions | Use retrained models for subsequent reports |

**Expected:** Models retrained successfully
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-007: Graduated Hazard Segment Impact — Perpendicular Distance

**Priority:** P1
**Type:** Algorithm / Unit
**Precondition:** Backend running; road segment exists; approved hazard report exists near segment

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create approved hazard report at **2 m** from road centerline (flooded_road) | Hazard saved with APPROVED status |
| 2 | Request route calculation including this segment | Route returned |
| 3 | Inspect effective_risk for the segment | High dynamic contribution (≥ 0.20); close hazard has near-full weight |
| 4 | Move hazard to **50 m** from centerline | Lower effective_risk on same segment |
| 5 | Move hazard to **90 m** from centerline (beyond 80 m flood radius) | Dynamic contribution = 0.0 for that hazard; effective_risk drops to base only |

**Expected:** Impact decreases continuously with distance; zero beyond type-specific radius
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-008: Flood Gradual Decay — Wide Influence Band

**Priority:** P1
**Type:** Algorithm
**Precondition:** Approved flood hazard report; road segment within 80 m

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Place flood hazard at **10 m** from road centerline | Dynamic contribution ≈ decay(10, 80, gradual) × 0.3 × severity ≈ high |
| 2 | Place flood hazard at **40 m** from road centerline | Dynamic contribution reduced but still meaningful (gradual decay) |
| 3 | Place flood hazard at **70 m** from road centerline | Small but non-zero contribution (still within 80 m radius) |
| 4 | Place flood hazard at **85 m** from road centerline | Contribution = 0.0 (outside 80 m radius) |
| 5 | Compare with fallen_tree at 40 m | fallen_tree contribution = 0.0 (beyond 15 m radius); flood still contributes |

**Expected:** Flood maintains graduated influence up to 80 m; other types cut off at their tighter radii
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-009: road_blocked Within 25 m Makes Segment Impassable

**Priority:** P0
**Type:** Algorithm / Functional
**Precondition:** Approved road_blocked hazard report; road segment within 25 m of centerline

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create approved road_blocked hazard at **10 m** from segment centerline | Hazard saved |
| 2 | Request route to evacuation center requiring this segment | Route calculation runs |
| 3 | Inspect effective_risk for the segment | effective_risk = 1.0 (impassable) |
| 4 | Observe route result | Dijkstra avoids this segment; alternate route returned |
| 5 | Move road_blocked hazard to **30 m** from centerline | effective_risk < 1.0; graduated penalty only; segment may still be used |

**Expected:** road_blocked within 25 m → immediate impassable (1.0); beyond 25 m → graduated penalty only
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-OFFLINE-001: App Launch Offline

**Priority:** P1
**Type:** Functional (Offline)
**Precondition:** Data cached from previous online session

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Turn off WiFi and mobile data | Device offline |
| 2 | Close app completely | App not running |
| 3 | Open app | App launches successfully |
| 4 | Check offline indicator | OfflineBanner widget visible at top |
| 5 | Navigate to map | Map displays with cached tiles |
| 6 | Check evacuation centers | Centers loaded from cache |

**Expected:** App functions offline with cached data
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-OFFLINE-002: Offline Hazard Report Queue

**Priority:** P1
**Type:** Functional (Offline)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Ensure device offline | No internet connection |
| 2 | Submit hazard report | Form accepts submission |
| 3 | Check response | "Report queued for submission" |
| 4 | Verify local storage | Report saved in offline queue |
| 5 | Submit 2nd report offline | Also queued |
| 6 | Turn on internet | Device online |
| 7 | Trigger sync (wait or pull) | Auto-sync starts |
| 8 | Wait for completion | All queued reports sent |
| 9 | Check queue | Empty (reports delivered) |

**Expected:** Reports queued offline, auto-synced online
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-OFFLINE-003: Offline Route Access (Cached)

**Priority:** P1
**Type:** Functional (Offline)
**Precondition:** Route calculated online previously

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Online: Calculate route to Center A | Route displayed, cached |
| 2 | Return to map | Back |
| 3 | Turn off internet | Device offline |
| 4 | Request route to Center A again | Loading... |
| 5 | Verify route loads | Route displayed from cache |
| 6 | Verify route accuracy | Same route as before |

**Expected:** Cached route accessible offline
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-OFFLINE-004: Offline Route Request (No Cache)

**Priority:** P1
**Type:** Functional (Offline/Negative)
**Precondition:** First time requesting route, offline

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Clear app data (fresh install state) | Cache empty |
| 2 | Ensure device offline | No internet |
| 3 | Open app, select evacuation center | Center details |
| 4 | Tap "View Routes" | Loading indicator |
| 5 | Wait for timeout | Error message displayed |
| 6 | Verify error text | Clear message indicating no internet |
| 7 | Check no broken route displayed | No partial polyline shown |

**Expected:** Clear error, no broken routes
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-OFFLINE-005: Intermittent Connectivity

**Priority:** P2
**Type:** Functional (Network)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start with internet | App online, OfflineBanner hidden |
| 2 | Calculate route | OSRM success |
| 3 | Turn off internet mid-operation | OfflineBanner appears |
| 4 | Check error handling | Graceful failure |
| 5 | Turn on internet | OfflineBanner disappears |
| 6 | Verify app recovers | Continued use possible |

**Expected:** App handles connectivity changes gracefully with visual indicator
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 11. Performance Test Cases

### TC-PERF-001: App Launch Time

**Priority:** P1
**Type:** Performance

| Metric | Requirement | Measurement Method |
|--------|-------------|-------------------|
| Cold start (app not in memory) | < 2 seconds | Tap icon → Map screen displayed |
| Warm start (app in memory) | < 1 second | Switch from background → Map screen |
| Hot start (app in foreground) | < 0.5 seconds | Resume from another app |

**Test Steps:**
1. Close app completely
2. Start stopwatch
3. Tap app icon
4. Stop when map screen fully loaded
5. Repeat 5 times, average results

**Expected:** Average < 2 seconds
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-PERF-002: Map Load Time

**Priority:** P1
**Type:** Performance

| Step | Action | Expected Time |
|------|--------|---------------|
| 1 | Open map screen (first time) | < 3 seconds |
| 2 | Verify tiles loaded | All visible tiles displayed |
| 3 | Check user location | Blue dot visible |
| 4 | Verify markers | Evacuation centers displayed |
| 5 | Verify bottom panel | Evacuation center list loaded |

**Expected:** < 3 seconds
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-PERF-003: Route Calculation Time (OSRM)

**Priority:** P1
**Type:** Performance

| Scenario | Expected Time |
|----------|---------------|
| Short route (< 2 km) | < 3 seconds |
| Medium route (2–5 km) | < 5 seconds |
| Long route (> 5 km) | < 7 seconds |

**Expected:** Within time limits above
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-PERF-004: API Response Time

**Priority:** P1
**Type:** Performance

| Endpoint | Expected Response Time |
|----------|------------------------|
| POST /auth/login/ | < 1 second |
| GET /evacuation-centers/ | < 1 second |
| POST /hazards/ | < 2 seconds |
| GET /mdrrmo/dashboard-stats/ | < 1 second |
| PUT /hazards/{id}/approve/ | < 1 second |

**Test Method:** Postman with timer
**Expected:** All endpoints within limits
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-PERF-005: Live Navigation Memory Usage

**Priority:** P2
**Type:** Performance

| Scenario | Maximum RAM |
|----------|-------------|
| Idle (map displayed) | 150 MB |
| Navigation active (rotation, GPS, voice) | 220 MB |
| Navigation with hazard markers | 230 MB |
| After 30 min navigation | < 250 MB |

**Test Method:** Android Profiler during navigation session
**Expected:** No memory leak; stable over 30 minutes
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-PERF-006: GPS Update Frequency During Navigation

**Priority:** P1
**Type:** Performance

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start live navigation | Navigation screen active |
| 2 | Walk/drive while observing marker | Marker moves on map |
| 3 | Measure update interval | GPS updates every ≤ 2 seconds |
| 4 | Verify smooth movement | Marker transition smooth, not jumpy |
| 5 | Check bearing update | Map rotates as heading changes |

**Expected:** GPS updates every ≤ 2 seconds; smooth marker animation
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-PERF-007: Battery Consumption During Navigation

**Priority:** P2
**Type:** Performance
**Precondition:** Fully charged device

| Scenario | Duration | Max Battery Drain |
|----------|----------|-------------------|
| Active navigation (GPS + voice + rotation) | 1 hour | 12% |
| Idle (app open, map displayed) | 1 hour | 3% |
| Background (app paused) | 1 hour | 1% |

**Expected:** Within limits above
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 12. Security Test Cases

### TC-SEC-001: Password Hashing

**Priority:** P0
**Type:** Security

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Register user with password: "testpass123" | User created |
| 2 | Check database (db.sqlite3) | Password field exists |
| 3 | Verify password format | Starts with "pbkdf2_sha256$..." |
| 4 | Check length | Hash length > 80 characters |
| 5 | Verify no plain text | "testpass123" NOT visible in DB |
| 6 | Register another user with same password | Different hash generated (unique salt) |

**Expected:** Passwords securely hashed with PBKDF2
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-SEC-002: JWT Token Security

**Priority:** P1
**Type:** Security

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login successfully | JWT token returned |
| 2 | Decode token (jwt.io) | Contains: user_id, email, role, exp (expiry) |
| 3 | Check expiry time | 24 hours from issue |
| 4 | Wait 24+ hours | Token expires |
| 5 | Try API call with expired token | 401 Unauthorized |
| 6 | Modify token payload | Signature verification fails, 401 error |

**Expected:** JWT secure, expires correctly
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-SEC-003: Role-Based Authorization

**Priority:** P0
**Type:** Security

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as Resident user | Token with role: "resident" |
| 2 | Try to access admin endpoint: GET /mdrrmo/dashboard-stats/ | 403 Forbidden |
| 3 | Verify error message | "You do not have permission" |
| 4 | Login as MDRRMO user | Token with role: "mdrrmo" |
| 5 | Access same endpoint | 200 OK, data returned |
| 6 | Verify Resident can access own endpoints | /evacuation-centers/, /hazards/ work |

**Expected:** RBAC enforced, residents cannot access admin endpoints
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-SEC-004: SQL Injection Prevention

**Priority:** P0
**Type:** Security

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Search centers with input: `'; DROP TABLE users; --` | Search executed safely |
| 2 | Verify no SQL executed | Users table still exists |
| 3 | Check results | Empty/no match (input treated as literal string) |
| 4 | Try injection in login: email=`admin' OR '1'='1` | Login fails |

**Expected:** SQL injection blocked by Django ORM
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-SEC-005: File Upload Validation

**Priority:** P1
**Type:** Security

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Try upload executable: test.exe | Error: "Invalid file type" |
| 2 | Try upload script: malicious.sh | Error: "Invalid file type" |
| 3 | Try oversized image: 15 MB | Error: "File size exceeds limit" |
| 4 | Upload valid JPEG (< 2 MB) | Success, file accepted |
| 5 | Check file storage | Stored in media/ directory |
| 6 | Verify filename sanitization | Special characters removed |

**Expected:** Only image/video files accepted within size limits
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-SEC-006: Data Privacy — Reporter Anonymization

**Priority:** P1
**Type:** Security/Privacy

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Resident A submits report | Report created |
| 2 | Login as Resident B | Different user |
| 3 | View hazard marker on map | Hazard details shown |
| 4 | Check reporter info | Reporter identity not revealed to other residents |
| 5 | Login as MDRRMO | Admin user |
| 6 | View same report | Full reporter info visible to admin |

**Expected:** Reporter identity hidden from other residents
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 13. Integration Test Cases

### TC-INT-001: OSRM API Integration

**Priority:** P0
**Type:** Integration

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | App requests route | OSRM API called |
| 2 | Verify API URL | `https://router.project-osrm.org/route/v1/driving/...` with `steps=true` |
| 3 | Check request parameters | coordinates, geometries=geojson, steps=true |
| 4 | Verify response | 200 OK, JSON with routes array |
| 5 | Parse GeoJSON | Coordinates extracted correctly |
| 6 | Display route | Polyline follows real roads |
| 7 | Check step maneuvers | All OSRM maneuver types mapped to readable instructions |

**Expected:** OSRM integration works; all maneuver types handled
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-INT-002: OpenStreetMap Tiles

**Priority:** P1
**Type:** Integration

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open map | Tiles load |
| 2 | Verify tile URL | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` |
| 3 | Zoom in | Higher zoom level tiles load |
| 4 | Pan map | New tiles load for new area |

**Expected:** OSM tiles load and display correctly
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-INT-003: GPS Location Service

**Priority:** P0
**Type:** Integration

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Grant location permission | Permission accepted |
| 2 | App requests GPS | Position obtained |
| 3 | Wait for GPS fix | Position returned |
| 4 | Verify coordinates | Valid lat/lng within Philippines |
| 5 | Check accuracy | Accuracy < 50 meters |
| 6 | Display on map | User location marker at correct position |

**Expected:** GPS integration works, location accurate
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-INT-004: Backend API Integration (Full Flow)

**Priority:** P0
**Type:** Integration

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Mobile app: Register user (without phone number) | POST /auth/register/ succeeds |
| 2 | Verify in database | User record created, phone_number blank |
| 3 | Mobile app: Login | POST /auth/login/, JWT returned |
| 4 | Mobile app: Get centers | GET /evacuation-centers/, list returned |
| 5 | Mobile app: Submit report | POST /hazards/, AI validation runs |
| 6 | Verify in database | Report saved with NB/Consensus scores |
| 7 | Admin app: Approve report | PUT /hazards/{id}/approve/ |
| 8 | Verify status updated | Status changed to "approved" |

**Expected:** Full mobile-backend integration works; phone_number optional
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-INT-005: AI Algorithms Integration Pipeline

**Priority:** P1
**Type:** Integration

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Submit hazard report | Backend receives |
| 2 | NB validation runs | Score calculated |
| 3 | Consensus check runs | Nearby reports counted, score adjusted |
| 4 | Report approved | RF triggered for road risk update |
| 5 | Road risk recalculated | predicted_risk_score updated for nearby segments |
| 6 | Route calculation requested | Modified Dijkstra uses updated risk scores |
| 7 | Verify route avoids high-risk roads | Safest route selected |

**Expected:** All 4 algorithms work together correctly
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-INT-006: Connectivity Service — Online/Offline Transition

**Priority:** P1
**Type:** Integration

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open app online | OfflineBanner not visible |
| 2 | Turn off internet | OfflineBanner slides in from top |
| 3 | Attempt to sync | App uses offline queue |
| 4 | Turn on internet | OfflineBanner slides out |
| 5 | Verify auto-sync triggered | Queued reports sent |

**Expected:** ConnectivityService accurately reflects network state in real time
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 14. Live Navigation Test Cases

### TC-NAV-001: Arrow Rotation via Device Compass Heading

**Priority:** P1
**Type:** Functional
**Precondition:** Active navigation started, device compass/heading sensor available

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start live navigation to evacuation center | Navigation screen active |
| 2 | Hold device still pointing north | User arrow points north |
| 3 | Rotate device to face east (90°) without moving | Arrow rotates to face east immediately |
| 4 | Rotate device to face south (180°) | Arrow rotates to face south; no movement required |
| 5 | Observe update frequency | Arrow responds within ≤ 500 ms of device rotation |
| 6 | Verify threshold | Rotations < 2° do not cause jitter/redraw |
| 7 | Move in a straight line | Arrow continues pointing in travel direction |
| 8 | Stop moving | Arrow holds last valid heading |

**Expected:** Arrow rotates in real time using `Position.heading` (compass); updates on ≥ 2° change; smooth rotation with no jitter
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-002: Real-Time GPS Location Updates

**Priority:** P0
**Type:** Functional
**Precondition:** Active navigation, GPS enabled

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation | Navigation screen active |
| 2 | Walk/drive for 50 meters | Movement begins |
| 3 | Observe user marker on map | Marker moves continuously with movement |
| 4 | Verify update frequency | Position updates every ≤ 2 seconds |
| 5 | Verify camera follows user | Map pans to keep user marker centered |
| 6 | Walk quickly | Marker keeps up without excessive lag |
| 7 | Stop moving | Marker stops at current position |

**Expected:** Marker moves smoothly; camera follows; no lag > 2 sec
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-003: Destination Banner Display

**Priority:** P1
**Type:** Functional
**Precondition:** Active navigation to a named evacuation center

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation to "Bulan NHS Gymnasium" | Navigation screen loads |
| 2 | Locate destination banner | Banner visible at bottom of navigation screen |
| 3 | Check banner content — Destination name | Shows: "Destination: Bulan NHS Gymnasium" |
| 4 | Check banner content — Barangay | Shows barangay name of destination center |
| 5 | Check banner content — Distance remaining | Shows current distance in km/m |
| 6 | Move closer to destination | Distance remaining decreases in real time |
| 7 | Arrive at destination | Banner shows "Arrived!" or similar |

**Expected:** Destination banner shows name, barangay, live distance remaining
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-004: Visual Turn Instructions — Correct Direction Labels

**Priority:** P1
**Type:** Functional
**Precondition:** Active navigation, approaching a turn

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation to evacuation center | Navigation screen active |
| 2 | Approach a left turn (> 100 m away) | Instruction panel shows "Turn left in [X] m" |
| 3 | Continue approaching (< 30 m) | Instruction updates to "Turn left" (imminent) |
| 4 | Verify correct direction | Label says LEFT, physical turn is LEFT |
| 5 | Approach a right turn | Instruction shows "Turn right in [X] m" |
| 6 | Verify correct direction | Label says RIGHT, physical turn is RIGHT |
| 7 | Verify no audio fires | No TTS/voice announcements at any step |

**Expected:** All turn instructions shown visually; labels are directionally correct; no audio
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-005: No Voice Audio During Navigation

**Priority:** P0
**Type:** Functional
**Precondition:** Navigation active; device volume at 100%

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation | Navigation screen active |
| 2 | Approach a turn | No audio/TTS played |
| 3 | Deviate from route | No audio/TTS played |
| 4 | Arrive at destination | No audio/TTS played |
| 5 | Listen throughout session | No voice announcements at any point |
| 6 | Check for any audio settings toggle | No voice toggle button present in UI |

**Expected:** Navigation is entirely visual; no TTS/voice audio plays under any circumstance
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-006: Navigation — Offline Continuity (No Internet)

**Priority:** P1
**Type:** Functional
**Precondition:** Device offline, navigation active with a cached route

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation with internet, then turn off internet | Device goes offline |
| 2 | Continue navigating | Navigation continues using cached route; no crash |
| 3 | Observe offline banner | "Offline" indicator appears in app bar |
| 4 | Approach a turn | Visual instruction panel still updates correctly |
| 5 | Attempt rerouting while offline | Rerouting fails gracefully with "No internet" message |
| 6 | Turn on internet | Rerouting becomes available again |

**Expected:** Navigation continues visually when offline; no crash; no voice ever fires; rerouting gracefully fails offline
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-007: Off-Route Detection and Automatic Rerouting

**Priority:** P1
**Type:** Functional
**Precondition:** Active navigation with a calculated route

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation | Route active on screen |
| 2 | Deviate from route by > 50 meters | App detects deviation |
| 3 | Check UI banner | "You are off route. Recalculating safer path..." displayed |
| 4 | Wait for reroute (internet required) | New route calculated to same destination |
| 5 | Verify new route displayed | Updated polyline from current position to destination |
| 6 | Return to original route before recalculation | Rerouting cancelled or completes and shows same route |
| 7 | Verify 5-second cooldown | Rerouting does not spam if user keeps deviating |

**Expected:** Off-route detected; new route calculated; banner shown visually; no voice audio
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-008: Back Button — Exit Navigation Confirmation

**Priority:** P1
**Type:** Functional
**Precondition:** Active navigation in progress

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation | Navigation screen active |
| 2 | Press Android hardware back button | Confirmation dialog appears |
| 3 | Verify dialog content | "Leave navigation?" with two options |
| 4 | Verify option 1 | "Continue Navigation" |
| 5 | Verify option 2 | "Exit Navigation" |
| 6 | Tap "Continue Navigation" | Dialog closes; navigation resumes normally |
| 7 | Press back button again | Dialog appears again |
| 8 | Tap "Exit Navigation" | Navigation ends; return to map screen |

**Expected:** Back button prompts confirmation; does not immediately exit
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-009: Pending Hazard Markers During Navigation

**Priority:** P1
**Type:** Functional
**Precondition:** At least 1 pending hazard report exists near the route

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation | Navigation screen active |
| 2 | Observe map markers along route | Pending reports visible as orange circle markers |
| 3 | Verify distinct style | Pending: orange background, warning_amber icon |
| 4 | Verify approved hazards ALSO visible | Red markers for approved hazards |
| 5 | Both marker types coexist | No overlap issues |
| 6 | Submit new report while navigating | New marker appears immediately |

**Expected:** Both pending and approved hazard markers visible during navigation
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-010: Approved Hazard Markers During Navigation

**Priority:** P1
**Type:** Functional
**Precondition:** At least 1 approved hazard exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation | Navigation screen active |
| 2 | Pan or zoom toward known approved hazard | Red marker visible |
| 3 | Verify marker present | Not hidden during navigation |
| 4 | Tap marker (if interactive) | Details shown or acknowledged |
| 5 | Verify route avoids the hazard area | Route polyline does not pass through high-risk segments |

**Expected:** Approved hazards remain visible and route avoids them
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-011: Navigation Arrival

**Priority:** P1
**Type:** Functional
**Precondition:** User near destination center (< 30 m)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate close to destination | Distance remaining < 30 m |
| 2 | Arrive at destination | App detects arrival |
| 3 | Check UI | "Arrived" or completion banner displayed visually |
| 4 | Verify no voice plays | No TTS audio fires on arrival |
| 5 | Navigation ends | Option to return to map or stay |

**Expected:** Arrival detected; visual UI confirms; navigation ends gracefully; no audio
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-012: Compass Heading — Real-Time Arrow Without Movement

**Priority:** P0
**Type:** Functional
**Precondition:** Navigation active; physical Android device with functioning compass sensor

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation; stand still | User arrow visible on map |
| 2 | Rotate phone 90° clockwise (north → east) while stationary | Arrow rotates to east within 500 ms |
| 3 | Rotate phone back north | Arrow returns to north |
| 4 | Rotate phone south (180°) | Arrow points south |
| 5 | Make tiny rotation (< 2°) | No visible arrow movement (jitter suppressed) |
| 6 | Rapidly spin phone | Arrow rotates smoothly, never freezes or jitters |
| 7 | Cover GPS (go indoors) | Arrow holds last valid compass heading |

**Expected:** Arrow uses `Position.heading` (compass); reacts to device orientation instantly; 2° threshold prevents jitter; works while stationary
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-013: Navigation Uses Backend Modified Dijkstra Polyline

**Priority:** P0
**Type:** Functional
**Precondition:** User has selected a route on the route-selection screen and tapped "Start Navigation"

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Complete route calculation on `RoutesSelectionScreen` | Route list displayed with risk levels from Django backend |
| 2 | Tap "Start Navigation" on a Green route | `LiveNavigationScreen` opens |
| 3 | Observe the polyline drawn on the map | Polyline matches the path coordinates returned by the Django backend route API |
| 4 | Confirm polyline does NOT change immediately upon navigation start | No new route request to OSRM on startup when `selectedRoute` is provided |
| 5 | Inspect network traffic (or logs) | No OSRM route geometry request; only optional OSRM step-instruction request |

**Expected:** Navigation polyline = Django backend polyline; no OSRM geometry request at navigation start
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-014: OSRM Used for Turn Instructions Only

**Priority:** P1
**Type:** Integration
**Precondition:** Device online; route selected from backend; navigation active

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation with a backend-calculated route | Navigation screen shows route |
| 2 | Monitor turn instruction banner | "Turn left", "Turn right", etc. are shown |
| 3 | Inspect source of turn instructions (logs/network) | Turn steps sourced from OSRM `/route/v1/driving/…?steps=true` |
| 4 | Confirm map polyline unchanged | Polyline still matches backend route, not OSRM geometry |
| 5 | Disable network after navigation start | Turn instructions gracefully degrade (bearing-analysis fallback); polyline unchanged |

**Expected:** OSRM provides steps only; backend polyline is never replaced by OSRM geometry
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NAV-015: Rerouting Calls Backend Modified Dijkstra First

**Priority:** P0
**Type:** Functional
**Precondition:** Navigation active; user intentionally moves off the route (> 50 m from nearest polyline point)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Begin live navigation on a selected route | Navigation active |
| 2 | Move > 50 m off the displayed route | "Rerouting…" indicator appears |
| 3 | Observe network requests (logs) | First request: POST to `/api/calculate-route/` (Django backend) with current GPS |
| 4 | New route appears | New polyline displayed; matches Django backend response |
| 5 | Simulate backend failure (disable API) then deviate again | OSRM fallback used; rerouting still completes (graceful degradation) |
| 6 | Restore API; deviate again | Backend used again on next reroute attempt |

**Expected:** Backend Modified Dijkstra called on every reroute; OSRM only when backend unreachable
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 15. Hazard Confirmation Test Cases

### TC-CONF-001: Resident Confirms an Existing Hazard

**Priority:** P1
**Type:** Functional
**Precondition:** Approved hazard report visible on map; resident is NOT the original reporter

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open map screen | Hazard markers visible |
| 2 | Tap an approved (red) hazard marker | Hazard detail dialog opens |
| 3 | Locate "Confirm Hazard" button | Button visible if user has not yet confirmed |
| 4 | Tap "Confirm Hazard" | Confirmation dialog or immediate action |
| 5 | Confirm action | Processing |
| 6 | Verify confirmation recorded | Confirmation count incremented (+1) |
| 7 | Re-open the same hazard | Button changes to "Already Confirmed" or hidden |

**Expected:** Confirmation recorded; count incremented; cannot confirm twice
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CONF-002: Cannot Self-Confirm Own Report

**Priority:** P1
**Type:** Functional (Negative)
**Precondition:** User has an approved hazard report on the map

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as resident who submitted a report | User logged in |
| 2 | Tap own approved hazard marker | Detail dialog opens |
| 3 | Check for "Confirm Hazard" button | Button absent or disabled |
| 4 | Verify message | "You reported this hazard" or no confirm button |

**Expected:** User cannot confirm their own hazard report
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CONF-003: Confirmation Count Badge Threshold

**Priority:** P1
**Type:** Functional
**Precondition:** A hazard report with 3 or more confirmations

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open map with a hazard that has ≥ 3 confirmations | Map visible |
| 2 | Locate hazard marker | Marker slightly larger than standard |
| 3 | Check for confirmation badge | Green circle badge with count visible |
| 4 | Verify badge number | Shows confirmation count (e.g., "3", "5") |
| 5 | Compare to hazard with < 3 confirmations | No badge on the lower-count hazard |

**Expected:** Badge visible for ≥ 3 confirmations; absent for < 3
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CONF-004: Confirmation Boosts Consensus Score

**Priority:** P1
**Type:** Functional (Algorithm Integration)
**Precondition:** An approved hazard report, admin access available

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Note current consensus score of a report (MDRRMO view) | Record score |
| 2 | Have 2 other residents confirm the hazard | 2 confirmations added |
| 3 | Admin re-opens the report | Detail screen |
| 4 | Check updated consensus score | Score increased from original |
| 5 | Verify confirmation count in Technical Details | Count matches confirmations performed |

**Expected:** Additional confirmations increase consensus score
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CONF-005: Confirmation Dialog UX

**Priority:** P2
**Type:** Functional (UI)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap an approved hazard marker | Detail dialog opens |
| 2 | Tap "Confirm Hazard" | Confirmation dialog shows |
| 3 | Verify dialog content | Clear description of what confirming means |
| 4 | Tap "Cancel" | Dialog closes, no confirmation recorded |
| 5 | Tap "Confirm Hazard" again | Dialog shows again |
| 6 | Tap "Confirm" | Confirmation recorded |

**Expected:** Confirmation dialog clear; cancel works correctly
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 16. Notification Test Cases

### TC-NOTIF-001: MDRRMO Receives Notification on New Pending Report

**Priority:** P1
**Type:** Functional
**Precondition:** MDRRMO logged in; resident account available

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as MDRRMO | Admin home screen |
| 2 | Note current notification count | Record badge number |
| 3 | Login as resident on separate device | Resident app |
| 4 | Submit a new hazard report | Report submitted with "pending" status |
| 5 | Check MDRRMO app | Notification badge count incremented |
| 6 | Tap notification bell icon | Notification list opens |
| 7 | Verify new notification | Entry for the new pending report visible |
| 8 | Check notification content | Hazard type, location, time |

**Expected:** MDRRMO notified of new pending report in real time
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NOTIF-002: Notification Badge Count

**Priority:** P1
**Type:** Functional
**Precondition:** MDRRMO logged in

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open admin app | Dashboard visible |
| 2 | Check notification bell icon | Badge shows unread count (or no badge if zero) |
| 3 | Submit 3 reports as resident | 3 new pending reports |
| 4 | Check notification bell | Badge increments to reflect unread count |
| 5 | Tap notification bell | Notification list opens |
| 6 | Mark all as read (or navigate through) | Badge clears to 0 |

**Expected:** Badge reflects unread notification count; clears when read
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NOTIF-003: Notification — View Report on Map

**Priority:** P1
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open notification list | Notifications displayed |
| 2 | Tap a notification for a hazard report | Options displayed |
| 3 | Tap "View on Map" | Navigate to Map Monitor tab |
| 4 | Verify map centered on report | Map pans/zooms to report location |
| 5 | Verify report marker highlighted | Pulsing animation on the target marker |

**Expected:** Tapping notification centers map on the reported hazard
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NOTIF-004: Resident Notification on Report Status Change

**Priority:** P1
**Type:** Functional
**Precondition:** Resident has a pending report; MDRRMO approves it

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Resident submits hazard report | Status: Pending |
| 2 | MDRRMO approves the report | Status: Approved |
| 3 | Check resident app | Notification received: "Your report has been approved" |
| 4 | Tap notification bell | Notification visible in list |
| 5 | Tap notification | Map highlights the approved hazard |

**Expected:** Resident notified when their report is approved or rejected
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NOTIF-005: Notifications Persist on App Restart

**Priority:** P2
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Receive 3 unread notifications | Badge shows 3 |
| 2 | Close app completely | App not running |
| 3 | Reopen app | App launches |
| 4 | Check notification badge | Still shows 3 unread |
| 5 | Open notification list | All 3 notifications present |

**Expected:** Unread notifications persist across app restarts
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-NOTIF-006: Deleted Report — Graceful Notification Handling

**Priority:** P0
**Type:** Functional
**Precondition:** Resident has a push notification for an "approved" report that MDRRMO subsequently soft-deleted

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | MDRRMO soft-deletes an approved hazard report | Report marked `is_deleted = True` |
| 2 | Resident opens notification for that report | App attempts to fetch report details |
| 3 | Backend returns 404 (report not found / deleted) | App receives null/empty result |
| 4 | Observe app behavior | "Report Unavailable" dialog appears |
| 5 | Read dialog title | "Report Unavailable" |
| 6 | Read dialog body | "This hazard report is no longer available. It may have been removed by MDRRMO." |
| 7 | Tap "OK" | Dialog dismissed; no navigation occurs |
| 8 | Verify no crash | App remains on notifications screen |

**Expected:** Graceful dialog shown; no crash; no broken navigation to deleted report
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 17. Media Handling Test Cases

### TC-MEDIA-001: View Attached Image in MDRRMO Report Detail

**Priority:** P1
**Type:** Functional
**Precondition:** MDRRMO logged in; a hazard report with attached image exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Reports tab | Reports list |
| 2 | Open a report with attached image | Report detail screen |
| 3 | Scroll to media section | Image thumbnail visible |
| 4 | Verify image loads | Image renders (not broken icon) |
| 5 | Verify image URL | Absolute URL with server host and media path |

**Expected:** Attached image renders correctly in report detail
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-MEDIA-002: Click Image to Enlarge (MDRRMO Report Detail)

**Priority:** P1
**Type:** Functional
**Precondition:** Report with attached image open in detail view

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Observe image thumbnail in media section | Thumbnail visible with "Tap to enlarge" overlay |
| 2 | Tap the image | Fullscreen viewer opens |
| 3 | Verify fullscreen mode | Image fills screen, dark background |
| 4 | Pinch to zoom in | Image zooms in smoothly (InteractiveViewer) |
| 5 | Pinch to zoom out | Image returns to fit view |
| 6 | Pan zoomed image | Image pans in zoomed state |
| 7 | Tap outside image or back button | Fullscreen viewer closes |
| 8 | Return to report detail | Detail screen intact |

**Expected:** Tap-to-enlarge opens zoomable fullscreen viewer; close works
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-MEDIA-003: Click Image to Enlarge (Resident Map View)

**Priority:** P2
**Type:** Functional
**Precondition:** Resident viewing hazard detail with attached image

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap hazard marker on map | Hazard detail dialog |
| 2 | Scroll to media/attachments section | Thumbnail visible |
| 3 | Tap the image | Fullscreen viewer opens |
| 4 | Verify zoom/pan functionality | Interactive zoom works |
| 5 | Close viewer | Returns to hazard detail |

**Expected:** Resident can enlarge hazard images from map view
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-MEDIA-004: Broken Image Handling

**Priority:** P2
**Type:** Functional (Negative)
**Precondition:** Report exists with a missing or inaccessible media file

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open a report whose image file is deleted from server | Report detail loads |
| 2 | Scroll to media section | Image area visible |
| 3 | Verify no crash | App does not crash |
| 4 | Check fallback UI | Broken image icon or placeholder shown |
| 5 | "Tap to enlarge" overlay | Absent or gracefully handles no image |

**Expected:** Broken images show placeholder; no crash
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-MEDIA-005: Video Attachment (If Enabled)

**Priority:** P2
**Type:** Functional
**Precondition:** `HazardMediaConfig.videoUploadEnabled = true`; camera permission granted

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Report Hazard screen | Form displayed |
| 2 | Check constraints hint | "JPG/PNG max 2 MB · MP4 max 10 MB / 10 s" shown |
| 3 | Tap "Add Video" (if present) | Video picker opens |
| 4 | Select a valid MP4 (< 10 MB, < 10 sec) | Video selected, preview shown |
| 5 | Submit report | Upload starts |
| 6 | Verify success | Report submitted with video |
| 7 | MDRRMO views report | Video icon/thumbnail shown in detail |

**Expected:** Video upload works within constraints; preview shown in MDRRMO detail
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-MEDIA-006: Media Upload Constraints Hint — No Overflow

**Priority:** P1
**Type:** Functional (UI)
**Precondition:** Test on both large and small screens

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Report Hazard screen | Form displayed |
| 2 | Scroll to "Attach Media (Optional)" row | Row visible |
| 3 | Test on 5.4" screen (small) | Both title and hint visible; hint wraps, no overflow stripe |
| 4 | Test on 6.7" screen (large) | Hint displayed on one line, no wrap needed |
| 5 | Confirm no yellow/black debug border | No RenderFlex overflow |

**Expected:** Constraints hint wraps gracefully using Flexible on small screens
**Actual:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 18. User Acceptance Test Cases

### TC-UAT-001: End-to-End Evacuation Scenario

**Priority:** P0
**Type:** UAT
**Tester:** Resident user (real person)

**Scenario:** Resident needs to evacuate during flooding

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open app during emergency | App launches quickly |
| 2 | View current location | User sees their position on map |
| 3 | See nearby hazards | Red markers for reported floods |
| 4 | Find nearest safe evacuation center | Bottom panel shows centers, collapsible |
| 5 | Tap panel handle to collapse/expand | Panel animates smoothly |
| 6 | Select closest center — tap "View Routes" | Route calculated |
| 7 | Select safest route — tap "Start Navigation" | Navigation starts |
| 8 | Verify destination banner | Name, barangay, distance remaining shown |
| 9 | Follow turn-by-turn voice guidance | Correct voice directions |
| 10 | Arrive at evacuation center | Arrival announced; navigation ends |

**Acceptance Criteria:**
- ✓ User can complete evacuation without assistance
- ✓ Route avoids known hazards
- ✓ Voice directions are correct (never wrong left/right)
- ✓ Destination banner always visible
- ✓ Collapsible panel does not obstruct map

**Actual User Feedback:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-UAT-002: Hazard Reporting by Resident

**Priority:** P1
**Type:** UAT
**Tester:** Resident user

**Scenario:** Resident encounters flooding and reports it

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | See flooding on street | Physical observation |
| 2 | Open app | App ready |
| 3 | Tap "Report Hazard" button | Form opens |
| 4 | Select hazard type: "Flooded Road" | Tile highlighted |
| 5 | Describe: "Water 2 feet deep, impassable" | Description entered (≥10 chars) |
| 6 | Observe media section — no overflow on any screen size | Layout correct |
| 7 | Take photo of flooding | Photo captured and preview shown |
| 8 | Submit report | Success message |
| 9 | Verify pending marker on map | Yellow marker appears |
| 10 | If navigating: marker visible on navigation map too | Pending marker visible during navigation |

**Acceptance Criteria:**
- ✓ Reporting process < 2 minutes
- ✓ No layout bugs or overflow during media attachment
- ✓ Photo upload works
- ✓ Pending marker visible immediately after submission

**Actual User Feedback:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-UAT-003: MDRRMO Report Management

**Priority:** P0
**Type:** UAT
**Tester:** MDRRMO personnel

**Scenario:** MDRRMO reviews incoming hazard reports

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as MDRRMO admin | Admin interface displayed |
| 2 | Navigate to Dashboard | See summary statistics including real High Risk Roads count |
| 3 | Check pending reports count | Number of reports awaiting review |
| 4 | Go to Reports tab | List with status filter only (no barangay filter) |
| 5 | Filter by "Pending" | Only pending reports shown |
| 6 | Select a report to review | Detail view opens |
| 7 | Review AI scores (NB, Consensus) — clean UI | Human-readable labels; no debug threshold text |
| 8 | Tap image thumbnail | Fullscreen viewer opens; zoom works |
| 9 | Approve the report | Tap Approve → confirm |
| 10 | Restore a rejected report | Tap Restore → simple confirm (no reason required) |
| 11 | Delete an old evacuation center | Tap trash icon → confirm → deleted |

**Acceptance Criteria:**
- ✓ MDRRMO can review 10 reports in < 15 minutes
- ✓ AI scores human-readable; no debug text
- ✓ Media click-to-enlarge works
- ✓ Restore requires no reason entry
- ✓ Delete center works with confirmation

**Actual User Feedback:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-UAT-004: Evacuation Center Management

**Priority:** P1
**Type:** UAT
**Tester:** MDRRMO personnel

**Scenario:** MDRRMO adds and deletes evacuation centers

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as MDRRMO | Admin interface |
| 2 | Navigate to Centers tab | List of existing centers (no barangay filter) |
| 3 | Tap "Add Center" button | Form opens |
| 4 | Fill in center details | All fields clear and labeled |
| 5 | Save new center | Success confirmation |
| 6 | Verify center appears in list | New center visible |
| 7 | Check resident app | New center available to residents |
| 8 | Delete a test center | Tap trash → confirm → removed |

**Acceptance Criteria:**
- ✓ Adding center takes < 3 minutes
- ✓ Deletion takes < 30 seconds with confirmation
- ✓ Changes reflect immediately for residents

**Actual User Feedback:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-UAT-005: Live Navigation Full Test

**Priority:** P0
**Type:** UAT
**Tester:** Resident walking/driving to evacuation center

**Scenario:** Real-world navigation test

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start navigation to nearest center | Navigation screen |
| 2 | Walk for 2 minutes | GPS and map update smoothly |
| 3 | Verify map rotates with direction | Map heading matches travel direction |
| 4 | Approach a turn | Voice says correct direction ("Turn left" not "Turn right") |
| 5 | Press back button | Exit confirmation dialog shown |
| 6 | Tap "Continue Navigation" | Navigation resumes |
| 7 | Deliberately take wrong road | "You are off route. Recalculating safer path..." banner |
| 8 | Wait for reroute | New route calculated |
| 9 | Continue to destination | Arrival announced |

**Acceptance Criteria:**
- ✓ Map rotates correctly
- ✓ GPS updates in real time
- ✓ Voice directions always correct
- ✓ Rerouting works when off route
- ✓ Back button protected with confirmation

**Actual User Feedback:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-UAT-006: Offline Usage During Emergency

**Priority:** P1
**Type:** UAT
**Tester:** Resident user

**Scenario:** Limited connectivity, user needs route

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Previous day: Use app online | Data cached |
| 2 | Emergency day: No internet | Device offline |
| 3 | Open app | App launches; OfflineBanner visible |
| 4 | Check evacuation centers | Centers visible from cache |
| 5 | Request route to nearest center | Route loads if previously cached |
| 6 | If not cached: See clear error message | "Connect to internet" guidance |
| 7 | Report hazard offline | Report queued |
| 8 | Later: Internet restored | Reports auto-sync; OfflineBanner disappears |

**Acceptance Criteria:**
- ✓ App usable offline with cached data
- ✓ OfflineBanner clearly communicates offline state
- ✓ Auto-sync works when back online

**Actual User Feedback:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-UAT-007: Overall User Satisfaction

**Priority:** P1
**Type:** UAT
**Tester:** Multiple users (5 residents, 2 MDRRMO)

**Survey Questions:**

| Question | Scale (1–5) | Average Score |
|----------|-------------|---------------|
| How easy was it to learn the app? | 1=Very Difficult, 5=Very Easy | _____ |
| How confident are you in the route safety? | 1=Not Confident, 5=Very Confident | _____ |
| How useful is the hazard reporting feature? | 1=Not Useful, 5=Very Useful | _____ |
| How clear were the visual navigation instructions? | 1=Very Confusing, 5=Very Clear | _____ |
| How satisfied are you with the MDRRMO admin tools? | 1=Very Dissatisfied, 5=Very Satisfied | _____ |
| Would you recommend this app to others? | 1=Never, 5=Definitely | _____ |
| Overall satisfaction with the app | 1=Very Dissatisfied, 5=Very Satisfied | _____ |

**Acceptance Criteria:**
- ✓ Average score >= 4.0 for all questions
- ✓ No critical usability issues reported
- ✓ 80%+ users would recommend

**Actual Results:** _____
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 19. Test Metrics and Reporting

### 19.1 Test Coverage

| Component | Total Test Cases | Executed | Passed | Failed | Blocked | Coverage % |
|-----------|------------------|----------|--------|--------|---------|------------|
| Authentication | 7 | | | | | |
| Evacuation Centers | 6 | | | | | |
| Routing | 7 | | | | | |
| Hazard Reporting | 7 | | | | | |
| Admin Dashboard | 17 | | | | | |
| AI Algorithms | 6 | | | | | |
| Offline Mode | 5 | | | | | |
| Performance | 7 | | | | | |
| Security | 6 | | | | | |
| Integration | 6 | | | | | |
| Live Navigation | 12 | | | | | |
| Hazard Confirmation | 5 | | | | | |
| Notifications | 6 | | | | | |
| Media Handling | 6 | | | | | |
| UAT | 7 | | | | | |
| **TOTAL** | **124** | | | | | |

### 19.2 Defect Summary

| Severity | Count | Description |
|----------|-------|-------------|
| Critical (P0) | | Blocks core functionality |
| High (P1) | | Major feature broken |
| Medium (P2) | | Minor feature issue |
| Low (P3) | | Cosmetic/enhancement |

### 19.3 QA Patch Coverage

The following items were addressed in QA Patches (v2.0 + v3.0) and must be regression tested:

| Patch Item | Version | Test Case(s) |
|------------|---------|--------------|
| Map rotation during navigation | v2.0 | TC-NAV-001 |
| Real-time GPS updates | v2.0 | TC-NAV-002 |
| Destination banner | v2.0 | TC-NAV-003 |
| Voice navigation left/right fix | v2.0 | *Superseded — voice removed in v3.0* |
| Off-route rerouting | v2.0 | TC-NAV-007 |
| Back button confirmation | v2.0 | TC-NAV-008 |
| Pending hazards during navigation | v2.0 | TC-NAV-009 |
| Approved hazards during navigation | v2.0 | TC-NAV-010 |
| Phone number removed from registration | v2.0 | TC-AUTH-001 |
| Collapsible evacuation center panel | v2.0 | TC-CENTER-005 |
| High Risk Roads real-time tile | v2.0 | TC-ADMIN-002 |
| Delete evacuation center | v2.0 | TC-ADMIN-011 |
| Restore report (no reason required) | v2.0 | TC-ADMIN-007 |
| Technical details UI (no debug text) | v2.0 | TC-ADMIN-008 |
| Map Monitor — Risk Overlay removed | v2.0 | TC-ADMIN-009 |
| Sync Baseline Data removed | v2.0 | TC-ADMIN-014 |
| Barangay filter removed (Reports, Centers, Users) | v2.0 | TC-ADMIN-003, TC-ADMIN-010, TC-ADMIN-013 |
| Media click-to-enlarge | v2.0 | TC-MEDIA-001, TC-MEDIA-002 |
| Media header overflow fix | v2.0 | TC-HAZARD-005, TC-MEDIA-006 |
| **Voice navigation removed (visual-only)** | **v3.0** | **TC-NAV-004, TC-NAV-005, TC-NAV-011** |
| **Compass heading arrow rotation** | **v3.0** | **TC-NAV-012** |
| **Navigation offline continuity (no voice)** | **v3.0** | **TC-NAV-006** |
| **Soft delete report — data integrity** | **v3.0** | **TC-ADMIN-017** |
| **Deleted report — graceful notification** | **v3.0** | **TC-NOTIF-006** |
| **Asia/Manila timezone (date display)** | **v3.0** | **TC-ADMIN-003** |
| **Phone number hidden from resident profile** | **v3.0** | **TC-AUTH-001** |
| **Live navigation uses backend polyline (not OSRM)** | **v4.0** | **TC-NAV-013** |
| **OSRM restricted to turn instructions only** | **v4.0** | **TC-NAV-014** |
| **Rerouting calls backend Modified Dijkstra first** | **v4.0** | **TC-NAV-015** |
| **Graduated hazard impact — perpendicular distance** | **v4.0** | **TC-AI-007** |
| **Flood gradual decay — wide influence band** | **v4.0** | **TC-AI-008** |
| **road_blocked within 25 m → segment impassable** | **v4.0** | **TC-AI-009** |

### 19.4 Test Environment Summary

- **Devices Tested:** _____
- **OS Versions:** _____
- **Network Conditions:** WiFi, 4G, 3G, Offline
- **Test Duration:** From _____ to _____
- **Testers:** _____

### 19.5 Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Test Lead | | | |
| Project Manager | | | |
| MDRRMO Representative | | | |
| Thesis Advisor | | | |

---

**END OF TEST CASE DOCUMENT**

---

**Document Control:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-02-05 | Team | Initial draft |
| 0.5 | 2026-02-07 | Team | Added UAT cases |
| 1.0 | 2026-02-08 | Team | First final version |
| 2.0 | 2026-04-13 | Team | Added Sections 14–17 (Navigation, Confirmation, Notifications, Media); updated Auth, Centers, Admin, Integration, Performance; removed phone number and Risk Overlay references; updated metrics from 71 to 117 test cases |
| 3.0 | 2026-04-17 | Team | QA Patch 2: replaced voice TCs (TC-NAV-004/005/006) with visual-only TCs; added TC-NAV-012 (compass heading); added TC-NOTIF-006 (deleted report graceful dialog); added TC-ADMIN-017 (soft delete integrity); updated UAT survey; expanded QA Patch Coverage table; 117 → 118 test cases |
| 4.0 | 2026-04-18 | Team | Routing consistency + graduated hazard influence: TC-NAV-013/014/015 (backend polyline, OSRM turn-instructions only, backend rerouting); TC-AI-007/008/009 (graduated impact, flood decay, road_blocked 25 m); updated QA Patch Coverage table; 118 → 124 test cases |

**Total Test Cases:** 124
**Total Sections:** 19
