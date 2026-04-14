# Offline Mode — Technical Documentation

**System:** AI-Powered Evacuation Route Recommendation System  
**Module:** Offline Mode & Fallback Logic  
**Last Updated:** April 2026

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Data Caching Strategy](#3-data-caching-strategy)
4. [Connectivity Detection](#4-connectivity-detection)
5. [Offline Report Queue](#5-offline-report-queue)
6. [Auto-Sync Mechanism](#6-auto-sync-mechanism)
7. [Offline UI Indicator](#7-offline-ui-indicator)
8. [Feature Availability Matrix](#8-feature-availability-matrix)
9. [Fallback Logic Per Feature](#9-fallback-logic-per-feature)
10. [No MDRRMO Data Handling](#10-no-mdrrmo-data-handling)
11. [Failsafe Design](#11-failsafe-design)
12. [Data Flow Diagrams](#12-data-flow-diagrams)
13. [File Reference](#13-file-reference)

---

## 1. Overview

The Evacuation Route Recommendation System operates in two modes:

| Mode | Data Source | API Calls |
|------|-------------|-----------|
| **Online** | Backend (Django REST API) → Hive cache | Yes |
| **Offline** | Hive (local device storage) only | No |

The system is designed so that **no core feature crashes or blocks the user** when the device has no internet connection. Users can still view the map, see cached hazards, select evacuation centers, and submit hazard reports — which are queued and sent automatically when connectivity returns.

> **Key principle:** Online = API first, cache on success.  
> Offline = Hive only, no API calls attempted.  
> These two paths are never mixed in a single request.

---

## 2. Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────┐
│                   Flutter App                        │
│                                                      │
│  ┌────────────┐   ┌──────────────┐  ┌────────────┐  │
│  │ Map Screen │   │ Report Screen│  │Auth Screen │  │
│  └─────┬──────┘   └──────┬───────┘  └────────────┘  │
│        │                 │                           │
│  ┌─────▼──────────────────▼──────────────────────┐   │
│  │             Service Layer                      │   │
│  │  RoutingService  │  HazardService              │   │
│  └─────┬────────────────────┬──────────────────┬──┘   │
│        │                    │                  │      │
│  ┌─────▼────┐  ┌────────────▼───┐  ┌──────────▼──┐   │
│  │ ApiClient│  │ConnectivitySvc │  │StorageService│   │
│  │  (Dio)   │  │(connectivity+) │  │   (Hive)     │   │
│  └─────┬────┘  └────────────┬───┘  └──────────────┘   │
│        │                    │                          │
│  ┌─────▼────┐  ┌────────────▼─────────────────────┐   │
│  │ Backend  │  │         SyncService               │   │
│  │ (Django) │  │  (auto-sync on reconnect)         │   │
│  └──────────┘  └──────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### Key Classes

| Class | File | Responsibility |
|-------|------|----------------|
| `ConnectivityService` | `core/services/connectivity_service.dart` | Monitors network state; exposes `isOnline` and a change stream |
| `SyncService` | `core/services/sync_service.dart` | Orchestrates data refresh and queue flush when connectivity returns |
| `StorageService` | `core/storage/storage_service.dart` | All Hive read/write operations |
| `OfflineBanner` | `ui/widgets/offline_banner.dart` | Animated UI indicator shown when offline |
| `HazardService` | `features/hazards/hazard_service.dart` | Hazard API calls; offline queue management; verified hazard caching |
| `RoutingService` | `features/routing/routing_service.dart` | Evacuation center API calls; route caching; Hive fallback |

---

## 3. Data Caching Strategy

### Hive Box Layout

The app uses six Hive boxes for persistent offline storage:

| Box Name | Key (`StorageConfig`) | Contents | Written When |
|----------|-----------------------|----------|--------------|
| `evacuation_centers` | `evacuationCentersBox` | List of all evacuation centers (JSON) | Every successful API fetch |
| `baseline_hazards` | `baselineHazardsBox` | MDRRMO-provided baseline hazard data | Bootstrap sync |
| `road_segments` | `roadSegmentsBox` | Road graph data + cached route results | Sync + route calculation |
| `user` | `userBox` | Current user profile (JSON) | After login / profile update |
| `pending_reports` | `pendingReportsBox` | Offline-queued hazard reports waiting to sync | On offline submission |
| `verified_hazards` | `verifiedHazardsBox` | Approved hazard reports for map display | Every successful API fetch |

> **Important:** `pending_reports` is intentionally isolated from all other boxes.  
> `clearAllCache()` does **not** wipe the pending queue — only `clearPendingReports()` does.

### Cache TTL (Time-to-Live)

| Data Type | TTL | Behaviour on Expiry |
|-----------|-----|---------------------|
| Route results | 7 days | Re-fetched from API; offline fallback removed |
| Evacuation centers | Indefinite | Served stale until next sync |
| Verified hazards | Indefinite | Served stale until next sync |
| Pending reports | Until synced | Retained until successfully sent |

### What Gets Cached and When

```
Online path (success):
  GET /evacuation-centers/    →  parse  →  save to Hive  →  return to UI
  GET /verified-hazards/      →  parse  →  save to Hive  →  return to UI
  POST /calculate-route/      →  parse  →  save route to Hive  →  return to UI

Offline path:
  (API call skipped)
  Read from Hive  →  return to UI (or return empty list if no cache)
```

---

## 4. Connectivity Detection

### Implementation

`ConnectivityService` wraps the `connectivity_plus` package and exposes two interfaces:

```dart
// One-time check (async)
final bool online = await ConnectivityService().isOnline;

// Continuous stream (listen for changes)
ConnectivityService().onConnectionChange.listen((bool isOnline) {
  // fires only when status actually changes (deduplicated)
});
```

### Connectivity States

| `connectivity_plus` result | App interpretation |
|----------------------------|--------------------|
| `ConnectivityResult.wifi` | Online |
| `ConnectivityResult.mobile` | Online |
| `ConnectivityResult.ethernet` | Online |
| `ConnectivityResult.none` | Offline |

> **Note:** Having a WiFi or mobile connection does not guarantee internet reachability (e.g. captive portal). The connectivity check detects the presence of a network interface, which is sufficient for triggering sync and showing/hiding the banner. Actual API failures are handled gracefully via try/catch with Hive fallback.

### Stream Deduplication

The stream uses `.distinct()` so listeners only fire on **transitions** (online→offline or offline→online), not on every periodic connectivity check.

---

## 5. Offline Report Queue

### How It Works

When a resident submits a hazard report while offline, the system:

1. **Does not reject the submission.** The UI shows a success response immediately.
2. Saves the report as JSON to the `pending_reports` Hive box with status `"pending"`.
3. Displays the pending count in the `OfflineBanner` widget.
4. Automatically sends the report when internet is restored (see §6).

### Queue Data Structure

Each queued entry is the full `HazardReport.toJson()` map:

```json
{
  "id": 1743649273000,
  "hazard_type": "flood",
  "latitude": 12.6700,
  "longitude": 123.8755,
  "description": "Water rising on main road",
  "photo_url": "data:image/jpeg;base64,...",
  "status": "pending",
  "naive_bayes_score": 0.0,
  "consensus_score": 0.0,
  "created_at": "2026-04-03T10:30:00.000Z"
}
```

> The `id` is a local timestamp-based integer. It is replaced by the server-assigned ID after successful sync.

### Partial Sync Resilience

If sync fails for some reports (network drops mid-sync), only the failed reports remain in the queue. Successfully sent reports are removed immediately. On the next connectivity event, the remaining reports are retried.

```
Queue: [A, B, C]
Sync attempt:
  A → success  → removed from queue
  B → timeout  → kept in queue
  C → success  → removed from queue
Queue after: [B]
Next sync: [B] retried
```

---

## 6. Auto-Sync Mechanism

### Trigger

`SyncService.startListening()` is called once at app startup (`main.dart`). It subscribes to `ConnectivityService.onConnectionChange`. Every time the stream emits `true` (device goes online), a sync cycle is triggered.

### Sync Cycle (in order)

```
Internet restored
       │
       ▼
1. Flush pending_reports queue
   ├─ POST each report to /api/report-hazard/
   ├─ Remove succeeded entries
   └─ Keep failed entries for next cycle
       │
       ▼
2. Refresh evacuation centers
   └─ GET /api/evacuation-centers/ → save to Hive
       │
       ▼
3. Refresh verified hazards
   └─ GET /api/verified-hazards/ → save to Hive
       │
       ▼
4. Save last_sync_time to SharedPreferences
       │
       ▼
Sync complete
```

### Concurrency Guard

`SyncService` uses a `_syncing` boolean flag to prevent concurrent sync cycles. If a sync is already in progress when another connectivity event fires, the second call is a no-op.

### Map Screen Live Reload

In addition to the background `SyncService`, `MapScreen` independently listens for connectivity changes and reloads its evacuation center and hazard overlays when the connection is restored:

```dart
_connectivity.onConnectionChange.listen((isOnline) {
  if (isOnline && mounted) {
    _loadEvacuationCenters();  // re-render map pins
    _loadHazardReports();      // re-render hazard overlays
  }
});
```

---

## 7. Offline UI Indicator

### Appearance

A persistent red banner slides down from the top of the screen when offline:

```
┌─────────────────────────────────────────────────────┐
│ 📵  Offline Mode: Data may not be up-to-date         │
│      3 reports queued — will sync when online        │
└─────────────────────────────────────────────────────┘
```

### Behaviour

| Event | Banner Action |
|-------|---------------|
| App starts offline | Slides in immediately after initial connectivity check |
| Loses connection | Slides in with `Curves.easeOut` animation (300 ms) |
| Regains connection | Slides out (reverse animation) |
| Reports queued | Subtitle shows count dynamically |
| No pending reports | Only primary line shown |

### Integration

`OfflineBanner` is a `Positioned` widget added as the **last child** of every relevant screen's `Stack`. This ensures it always renders above map tiles, buttons, and bottom sheets without affecting layout.

```dart
// In map_screen.dart — inside the Stack children list:
const OfflineBanner(),  // Always on top
```

---

## 8. Feature Availability Matrix

| Feature | Online | Offline (cached) | Offline (no cache) |
|---------|--------|-------------------|--------------------|
| View map tiles | ✅ Live | ✅ Cached by flutter_map | ⚠️ Last cached tiles |
| View evacuation centers | ✅ Live | ✅ From Hive | ⚠️ Empty list, no crash |
| View verified hazards | ✅ Live | ✅ From Hive | ⚠️ Empty list, no crash |
| Select evacuation center | ✅ | ✅ | ✅ |
| Calculate route | ✅ Via Django backend | ✅ Cached routes | ⚠️ "No cache" message |
| Submit hazard report | ✅ Immediate | ✅ Queued (auto-sync) | ✅ Queued (auto-sync) |
| View my reports | ✅ Live | ⚠️ Empty list | ⚠️ Empty list |
| Login / Register | ✅ | ❌ Requires network | ❌ Requires network |
| Auto-login (token) | ✅ | ✅ Token in SecureStorage | ✅ Token in SecureStorage |
| Live navigation | ✅ | ⚠️ Cached route only | ❌ No route available |

**Legend:** ✅ Fully functional · ⚠️ Degraded / cached · ❌ Not available

---

## 9. Fallback Logic Per Feature

### 9.1 Evacuation Centers

```
_loadEvacuationCenters()
  └─ RoutingService.getEvacuationCenters()
        ├─ [online]  GET /api/evacuation-centers/
        │            → parse → save to Hive → return list
        └─ [offline] read from Hive
                     ├─ cache exists → return cached list
                     └─ no cache     → return [] (empty, no crash)
```

### 9.2 Verified Hazards (Map Overlay)

```
HazardService.getVerifiedHazards()
  ├─ [online]  GET /api/verified-hazards/
  │            → parse → save to Hive → return list
  └─ [offline] read from Hive (verified_hazards box)
               ├─ cache exists → return cached list
               └─ no cache     → return [] (empty, no crash)
```

### 9.3 Route Calculation

```
RoutingService.calculateRoutes()
  ├─ [online]  POST /api/calculate-route/  (Django Modified Dijkstra)
  │            → parse → save route to Hive → return result
  └─ [API fails] read cached routes from Hive (road_segments box)
                 ├─ cached (< 7 days old) → return cached result
                 └─ no cache / expired    → throw Exception (UI shows error)
```

### 9.4 Hazard Report Submission

```
HazardService.submitHazardReport()
  ├─ [online]  POST /api/report-hazard/
  │            → return HazardReport
  └─ [network error] _queueHazardReport()
                     → save to pending_reports box
                     → return optimistic HazardReport (status: pending)
                     → UI shows "queued" confirmation
```

### 9.5 Session Restore on App Start

```
AuthGateScreen._restoreSession()
  ├─ read token from SecureStorage
  │   └─ no token → WelcomeScreen
  ├─ check session expiry (7 days)
  │   └─ expired → clear session → WelcomeScreen
  ├─ read role from SharedPreferences cache
  │   └─ cache hit → skip network call → route to home screen immediately
  └─ cache miss → GET /api/auth/profile/
                  ├─ success → route to home screen
                  └─ failure → clear session → WelcomeScreen
```

---

## 10. No MDRRMO Data Handling

Since MDRRMO historical data and Random Forest model data may not be available during early deployment, the system uses a fallback risk logic that does not block routing or hazard display.

### Risk Score Fallback

When no MDRRMO data or backend risk calculation is available, a base risk value is used:

```
fallback_risk = base_risk + hazard_impact

Where:
  base_risk     = 0.20  (20% — conservative default)
  hazard_impact = derived from count and type of nearby approved reports
```

### Routing Without MDRRMO Data

| Condition | Behaviour |
|-----------|-----------|
| Backend route calculation available | Use Django Modified Dijkstra (full risk scoring) |
| Backend unavailable, route cached | Serve cached route with last-known risk scores |
| No backend, no cache | Show evacuation centers on map; user can navigate manually |
| No evacuation centers in cache | Show map only; center selection unavailable |

The system **never blocks the map from loading** due to missing data. Empty states are shown with appropriate messages, not crash screens.

---

## 11. Failsafe Design

### Null / Empty Handling

Every offline data-fetch method returns a safe empty type rather than throwing when no data is available:

| Method | Returns on failure |
|--------|-------------------|
| `getEvacuationCenters()` | `[]` (empty list) |
| `getVerifiedHazards()` | `[]` (empty list) |
| `getMyReports()` | `[]` (empty list) |
| `getCalculatedRoutes()` | `null` (triggers error UI, not crash) |
| `getPendingReports()` | `[]` (empty list) |

### No-Crash Contract

The app guarantees no crashes under these conditions:

- No MDRRMO data available
- No road segment graph in Hive
- Empty Hive cache (first install, no sync yet)
- Network timeout or server error
- Server returns unexpected JSON shape

### Error Recovery Priority

```
1st: Live API data
2nd: Hive cache (any age)
3rd: Empty list / empty state UI
4th: (never) crash
```

---

## 12. Data Flow Diagrams

### Online → Cache → Offline Flow

```
First launch (online):
  App start → Hive initialized → Auth gate → Login
  Map screen → API fetch evacuation centers → Cache to Hive
            → API fetch verified hazards → Cache to Hive
  User selects center → API calculate route → Cache route to Hive

Later (offline):
  App start → Token in SecureStorage → Cached role → Home screen (instant)
  Map screen → API fails → Hive fallback → Show cached centers + hazards
  User selects center → API fails → Hive route cache → Show cached route
  User submits report → API fails → Queue to pending_reports box

Connection restored:
  SyncService fires → Flush queue → Refresh centers → Refresh hazards
  Map screen reloads evacuation centers + hazards from fresh API data
```

### Pending Report Lifecycle

```
[User submits report offline]
          │
          ▼
  Save to pending_reports box
  (status: "pending", id: timestamp)
          │
          ▼
  OfflineBanner shows count
          │
    (time passes)
          │
          ▼
  [Connection restored]
          │
          ▼
  SyncService.syncQueuedReports()
          │
     ┌────┴────┐
   success   failure
     │           │
  Remove     Keep in queue
  from       (retry next
  queue       connection)
```

---

## 13. File Reference

### New Files (created for offline mode)

| File | Purpose |
|------|---------|
| `lib/core/services/connectivity_service.dart` | Network status singleton using `connectivity_plus` |
| `lib/core/services/sync_service.dart` | Auto-sync orchestrator (queue flush + data refresh) |
| `lib/ui/widgets/offline_banner.dart` | Animated offline indicator widget |

### Modified Files

| File | Changes |
|------|---------|
| `pubspec.yaml` | Added `connectivity_plus: ^6.0.0` |
| `lib/core/config/storage_config.dart` | Added `pendingReportsBox`, `verifiedHazardsBox` |
| `lib/core/storage/storage_service.dart` | New boxes opened; pending queue API; verified hazards API |
| `lib/features/hazards/hazard_service.dart` | Fixed queue box; fixed sync (no clearAllCache); added verified hazards caching + fallback; `getMyReports` no longer throws offline |
| `lib/features/routing/routing_service.dart` | `getEvacuationCenters` caches on success; Hive fallback on failure |
| `lib/ui/screens/map_screen.dart` | Added `OfflineBanner`; added reconnect-triggered data reload |
| `lib/main.dart` | `SyncService().startListening()` called at startup |

### Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `connectivity_plus` | `^6.0.0` | Network interface monitoring |
| `hive` | `^2.2.3` | Key-value offline storage engine |
| `hive_flutter` | `^1.1.0` | Flutter integration for Hive |
| `flutter_secure_storage` | `^9.2.4` | Secure auth token persistence |
| `shared_preferences` | `^2.2.0` | Lightweight key-value store (profile cache, sync time) |
