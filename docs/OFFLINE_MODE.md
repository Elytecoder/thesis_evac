# Offline Mode — Architecture & Behaviour

**Last updated:** April 2026  
**Project:** HAZNAV (Hazard-Aware Evacuation Navigator) · Bulan, Sorsogon

---

## Why Offline Mode Matters

Disasters frequently cause **weak signal, no mobile data, and network interruptions** —
exactly when residents most need the app.  The system is designed to **gracefully degrade**
rather than crash or lock the user out.

---

## Map Package

| Item | Value |
|------|-------|
| Map library | `flutter_map ^7.0.2` |
| Tile source | OpenStreetMap (`tile.openstreetmap.org`) |
| Tile caching | Custom `CachedNetworkTileProvider` (disk-based, no extra packages) |
| Cache location | `<app-cache>/map_tiles/{z}_{x}_{y}.png` |
| Offline fallback | Light-grey grid placeholder tile (no crash, no blank white screen) |

---

## Tile Caching — `CachedNetworkTileProvider`

**File:** `mobile/lib/core/map/cached_tile_provider.dart`

Every OSM tile that has been viewed at least once is **persisted as a PNG file** in the
app's cache directory (`getApplicationCacheDirectory()`).  The file name encodes the tile
coordinates (`{z}_{x}_{y}.png`) for fast lookup.

### Request lifecycle per tile

```
1. Check disk:  <cache>/map_tiles/{z}_{x}_{y}.png  exists?
   └─ YES → decode and return immediately  (offline-safe ✅)
   └─ NO  →
      2. Fetch from OSM over HTTP (uses Dio, already in project).
         ├─ 200 OK → save bytes to disk → decode and return  (caches for next time ✅)
         └─ Error  → draw grey 256×256 grid placeholder  (no crash ✅)
```

Tiles are **never auto-expired** — they change slowly and the Bulan municipality area is
small (~50 km²).  The total cache size at zoom 10–18 for Bulan is well under 50 MB.

### How tiles get pre-warmed

Tiles are cached **lazily** as the user pans and zooms the map.  To ensure offline
coverage:

1. Instruct users to open the map and **pan around Bulan** before going into the field.
2. Zoom into key areas (evacuation routes, barangay centres, EC locations).
3. Once tiles are cached they will render offline indefinitely.

> There is no automatic bulk pre-download because OSM's tile usage policy requires user
> interaction.  A future version could download a bounded region in the background with
> explicit user consent.

---

## Local Data Cache (Hive)

All persistent offline data lives in **Hive boxes** opened at app startup
(`StorageService.initialize()`):

| Hive Box | Key | Contents | Updated |
|----------|-----|----------|---------|
| `evacuation_centers` | `all` | List of operational ECs (name, lat/lng, barangay, capacity) | On launch + on sync |
| `verified_hazards` | `all` | Approved, non-deleted hazard reports | On launch + on sync |
| `pending_reports` | `queue` | Reports submitted while offline (PENDING_SYNC) | On report submission |
| `active_route` | `current` | Last selected route polyline + destination summary | During navigation |
| `trip_history` | `records` | Completed navigation sessions | On arrival |
| `user` | `current_user` | Essential profile fields | On login / profile update |

Session token is stored separately in `FlutterSecureStorage`; the user **stays logged in**
across restarts and connectivity loss.

---

## Offline Behaviour by Feature

### Map Screen

| Feature | Online | Offline |
|---------|--------|---------|
| Map tiles | Live OSM | Cached tiles (grey grid for uncached) |
| Approved hazard markers | Live from backend | Cached from last sync |
| Evacuation center markers | Live from backend | Cached from last sync |
| User GPS arrow | ✅ GPS is device-side, always works | ✅ Same |
| Pan / zoom / recenter | ✅ | ✅ |
| Own pending reports | Shown on map | Shown (from local queue + server) |

### Hazard Reporting

