# Test Case Document
## AI-Powered Mobile Evacuation Routing Application

**Version:** 1.0  
**Date:** February 8, 2026  
**Project:** Thesis - Evacuation Routing System  
**Test Lead:** [Name]  

---

## Document Information

| Document ID | TEST-EVAC-001 |
|-------------|---------------|
| Version | 1.0 |
| Status | Final |
| Last Updated | February 8, 2026 |
| Classification | Internal |

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
14. [User Acceptance Test Cases](#14-user-acceptance-test-cases)

---

## 1. Introduction

### 1.1 Purpose

This document provides comprehensive test cases for the AI-Powered Mobile Evacuation Routing Application. It covers functional, non-functional, integration, and user acceptance testing.

### 1.2 Scope

**In Scope:**
- Mobile app functionality (Android)
- Backend API endpoints
- AI/ML algorithms
- Offline capabilities
- Admin dashboard
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

---

## 2. Test Strategy

### 2.1 Test Levels

1. **Unit Testing** - Individual components/functions
2. **Integration Testing** - Component interactions
3. **System Testing** - Complete system functionality
4. **User Acceptance Testing** - End-user validation

### 2.2 Test Types

- **Functional Testing** - Feature correctness
- **Non-Functional Testing** - Performance, usability
- **Security Testing** - Authentication, authorization, data protection
- **Regression Testing** - Ensure existing features still work
- **Smoke Testing** - Basic functionality check
- **Compatibility Testing** - Different Android versions

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
| Samsung Galaxy A52 | Android 12 | 6.5" (1080x2400) | 6 GB | Mid-range |
| Google Pixel 4a | Android 13 | 5.81" (1080x2340) | 6 GB | Stock Android |
| Android Emulator | Android 11 | 5.4" (1080x1920) | 2 GB | Min spec |
| Android Emulator | Android 13 | 6.7" (1440x3200) | 8 GB | High-end |
| Xiaomi Redmi 9 | Android 10 | 6.53" (1080x2340) | 4 GB | Budget device |

**Network Configurations:**
- WiFi (high speed: 10+ Mbps)
- 4G LTE (medium speed: 1-5 Mbps)
- 3G (low speed: 256 Kbps - 1 Mbps)
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
| resident2 | resident2@test.com | password123 | Resident | Multi-user testing |
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
| 3 | Enter valid full name: "Juan Dela Cruz" | Field accepts input |
| 4 | Enter valid email: "juan.test@email.com" | Field accepts input |
| 5 | Enter valid phone: "09171234567" | Field accepts input |
| 6 | Enter password: "password123" | Password masked, field accepts |
| 7 | Enter confirm password: "password123" | Password masked, field accepts |
| 8 | Tap "Register" button | Loading indicator appears |
| 9 | Wait for response | Success message: "Registration successful" |
| 10 | Check navigation | Navigate to map screen (auto-login) |
| 11 | Verify user logged in | User name displays in profile |

**Expected:** Registration successful, user auto-logged in  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked  
**Notes:** _____

---

### TC-AUTH-002: User Registration - Duplicate Email

**Priority:** P1  
**Type:** Functional (Negative)  
**Precondition:** User with email "resident@test.com" already exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open registration screen | Registration form displayed |
| 2 | Enter full name: "Test User" | Field accepts input |
| 3 | Enter email: "resident@test.com" (existing) | Field accepts input |
| 4 | Enter phone: "09171234567" | Field accepts input |
| 5 | Enter password: "password123" | Field accepts input |
| 6 | Enter confirm password: "password123" | Field accepts input |
| 7 | Tap "Register" button | Loading indicator appears |
| 8 | Wait for response | Error message: "Email already exists" |
| 9 | Verify still on registration screen | Form still visible, fields retain values |

**Expected:** Error message, registration blocked  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked  
**Notes:** _____

---

### TC-AUTH-003: User Registration - Weak Password

**Priority:** P2  
**Type:** Functional (Negative)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open registration screen | Registration form displayed |
| 2 | Enter all required fields | Fields accept input |
| 3 | Enter password: "1234" (too short) | Field accepts input |
| 4 | Enter confirm password: "1234" | Field accepts input |
| 5 | Tap "Register" button | Error: "Password must be at least 8 characters" |
| 6 | Verify not registered | Registration blocked |

**Expected:** Validation error, registration blocked  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AUTH-004: User Login - Valid Credentials

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

### TC-AUTH-005: User Login - Invalid Password

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

### TC-AUTH-007: Admin Login - Role-Based Routing

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
| 7 | Verify UI | Bottom navigation with 6 tabs visible |
| 8 | Check tabs | Dashboard, Reports, Map Monitor, Centers, Analytics, Settings |

**Expected:** Admin logged in, admin interface displayed  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 5. Evacuation Centers Test Cases

### TC-CENTER-001: View Evacuation Centers List

**Priority:** P0  
**Type:** Functional  
**Precondition:** User logged in, at least 3 centers exist

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From map screen, tap bottom sheet | Expand to show centers list |
| 2 | Verify list displayed | All centers visible (min 3) |
| 3 | Check center card content | Shows: name, distance, address |
| 4 | Verify distance calculation | Distance calculated from user location |
| 5 | Check sorting | Sorted by distance (nearest first) |
| 6 | Scroll list | List scrollable if > 3 centers |

**Expected:** All centers displayed correctly, sorted by distance  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CENTER-002: View Center Details

**Priority:** P1  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From centers list, tap a center card | Navigate to center details |
| 2 | Verify information displayed | Name, barangay, address shown |
| 3 | Check contact number | Phone number displayed, formatted |
| 4 | Check GPS coordinates | Latitude/longitude displayed |
| 5 | Verify "Get Directions" button | Button visible, enabled |
| 6 | Tap "View on Map" | Map centered on center location |

**Expected:** All center details displayed accurately  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CENTER-003: Search Evacuation Centers

**Priority:** P2  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On centers list, locate search bar | Search input visible at top |
| 2 | Tap search bar | Keyboard appears, cursor in field |
| 3 | Type: "Gymnasium" | Search updates in real-time |
| 4 | Verify results | Only centers matching "Gymnasium" shown |
| 5 | Clear search (X button) | All centers displayed again |
| 6 | Search: "NonExistent" | "No results found" message |

**Expected:** Search filters centers correctly  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CENTER-004: Centers on Map

**Priority:** P1  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to map screen | Map displayed with user location |
| 2 | Verify center markers | Blue markers for each center |
| 3 | Count markers | Matches number of centers (e.g., 5) |
| 4 | Tap a center marker | Popup shows center name |
| 5 | Tap popup | Navigate to center details |
| 6 | Zoom in/out | Markers scale appropriately |

**Expected:** All centers displayed as blue markers  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-CENTER-005: Offline Centers Access

**Priority:** P1  
**Type:** Functional (Offline)  
**Precondition:** Centers cached (accessed once online)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Turn off WiFi and mobile data | Device offline |
| 2 | Open app (if closed) or stay in app | App functions |
| 3 | Navigate to centers list | List displays |
| 4 | Verify centers displayed | All cached centers visible |
| 5 | Check distances | Calculated from current GPS |
| 6 | Open center details | Details displayed from cache |
| 7 | Verify "Offline" indicator | Badge/icon showing offline mode |

**Expected:** Centers accessible offline from cache  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 6. Routing Test Cases

### TC-ROUTE-001: Calculate Route - Online (OSRM)

**Priority:** P0  
**Type:** Functional  
**Precondition:** User logged in, internet available, GPS active

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From map screen, select evacuation center | Center details displayed |
| 2 | Tap "Get Directions" button | Loading indicator: "Calculating routes..." |
| 3 | Wait for route calculation (max 5 sec) | Navigate to Routes Selection screen |
| 4 | Verify routes displayed | 3 routes shown (or less if alternatives unavailable) |
| 5 | Check route 1 (safest) | Green indicator, lowest risk %, marked "Recommended" |
| 6 | Verify route details | Shows: distance (km), risk (%), risk level (Green/Yellow/Red) |
| 7 | Check map display | Route polyline displayed, color-coded |
| 8 | Verify console logs | "✅ OSRM routing successful" in logs |

**Expected:** Routes calculated via OSRM, displayed correctly  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-002: Route Display - Risk Color Coding

**Priority:** P1  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Calculate routes to a center | Routes displayed |
| 2 | Identify safest route | Green card background, green polyline |
| 3 | Check risk percentage | Green route: < 30% risk |
| 4 | If yellow route exists | Yellow card, 30-70% risk |
| 5 | If red route exists | Red card, > 70% risk |
| 6 | Verify risk bar | Horizontal bar filled to risk % |
| 7 | Check icons | Green: ✓ check, Yellow: ⚠ warning, Red: ⚠ error |

**Expected:** Routes color-coded by risk level correctly  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-003: Start Navigation

**Priority:** P1  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On routes selection, tap safest route | Route card expands |
| 2 | Tap "Start Navigation" button | Navigate to Navigation screen |
| 3 | Verify map display | Map with route polyline, user location dot |
| 4 | Check top bar | Destination name, distance remaining, ETA |
| 5 | Verify user dot | Blue dot at user's current location |
| 6 | Check route line | Colored polyline from user to destination |
| 7 | Tap "Cancel Navigation" | Return to map screen |

**Expected:** Navigation screen displays, route visible  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-004: Route Caching

**Priority:** P1  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Calculate route online (first time) | Route calculated via OSRM |
| 2 | Verify console log | "Routes cached successfully" |
| 3 | Return to map | Back button |
| 4 | Turn off internet | Device offline |
| 5 | Request same route again | Loading indicator |
| 6 | Wait for response | Route displays from cache |
| 7 | Verify console log | "✅ Using cached routes (offline mode)" |
| 8 | Check route accuracy | Same route as before |

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
| 3 | Tap "Get Directions" | Loading indicator |
| 4 | Wait for response (10-15 sec) | Error message displayed |
| 5 | Verify error text | "Unable to calculate routes. Please check your internet connection and try again." |
| 6 | Check console log | "❌ OSRM failed" and "❌ No cached routes available" |
| 7 | Verify no routes shown | Empty state or error screen |

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
| 3 | Verify console log | "⚠️ Location outside Philippines (37.42, -122.08), using Bulan default" |
| 4 | Request route to center | Route calculation starts |
| 5 | Verify OSRM coordinates | Uses Bulan coordinates (12.6699, 123.8758) |
| 6 | Check route validity | Route follows roads in Bulan, not USA |

**Expected:** App detects invalid location, uses Bulan default  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ROUTE-007: Multiple Routes Comparison

**Priority:** P2  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Calculate routes to center | 3 routes displayed |
| 2 | Compare distances | Routes may have different distances |
| 3 | Compare risks | Routes have different risk percentages |
| 4 | Verify safest route | Lowest risk, marked "Recommended" |
| 5 | Check distance vs risk tradeoff | Safest route may be longer |
| 6 | Tap each route | Can view details for each |

**Expected:** Multiple distinct routes with varying risk/distance  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 7. Hazard Reporting Test Cases

### TC-HAZARD-001: Submit Hazard Report - Complete

**Priority:** P0  
**Type:** Functional  
**Precondition:** User logged in, online, location permission granted

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From map, tap "Report Hazard" FAB | Navigate to Report Hazard screen |
| 2 | Tap hazard type dropdown | List of 9 hazard types shown |
| 3 | Select: "Flooded Road" | Type selected, icon displayed |
| 4 | Enter description: "Main highway near market severely flooded, water level rising" | Text area accepts input (>10 chars) |
| 5 | Verify location | Current GPS location displayed |
| 6 | Optional: Tap "Add Photo" | Camera/gallery picker opens |
| 7 | Select photo | Photo preview displayed |
| 8 | Tap "Submit Report" button | Loading indicator |
| 9 | Wait for response | Success: "Report submitted successfully" |
| 10 | Check navigation | Return to map screen |

**Expected:** Report submitted successfully  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-002: Submit Report - Missing Required Fields

**Priority:** P1  
**Type:** Functional (Negative)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Report Hazard screen | Form displayed |
| 2 | Leave hazard type unselected | Dropdown empty |
| 3 | Enter description: "Test" (< 10 chars) | Text accepted |
| 4 | Tap "Submit Report" | Validation errors displayed |
| 5 | Verify error messages | "Please select hazard type" and "Description must be at least 10 characters" |
| 6 | Report not submitted | Still on form screen |

**Expected:** Validation errors, submission blocked  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-003: Submit Report - Offline Queue

**Priority:** P1  
**Type:** Functional (Offline)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Turn off internet | Device offline |
| 2 | Open Report Hazard screen | Form displayed |
| 3 | Fill all required fields | Hazard type, description |
| 4 | Tap "Submit Report" | Processing |
| 5 | Check response | Success: "Report queued for submission when online" |
| 6 | Verify report saved locally | In Hive queue |
| 7 | Turn on internet | Device online |
| 8 | Wait or trigger sync | Auto-sync starts |
| 9 | Check console log | "Sync complete!" |
| 10 | Verify report submitted | Removed from queue |

**Expected:** Report queued offline, auto-synced when online  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-004: Report with Media Upload

**Priority:** P2  
**Type:** Functional  
**Precondition:** Camera permission granted

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Report Hazard screen | Form displayed |
| 2 | Fill hazard type and description | Required fields complete |
| 3 | Tap "Add Photo" button | Image picker opens |
| 4 | Select photo from gallery | Photo selected |
| 5 | Verify photo preview | Thumbnail displayed |
| 6 | Check file size | If > 10 MB, error shown |
| 7 | Tap "Submit Report" | Upload starts |
| 8 | Wait for upload | Progress indicator (if large file) |
| 9 | Verify success | Report submitted with photo |

**Expected:** Photo uploaded successfully with report  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-HAZARD-005: Hazard Type Selection

**Priority:** P2  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Report Hazard screen | Form displayed |
| 2 | Tap hazard type dropdown | 9 types listed with icons |
| 3 | Verify types | Flooded Road, Landslide, Fallen Tree, Road Damage, Fallen Electric Post, Road Blocked, Bridge Damage, Storm Surge, Other |
| 4 | Check icons | Each type has unique icon |
| 5 | Select "Landslide" | Type selected, displayed in field |
| 6 | Re-open dropdown | Can change selection |
| 7 | Select "Other" | Type changed |

**Expected:** All 9 hazard types selectable  
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
| 3 | Check summary cards | 5 cards displayed (2x3 grid) |
| 4 | Verify card 1 | Total Reports: shows count |
| 5 | Verify card 2 | Pending Reports: shows count |
| 6 | Verify card 3 | Verified Hazards: shows count |
| 7 | Verify card 4 | High Risk Roads: shows count |
| 8 | Verify card 5 | Evacuation Centers: shows count |
| 9 | Check card design | Icon, label, count, colored border |

**Expected:** All statistics displayed correctly  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-002: View Reports List

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

**Expected:** All reports listed with complete information  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-003: Filter Reports by Status

**Priority:** P1  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On Reports tab, locate filter dropdown | "All" selected by default |
| 2 | Tap filter dropdown | Options: All, Pending, Approved, Rejected |
| 3 | Select "Pending" | Dropdown closes |
| 4 | Verify list updates | Only pending reports shown |
| 5 | Check status badges | All show "Pending" |
| 6 | Select "Approved" filter | Only approved reports shown |
| 7 | Select "All" | All reports shown again |

**Expected:** Filter works correctly for each status  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-004: Approve Hazard Report

**Priority:** P0  
**Type:** Functional  
**Precondition:** At least 1 pending report exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | On Reports tab, find pending report | Report with "Pending" badge |
| 2 | Tap "View Details" | Report detail screen |
| 3 | Scroll to AI Analysis section | NB, Consensus, RF scores displayed |
| 4 | Check recommendation | "Recommendation: Approve" or similar |
| 5 | Scroll to Decision Controls | Approve and Reject buttons visible |
| 6 | Optional: Add admin comment | Comment field accepts text |
| 7 | Tap "Approve" button | Confirmation dialog |
| 8 | Confirm action | Processing indicator |
| 9 | Wait for response | Success: "Report approved" |
| 10 | Check status update | Badge changes to "Approved" (Green) |
| 11 | Verify road risk update triggered | Console log (future: risk recalculation) |

**Expected:** Report approved, status updated  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-005: Reject Hazard Report

**Priority:** P1  
**Type:** Functional  
**Precondition:** At least 1 pending report exists

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open pending report details | Report detail screen |
| 2 | Scroll to Decision Controls | Reject button visible |
| 3 | Tap "Reject" button | Comment field becomes required |
| 4 | Try to submit without comment | Error: "Comment required for rejection" |
| 5 | Enter rejection reason: "Duplicate report" | Comment accepted |
| 6 | Tap "Reject" button again | Confirmation dialog |
| 7 | Confirm action | Processing |
| 8 | Wait for response | Success: "Report rejected" |
| 9 | Check status update | Badge changes to "Rejected" (Red) |
| 10 | Verify comment saved | Visible in report detail |

**Expected:** Report rejected with comment, status updated  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-006: Map Monitor - Layer Toggles

**Priority:** P1  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | From admin home, tap Map Monitor tab | Full-screen map displayed |
| 2 | Verify default layers | All layers visible by default |
| 3 | Tap "Layers" icon (top-right) | Bottom sheet with toggles opens |
| 4 | Check toggle options | Evacuation Centers, Verified Hazards, Pending Hazards, Risk Overlay |
| 5 | Toggle OFF "Evacuation Centers" | Blue markers disappear |
| 6 | Close bottom sheet | Returns to map |
| 7 | Toggle ON "Evacuation Centers" | Blue markers reappear |
| 8 | Toggle OFF "Pending Hazards" | Orange markers disappear |
| 9 | Verify state persists | Toggles remember state when reopened |

**Expected:** Layer toggles work correctly  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-007: Add Evacuation Center

**Priority:** P1  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap Centers tab | Centers management screen |
| 2 | Tap "Add Center" FAB (bottom-right) | Add Center form screen |
| 3 | Enter name: "New Evacuation Center" | Field accepts input |
| 4 | Select barangay: "Zone 1" | Dropdown selection |
| 5 | Enter address: "123 Main St" | Field accepts input |
| 6 | Enter contact: "09171234567" | Field accepts input |
| 7 | Enter latitude: "12.6705" | Field accepts input |
| 8 | Enter longitude: "123.8762" | Field accepts input |
| 9 | Tap "Save" button | Processing |
| 10 | Wait for response | Success: "Center added successfully" |
| 11 | Verify in list | New center appears |
| 12 | Check resident app | New center visible to residents |

**Expected:** Center added successfully, visible immediately  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-008: Edit Evacuation Center

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

### TC-ADMIN-009: Analytics - Most Dangerous Barangays

**Priority:** P2  
**Type:** Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap Analytics tab | Analytics screen displayed |
| 2 | Scroll to "Most Dangerous Barangays" | Section visible |
| 3 | Verify list displayed | Top 5 barangays shown |
| 4 | Check data format | Barangay name, risk score, hazard count |
| 5 | Verify sorting | Sorted by risk score (highest first) |
| 6 | Check risk scores | Values between 0.0 and 1.0 |

**Expected:** Analytics data displayed correctly  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-ADMIN-010: Admin Settings - Logout

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

## 9. AI Algorithm Test Cases

### TC-AI-001: Naive Bayes - Valid Report (High Confidence)

**Priority:** P1  
**Type:** Functional (Algorithm)  
**Precondition:** Model trained with mock data

| Step | Action | Test Input | Expected Output |
|------|--------|------------|-----------------|
| 1 | Submit report via API | `{"hazard_type": "flooded_road", "description": "Severe flooding on main highway near market"}` | Report accepted |
| 2 | Check Naive Bayes score | Extract from response | Score >= 0.75 |
| 3 | Verify classification | Check logs | "Likely valid" |

**Expected:** NB score >= 0.75, classified as valid  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-002: Naive Bayes - Invalid Report (Low Confidence)

**Priority:** P1  
**Type:** Functional (Algorithm)

| Step | Action | Test Input | Expected Output |
|------|--------|------------|-----------------|
| 1 | Submit suspicious report | `{"hazard_type": "other", "description": "Test"}` | Report accepted (but flagged) |
| 2 | Check Naive Bayes score | Extract from response | Score < 0.5 |
| 3 | Verify status | Check report status | "Pending" or "Flagged" |

**Expected:** Low NB score, report flagged  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-003: Consensus Scoring - Multiple Reports

**Priority:** P1  
**Type:** Functional (Algorithm)  
**Precondition:** No existing reports at test location

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Submit report 1 at (12.6700, 123.8755) | NB score: 0.70, Consensus: 0 |
| 2 | Calculate consensus score | 0.7 × 0.70 + 0.3 × 0.5 = 0.64 |
| 3 | Submit report 2 at (12.6701, 123.8756) (30m away) | NB score: 0.75 |
| 4 | Check consensus for report 2 | Nearby count: 1 |
| 5 | Calculate boosted score | 0.7 × 0.75 + 0.3 × 0.6 = 0.705 |
| 6 | Verify score increased | Report 2 score > Report 1 score |

**Expected:** Consensus boosts confidence for nearby reports  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-004: Random Forest - Road Risk Prediction

**Priority:** P1  
**Type:** Functional (Algorithm)  
**Precondition:** Model trained, road segments exist

| Step | Action | Test Input | Expected Output |
|------|--------|------------|-----------------|
| 1 | Provide segment features | `{"nearby_hazard_count": 5, "avg_severity": 0.8}` | High risk predicted |
| 2 | Call predict_risk() | Pass features to RF model | Risk score: 0.7 - 0.9 |
| 3 | Verify classification | Check risk level | "Red" (High Risk) |
| 4 | Test low-risk segment | `{"nearby_hazard_count": 0, "avg_severity": 0.1}` | Risk score: 0.0 - 0.3 (Green) |

**Expected:** RF predicts high risk for high-hazard segments  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-AI-005: Modified Dijkstra - Safest Route

**Priority:** P0  
**Type:** Functional (Algorithm)  
**Precondition:** Road network with varying risk scores

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Set up test road network | 2 routes: Route A (2km, risk 0.9), Route B (4km, risk 0.1) |
| 2 | Calculate weights | A: 2 + (0.9 × 500) = 452, B: 4 + (0.1 × 500) = 54 |
| 3 | Run Modified Dijkstra | Start and end nodes defined |
| 4 | Verify route selection | Route B chosen (lower weight) |
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
| 2 | Scroll to Admin Actions | "Retrain AI Models" button visible |
| 3 | Tap "Retrain AI Models" | Confirmation dialog |
| 4 | Confirm action | Processing indicator |
| 5 | Wait for retraining (30-60 sec) | Success message |
| 6 | Check model version | Version number incremented |
| 7 | Verify new predictions | Use retrained models |

**Expected:** Models retrained successfully  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 10. Offline Mode Test Cases

### TC-OFFLINE-001: App Launch Offline

**Priority:** P1  
**Type:** Functional (Offline)  
**Precondition:** Data cached from previous online session

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Turn off WiFi and mobile data | Device offline |
| 2 | Close app completely | App not running |
| 3 | Open app | App launches successfully |
| 4 | Check offline indicator | "Offline" badge in app bar |
| 5 | Navigate to map | Map displays with cached tiles |
| 6 | Check evacuation centers | Centers loaded from cache |
| 7 | Verify limited functionality | Warning: "Using cached data" |

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
| 4 | Verify local storage | Report saved in Hive queue |
| 5 | Submit 2nd report offline | Also queued |
| 6 | Check queue count | 2 reports pending |
| 7 | Turn on internet | Device online |
| 8 | Trigger sync (pull to refresh or wait) | Auto-sync starts |
| 9 | Monitor console | "Syncing 2 reports..." |
| 10 | Wait for completion | "Sync complete!" |
| 11 | Check queue | Empty (reports sent) |

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
| 6 | Check console | "✅ Using cached routes (offline mode)" |
| 7 | Verify route accuracy | Same route as before |

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
| 3 | Open app, login (if credentials cached) | App opens |
| 4 | Select evacuation center | Center details |
| 5 | Tap "Get Directions" | Loading indicator |
| 6 | Wait for timeout | Error message displayed |
| 7 | Verify error text | "Unable to calculate routes. Please check your internet connection and try again." |
| 8 | Check no broken route displayed | No geometric fallback shown |

**Expected:** Clear error, no broken routes  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-OFFLINE-005: Cache Expiration

**Priority:** P2  
**Type:** Functional  
**Precondition:** Cached data older than expiry period

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Set system date forward by 8 days | Simulate time passage |
| 2 | Open app offline | App launches |
| 3 | Check evacuation centers | Cache expired (> 7 days) |
| 4 | Verify behavior | Shows warning: "Data may be outdated" |
| 5 | Turn on internet | Device online |
| 6 | Pull to refresh | Fetch fresh data |
| 7 | Verify cache updated | New expiry timestamp |

**Expected:** Expired cache handled gracefully  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-OFFLINE-006: Intermittent Connectivity

**Priority:** P2  
**Type:** Functional (Network)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start with internet | App online |
| 2 | Calculate route | OSRM success |
| 3 | Turn off internet mid-operation | Connection lost |
| 4 | Check error handling | Graceful failure, retry logic |
| 5 | Turn on internet | Connection restored |
| 6 | Verify auto-retry | Operation resumes |
| 7 | Check console | "Connection restored, retrying..." |

**Expected:** App handles connectivity changes gracefully  
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
5. Record time
6. Repeat 5 times, average results

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

**Measurement:** Start timer when map widget builds, stop when all elements rendered  
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
| Medium route (2-5 km) | < 5 seconds |
| Long route (> 5 km) | < 7 seconds |

**Test Steps:**
1. Select evacuation center
2. Tap "Get Directions"
3. Start timer
4. Wait for routes displayed
5. Stop timer
6. Record time

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
| POST /calculate-route/ | < 2 seconds (excluding OSRM) |
| GET /mdrrmo/dashboard-stats/ | < 1 second |

**Test Method:** Use API testing tool (Postman) with timer  
**Expected:** All endpoints within limits  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-PERF-005: Memory Usage

**Priority:** P2  
**Type:** Performance

| Scenario | Maximum RAM |
|----------|-------------|
| Idle (map displayed) | 150 MB |
| Navigation active | 200 MB |
| Multiple reports queued | 180 MB |
| After 30 min use | < 220 MB |

**Test Method:** 
1. Use Android Profiler
2. Monitor memory over 30 minutes
3. Record peak usage

**Expected:** Always < 200 MB  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-PERF-006: Battery Consumption

**Priority:** P2  
**Type:** Performance  
**Precondition:** Fully charged device

| Scenario | Duration | Max Battery Drain |
|----------|----------|-------------------|
| Active use (navigation) | 1 hour | 10% |
| Idle (app open) | 1 hour | 3% |
| Background (app paused) | 1 hour | 1% |

**Test Method:**
1. Charge device to 100%
2. Use app for specified duration
3. Record battery % remaining
4. Calculate drain rate

**Expected:** Within limits above  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-PERF-007: Network Data Usage

**Priority:** P2  
**Type:** Performance

| Action | Maximum Data |
|--------|--------------|
| App launch + map load | 2 MB |
| Calculate route (OSRM) | 500 KB |
| Submit report (no media) | 50 KB |
| Submit report (with photo) | 1.5 MB |
| 30 minutes normal use | 10 MB |

**Test Method:** Use Android data usage monitor  
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
| 6 | Verify token signature | Valid signature |
| 7 | Modify token payload | Signature verification fails, 401 error |

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
| 1 | Search centers with input: "'; DROP TABLE users; --" | Search executed safely |
| 2 | Verify no SQL executed | Users table still exists |
| 3 | Check results | Empty or no match (input treated as literal string) |
| 4 | Try injection in login: email=`admin' OR '1'='1` | Login fails |
| 5 | Verify ORM usage | All queries use parameterized statements |

**Expected:** SQL injection blocked by ORM  
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
| 3 | Try oversized file: 15 MB image | Error: "File size exceeds 10 MB limit" |
| 4 | Upload valid JPEG | Success, file accepted |
| 5 | Check file storage | Stored outside web root |
| 6 | Verify filename sanitization | Special characters removed |

**Expected:** Only image/video files accepted, size limited  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-SEC-006: Rate Limiting

**Priority:** P2  
**Type:** Security

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Make 5 API calls in 1 minute | All succeed |
| 2 | Make 15 more calls rapidly | Some succeed |
| 3 | Continue making calls | 429 Too Many Requests |
| 4 | Wait 1 minute | Rate limit resets |
| 5 | Make new call | 200 OK |

**Expected:** Rate limiting active (10-20 req/min per user)  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-SEC-007: Data Privacy - Reporter Anonymization

**Priority:** P1  
**Type:** Security/Privacy

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Resident A submits report | Report created |
| 2 | Login as Resident B | Different user |
| 3 | View map with hazards | Hazards visible |
| 4 | Tap hazard marker | Details displayed |
| 5 | Check reporter info | Shows "Reporter ID: #12345" (not name) |
| 6 | Login as MDRRMO | Admin user |
| 7 | View same report | Full reporter info visible |

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
| 2 | Verify API URL | `https://router.project-osrm.org/route/v1/driving/...` |
| 3 | Check request parameters | coordinates, alternatives=2, geometries=geojson |
| 4 | Verify response | 200 OK, JSON with routes array |
| 5 | Parse GeoJSON | Coordinates extracted |
| 6 | Display route | Polyline follows roads correctly |

**Expected:** OSRM integration works end-to-end  
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
| 3 | Check tile requests | Multiple tiles for visible area |
| 4 | Zoom in | Higher zoom level tiles load |
| 5 | Pan map | New tiles load for new area |
| 6 | Verify attribution | "© OpenStreetMap contributors" displayed |

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
| 2 | App requests GPS | Geolocator.getCurrentPosition() called |
| 3 | Wait for GPS fix | Position returned |
| 4 | Verify coordinates | Valid lat/lng values |
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
| 1 | Mobile app: Register user | POST /auth/register/ |
| 2 | Verify in database | User record created |
| 3 | Mobile app: Login | POST /auth/login/, JWT returned |
| 4 | Mobile app: Get centers | GET /evacuation-centers/, list returned |
| 5 | Mobile app: Submit report | POST /hazards/, AI validation runs |
| 6 | Verify in database | Report saved with NB/Consensus scores |
| 7 | Admin app: Approve report | PUT /hazards/{id}/approve/ |
| 8 | Verify status updated | Status changed to "approved" |

**Expected:** Full mobile-backend integration works  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-INT-005: AI Algorithms Integration

**Priority:** P1  
**Type:** Integration

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Submit hazard report | Backend receives |
| 2 | NB validation runs | Score calculated |
| 3 | Consensus check runs | Nearby reports counted, score boosted |
| 4 | Report approved | RF triggered for road risk update |
| 5 | Road risk recalculated | Risk scores updated for nearby segments |
| 6 | Route calculation requested | Modified Dijkstra uses updated risk scores |
| 7 | Verify route avoids high-risk roads | Safest route selected |

**Expected:** All 4 algorithms work together correctly  
**Actual:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 14. User Acceptance Test Cases

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
| 4 | Find nearest safe evacuation center | List shows 5 centers, sorted by distance |
| 5 | Select closest center | Center details displayed |
| 6 | Request safest route | 3 routes calculated |
| 7 | Review route options | Understand Green/Yellow/Red risk levels |
| 8 | Select safest (Green) route | Navigation starts |
| 9 | Follow turn-by-turn directions | Clear guidance provided |
| 10 | Arrive at evacuation center | Navigation complete |

**Acceptance Criteria:**
- ✓ User can complete evacuation without assistance
- ✓ Route avoids known hazards
- ✓ User feels confident in app guidance

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
| 4 | Select hazard type: "Flooded Road" | Type selected easily |
| 5 | Describe: "Water 2 feet deep, impassable" | Description entered |
| 6 | Take photo of flooding | Photo captured |
| 7 | Submit report | Success message |
| 8 | Verify report visible on map | New red marker appears |
| 9 | Check if works offline (if no signal) | Report queued for later |

**Acceptance Criteria:**
- ✓ Reporting process < 2 minutes
- ✓ User understands all steps
- ✓ Photo upload works
- ✓ Offline queueing transparent

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
| 2 | Navigate to Dashboard | See summary statistics |
| 3 | Check pending reports count | Number of reports awaiting review |
| 4 | Go to Reports tab | List of all reports |
| 5 | Filter by "Pending" | Only pending reports shown |
| 6 | Select a report to review | Detail view opens |
| 7 | Review AI scores (NB, Consensus) | Scores help decision-making |
| 8 | View attached photo | Photo displays |
| 9 | Check location on map | Map preview shown |
| 10 | Decide: Approve if valid | Tap "Approve" |
| 11 | Add comment: "Verified by field team" | Comment saved |
| 12 | Verify report marked as "Approved" | Status updated |

**Acceptance Criteria:**
- ✓ MDRRMO can review 10 reports in < 15 minutes
- ✓ AI scores help decision-making
- ✓ Interface intuitive, no training needed
- ✓ Approve/reject process clear

**Actual User Feedback:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-UAT-004: Evacuation Center Management

**Priority:** P1  
**Type:** UAT  
**Tester:** MDRRMO personnel

**Scenario:** MDRRMO needs to add new evacuation center

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login as MDRRMO | Admin interface |
| 2 | Navigate to Centers tab | List of existing centers |
| 3 | Tap "Add Center" button | Form opens |
| 4 | Fill in center details | All fields clear and labeled |
| 5 | Enter GPS coordinates (or get from map) | Coordinates accepted |
| 6 | Save new center | Success confirmation |
| 7 | Verify center appears in list | New center visible |
| 8 | Check resident app | New center available to residents |

**Acceptance Criteria:**
- ✓ Adding center takes < 3 minutes
- ✓ Form fields intuitive
- ✓ Changes reflect immediately for residents

**Actual User Feedback:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-UAT-005: Offline Usage During Emergency

**Priority:** P1  
**Type:** UAT  
**Tester:** Resident user

**Scenario:** Power outage, limited cell service, but user needs route

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Previous day: Use app online | Data cached |
| 2 | Emergency day: No internet | Device offline |
| 3 | Open app | App launches despite no connection |
| 4 | Check evacuation centers | Centers visible from cache |
| 5 | Request route to nearest center | Route loads (if previously calculated) |
| 6 | If not cached: See clear error message | "Connect to internet" message |
| 7 | Report hazard offline | Report queued |
| 8 | Later: Internet restored | Reports auto-sync |

**Acceptance Criteria:**
- ✓ App usable offline with cached data
- ✓ User understands offline limitations
- ✓ Offline indicators clear
- ✓ Auto-sync works when back online

**Actual User Feedback:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

### TC-UAT-006: Overall User Satisfaction

**Priority:** P1  
**Type:** UAT  
**Tester:** Multiple users (5 residents, 2 MDRRMO)

**Survey Questions:**

| Question | Scale (1-5) | Average Score |
|----------|-------------|---------------|
| How easy was it to learn the app? | 1=Very Difficult, 5=Very Easy | _____ |
| How confident are you in the route safety? | 1=Not Confident, 5=Very Confident | _____ |
| How useful is the hazard reporting feature? | 1=Not Useful, 5=Very Useful | _____ |
| Would you recommend this app to others? | 1=Never, 5=Definitely | _____ |
| Overall satisfaction with the app | 1=Very Dissatisfied, 5=Very Satisfied | _____ |

**Acceptance Criteria:**
- ✓ Average score >= 4.0 for all questions
- ✓ No critical usability issues reported
- ✓ 80%+ users would recommend

**Actual Results:** _____  
**Status:** ☐ Pass ☐ Fail ☐ Blocked

---

## 15. Test Metrics and Reporting

### 15.1 Test Coverage

| Component | Total Test Cases | Executed | Passed | Failed | Blocked | Coverage % |
|-----------|------------------|----------|--------|--------|---------|------------|
| Authentication | 7 | | | | | |
| Evacuation Centers | 5 | | | | | |
| Routing | 7 | | | | | |
| Hazard Reporting | 5 | | | | | |
| Admin Dashboard | 10 | | | | | |
| AI Algorithms | 6 | | | | | |
| Offline Mode | 6 | | | | | |
| Performance | 7 | | | | | |
| Security | 7 | | | | | |
| Integration | 5 | | | | | |
| UAT | 6 | | | | | |
| **TOTAL** | **71** | | | | | |

### 15.2 Defect Summary

| Severity | Count | Description |
|----------|-------|-------------|
| Critical (P0) | | Blocks core functionality |
| High (P1) | | Major feature broken |
| Medium (P2) | | Minor feature issue |
| Low (P3) | | Cosmetic/enhancement |

### 15.3 Test Environment Summary

- **Devices Tested:** _____
- **OS Versions:** _____
- **Network Conditions:** WiFi, 4G, 3G, Offline
- **Test Duration:** From _____ to _____
- **Testers:** _____

### 15.4 Sign-Off

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
- **Revision History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-02-05 | Team | Initial draft |
| 0.5 | 2026-02-07 | Team | Added UAT cases |
| 1.0 | 2026-02-08 | Team | Final version |

**Total Test Cases:** 71+  
**Total Pages:** 60+