| Scenario | Behaviour |
|----------|-----------|
| **Online** | Report submitted immediately via `POST /api/report-hazard/` |
| **Offline** | Report saved locally to `pending_reports` Hive box with status `PENDING_SYNC` |
| **Shown on map** | Local pending reports shown immediately as yellow markers |
| **After reconnect** | `SyncService._flushPendingReports()` auto-uploads the queue |
| **Partial failure** | Only failed reports remain in queue; successful ones are removed |
| **Media** | Photos stored as base64 data URL; videos stored as a local file path on device — both are re-uploaded as multipart on reconnect and removed from queue only on confirmed success |

No duplicate uploads: each report is removed from the queue individually only after a
successful `200 OK` response.  Timestamps are the original submission time (not the sync
time).

### Live Navigation (Offline During Navigation)

| Feature | Behaviour when internet drops mid-navigation |
|---------|----------------------------------------------|
| Route polyline | **Stays visible** — loaded into memory/RAM before navigation started |
| GPS tracking | ✅ Continues — GPS is device-side |
| User arrow / heading | ✅ Continues — compass + GPS course fusion |
| Distance remaining | ✅ Continues — haversine calculation from current GPS |
| Arrival detection | ✅ Continues |
| Turn instructions | Visual banners still shown (pre-loaded steps from OSRM/polyline analysis) |
| **Rerouting** | Shows snackbar: *"Offline mode — Rerouting unavailable until connection returns. Current route is still shown."* — **does not crash, does not clear route** |

When connection restores, the next deviation check will trigger a normal backend reroute.

### Session Persistence

The user **is never force-logged out** due to being offline.  The DRF token is stored in
`FlutterSecureStorage`.  The `onUnauthorized` handler (401) only fires when the server
explicitly rejects the token — not on network timeouts.

---

## Offline Banner & Sync Indicator

**File:** `mobile/lib/ui/widgets/offline_banner.dart`

| State | Banner colour | Message |
|-------|--------------|---------|
| Online, idle | Hidden | — |
| **Offline** | Dark red | "Offline Mode — Using cached maps and saved data" + pending count |
| **Back online, syncing** | Dark blue | "Back online — Syncing data…" + spinner |

The banner slides in/out with a 300 ms animation.  It auto-disappears once the sync cycle
completes.

---

## Auto-Sync on Reconnect

`SyncService` (singleton, started in `main.dart`) listens to
`ConnectivityService.onConnectionChange`.  When the stream emits `true` (online):

```
SyncService.syncAll():
  1. _flushPendingReports()   — upload queued offline reports
  2. _refreshEvacuationCenters() — update Hive cache
  3. _refreshVerifiedHazards()   — update Hive cache
  4. _saveLastSyncTime()         — record sync timestamp
```

Concurrent sync cycles are prevented by a `_syncing` guard.  Errors in any step are
logged but do not abort the remaining steps.

---

## Data Consistency Rules

- Soft-deleted hazards (`is_deleted=True`) are **excluded** from the verified hazards
  endpoint and therefore never enter the local cache.
- Pending hazards (not yet MDRRMO-approved) are **never** used in route calculation.
- Server always wins on conflict (e.g. a hazard deleted server-side after the last sync
  will be removed from cache on the next successful sync).

---

## Storage Summary

| Storage | Used for | Package |
|---------|----------|---------|
| `getApplicationCacheDirectory()` | OSM tile images | `path_provider` |
| Hive boxes | Structured data (hazards, ECs, routes, queue) | `hive_flutter` |
| `FlutterSecureStorage` | Auth token | `flutter_secure_storage` |
| `SharedPreferences` | User profile, settings, last sync time | `shared_preferences` |

---

## Known Limitations

| Limitation | Notes |
|------------|-------|
| Uncached tiles show grey grid | Expected; pan the area while online first |
| Rerouting disabled offline | Intended; original backend route stays visible |
| Hazards/ECs not updated offline | Shows data from last successful sync |
| Route calculation requires internet | Dijkstra runs on Django backend; no client-side fallback |
