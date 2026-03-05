# Live Navigation System Architecture

## System Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         RESIDENT USER INTERFACE                          │
│                                                                          │
│  ┌────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │ Map Screen │ -> │ Route Select │ -> │ Live Navigation Screen   │  │
│  │            │    │              │    │  (Full-Screen Turn-by-   │  │
│  │ - Centers  │    │ - 3 Routes   │    │   Turn Interface)        │  │
│  │ - Hazards  │    │ - Risk Info  │    │                          │  │
│  └────────────┘    └──────────────┘    └──────────┬───────────────┘  │
│                                                    │                    │
└────────────────────────────────────────────────────┼────────────────────┘
                                                     │
                ┌────────────────────────────────────┼───────────────────────────┐
                │                                    ▼                           │
                │        ┌─────────────────────────────────────────┐            │
                │        │   LiveNavigationScreen (Main UI)        │            │
                │        │                                          │            │
                │        │  ┌────────────────────────────────────┐ │            │
                │        │  │  Top Panel                          │ │            │
                │        │  │  - Turn Icon                        │ │            │
                │        │  │  - Instruction Text                 │ │            │
                │        │  │  - Distance to Next Turn            │ │            │
                │        │  │  - ETA + Total Distance             │ │            │
                │        │  └────────────────────────────────────┘ │            │
                │        │                                          │            │
                │        │  ┌────────────────────────────────────┐ │            │
                │        │  │  Center: Full-Screen Map            │ │            │
                │        │  │  - flutter_map                      │ │            │
                │        │  │  - Route Polyline (Blue)            │ │            │
                │        │  │  - User Marker (Blue Circle)        │ │            │
                │        │  │  - Destination Marker (Green)       │ │            │
                │        │  └────────────────────────────────────┘ │            │
                │        │                                          │            │
                │        │  ┌────────────────────────────────────┐ │            │
                │        │  │  Conditional: High-Risk Banner      │ │            │
                │        │  │  (Red, Warning Icon)                │ │            │
                │        │  └────────────────────────────────────┘ │            │
                │        │                                          │            │
                │        │  ┌────────────────────────────────────┐ │            │
                │        │  │  Bottom Panel                       │ │            │
                │        │  │  - Cancel Button (Red)              │ │            │
                │        │  │  - Voice Toggle (Blue/Gray)         │ │            │
                │        │  └────────────────────────────────────┘ │            │
                │        └──────────────┬───────────────┬──────────┘            │
                │                       │               │                        │
                └───────────────────────┼───────────────┼────────────────────────┘
                                        │               │
        ┌───────────────────────────────┼───────────────┼──────────────────────────┐
        │                               ▼               ▼                          │
        │                   ┌──────────────────┐  ┌─────────────────┐            │
        │                   │ GPSTracking      │  │ VoiceGuidance   │            │
        │                   │ Service          │  │ Service         │            │
        │                   │                  │  │                 │            │
        │                   │ - geolocator     │  │ - flutter_tts   │            │
        │                   │ - High accuracy  │  │ - Speech rate   │            │
        │                   │ - 5m updates     │  │ - On/Off toggle │            │
        │                   │ - Location       │  │ - Instructions  │            │
        │                   │   stream         │  │ - Warnings      │            │
        │                   └────────┬─────────┘  └─────────────────┘            │
        │                            │                                            │
        │                            ▼                                            │
        │                   ┌────────────────────────────────────────┐           │
        │                   │  RiskAwareRoutingService               │           │
        │                   │  (Main Routing Coordinator)            │           │
        │                   │                                        │           │
        │                   │  - calculateSafestRoute()              │           │
        │                   │  - hasDeviatedFromRoute()              │           │
        │                   │  - getCurrentHighRiskSegment()         │           │
        │                   │  - hasReachedDestination()             │           │
        │                   │  - Rerouting cooldown (5s)             │           │
        │                   └──────┬─────────────────┬───────────────┘           │
        │                          │                 │                            │
        │                          ▼                 ▼                            │
        │         ┌────────────────────────┐  ┌──────────────────────┐          │
        │         │ Backend API            │  │ OfflineRouting       │          │
        │         │ (Production)           │  │ Service              │          │
        │         │                        │  │                      │          │
        │         │ - POST /safest-route/  │  │ - Modified Dijkstra  │          │
        │         │ - NavigationRoute JSON │  │ - Risk-weighted cost │          │
        │         │ - Real-time hazards    │  │ - Cached road graph  │          │
        │         │ - ML predictions       │  │ - Cached hazards     │          │
        │         └────────────────────────┘  └──────┬───────────────┘          │
        │                                            │                            │
        │                                            ▼                            │
        │                                    ┌──────────────────┐                │
        │                                    │ Hive Cache       │                │
        │                                    │                  │                │
        │                                    │ - Road Graph     │                │
        │                                    │ - Hazard Data    │                │
        │                                    │ - Risk Scores    │                │
        │                                    │ - Evacuation     │                │
        │                                    │   Centers        │                │
        │                                    └──────────────────┘                │
        └─────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        NAVIGATION LIFECYCLE                              │
└─────────────────────────────────────────────────────────────────────────┘

1. INITIALIZATION
   ┌──────────────┐
   │ User Taps    │
   │ "Navigate"   │
   └──────┬───────┘
          │
          ▼
   ┌──────────────────┐
   │ Initialize       │
   │ - Voice Service  │
   │ - GPS Service    │
   │ - Route Calc     │
   └──────┬───────────┘
          │
          ▼
   ┌──────────────────┐
   │ Start GPS        │
   │ Tracking         │
   │ (5m updates)     │
   └──────┬───────────┘
          │
          ▼
   ┌──────────────────┐
   │ Calculate        │
   │ Initial Route    │
   └──────┬───────────┘
          │
          ▼
   ┌──────────────────┐
   │ Speak First      │
   │ Instruction      │
   └──────────────────┘

2. DURING NAVIGATION (Continuous Loop)
   ┌──────────────────┐
   │ GPS Update       │
   │ (Every 5 meters) │
   └──────┬───────────┘
          │
          ▼
   ┌──────────────────────────────┐
   │ Check Arrival                 │
   │ (Distance < 30m?)             │
   └──┬────────────────────────┬───┘
      │ YES                    │ NO
      ▼                        │
   ┌──────────────────┐        │
   │ 🎉 ARRIVED        │        │
   │ - Speak Arrival   │        │
   │ - Show Dialog     │        │
   │ - Stop Navigation │        │
   └──────────────────┘        │
                               ▼
                        ┌──────────────────────────┐
                        │ Check High-Risk Segment   │
                        │ (Risk Level ≥ 0.7?)       │
                        └──┬───────────────────┬────┘
                           │ YES               │ NO
                           ▼                   │
                        ┌──────────────────┐   │
                        │ 🚨 HIGH RISK     │   │
                        │ - Show Red Banner│   │
                        │ - Vibrate Device │   │
                        │ - Speak Warning  │   │
                        │ - Trigger Reroute│   │
                        └──────────────────┘   │
                                              ▼
                                       ┌──────────────────────────┐
                                       │ Check Deviation           │
                                       │ (Distance > 50m?)         │
                                       └──┬───────────────────┬────┘
                                          │ YES               │ NO
                                          ▼                   │
                                       ┌──────────────────┐   │
                                       │ ⚠️ DEVIATION     │   │
                                       │ - Show Orange    │   │
                                       │   Banner         │   │
                                       │ - Speak Warning  │   │
                                       │ - Trigger Reroute│   │
                                       └──────────────────┘   │
                                                             ▼
                                                      ┌──────────────────────┐
                                                      │ Update Current Step   │
                                                      │ (Distance < 20m?)     │
                                                      └──┬───────────────┬────┘
                                                         │ YES           │ NO
                                                         ▼               │
                                                      ┌──────────────┐   │
                                                      │ Advance Step │   │
                                                      │ - Next Step  │   │
                                                      │ - Speak New  │   │
                                                      │   Instruction│   │
                                                      └──────────────┘   │
                                                                        ▼
                                                                     ┌──────────────┐
                                                                     │ Update UI    │
                                                                     │ - Distance   │
                                                                     │ - ETA        │
                                                                     │ - Map Center │
                                                                     └──────────────┘

3. REROUTING FLOW
   ┌──────────────────┐
   │ Reroute Trigger  │
   │ (High-Risk or    │
   │  Deviation)      │
   └──────┬───────────┘
          │
          ▼
   ┌──────────────────────┐
   │ Check Cooldown       │
   │ (5 seconds since     │
   │  last reroute?)      │
   └──┬──────────────┬────┘
      │ YES          │ NO
      │              ▼
      │           ┌──────────────────┐
      │           │ Ignore (Too soon)│
      │           └──────────────────┘
      │
      ▼
   ┌──────────────────────┐
   │ Show "Recalculating" │
   │ Banner               │
   └──────┬───────────────┘
          │
          ▼
   ┌──────────────────────┐
   │ Try Backend API      │
   └──┬────────────────┬──┘
      │ Success        │ Fail
      ▼                │
   ┌──────────────┐    │
   │ Use API Route│    │
   └──────┬───────┘    │
          │            ▼
          │     ┌──────────────────────┐
          │     │ Use Offline Routing  │
          │     │ (Modified Dijkstra)  │
          │     └──────┬───────────────┘
          │            │
          └────────────┼────────────┐
                       │            │
                       ▼            │
                  ┌──────────────┐  │
                  │ New Route    │  │
                  │ Calculated   │  │
                  └──────┬───────┘  │
                         │          │
                         ▼          │
                  ┌──────────────┐  │
                  │ Update UI    │  │
                  │ Continue Nav │  │
                  └──────────────┘  │
                                   │
                                   ▼
                            ┌──────────────────┐
                            │ Hide "Recalc"    │
                            │ Banner           │
                            └──────────────────┘
```

---

## Risk-Aware Routing Algorithm

```
┌─────────────────────────────────────────────────────────────────┐
│            MODIFIED DIJKSTRA'S ALGORITHM                         │
└─────────────────────────────────────────────────────────────────┘

INPUT:
  - Start Location (LatLng)
  - Destination Location (LatLng)
  - Road Graph (Nodes + Edges)
  - Hazard Data (with risk scores)

COST FORMULA:
  cost(segment) = distance + (riskScore × RISK_WEIGHT)
  
  Where:
    distance      = physical distance in meters
    riskScore     = 0.0 (safe) to 1.0 (extreme danger)
    RISK_WEIGHT   = 5000.0 (5km penalty per 1.0 risk)

ALGORITHM STEPS:

1. INITIALIZE
   ┌────────────────────────────────────┐
   │ priority_queue = [(start, cost=0)] │
   │ visited = {}                        │
   │ parent = {}                         │
   └────────────────────────────────────┘

2. LOOP (While queue not empty)
   ┌──────────────────────────────────────────────┐
   │ current_node = queue.pop_min()               │
   │                                              │
   │ IF current_node == destination:              │
   │   RETURN reconstruct_path(parent)            │
   │                                              │
   │ FOR each neighbor of current_node:           │
   │   edge = get_edge(current_node, neighbor)    │
   │   risk = calculate_segment_risk(edge)        │
   │                                              │
   │   new_cost = current_cost                    │
   │            + edge.distance                   │
   │            + (risk × RISK_WEIGHT)            │
   │                                              │
   │   IF neighbor not visited OR new_cost < old: │
   │     visited[neighbor] = new_cost             │
   │     parent[neighbor] = current_node          │
   │     queue.push(neighbor, new_cost)           │
   └──────────────────────────────────────────────┘

3. GENERATE NAVIGATION STEPS
   ┌──────────────────────────────────────────┐
   │ path = list of nodes from start to end   │
   │                                          │
   │ FOR each consecutive pair in path:       │
   │   Calculate turn angle                   │
   │   Determine maneuver (left/right/str8)   │
   │   Create NavigationStep                  │
   └──────────────────────────────────────────┘

OUTPUT:
  NavigationRoute {
    polyline: [LatLng...]
    segments: [RouteSegment...]  // with risk scores
    steps: [NavigationStep...]   // turn-by-turn
    totalDistance: meters
    totalRiskScore: average
    overallRiskLevel: "safe"|"moderate"|"high"
    estimatedTimeSeconds: calculated
  }

EXAMPLE:

  Route Option A (Short but Risky):
    Distance: 1000m
    Risk: 0.8 (high)
    Cost: 1000 + (0.8 × 5000) = 5000m equivalent

  Route Option B (Longer but Safe):
    Distance: 3000m
    Risk: 0.1 (safe)
    Cost: 3000 + (0.1 × 5000) = 3500m equivalent

  RESULT: Algorithm chooses Route B (safer) ✅
```

---

## Service Interaction Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                  SERVICE LAYER INTERACTIONS                       │
└──────────────────────────────────────────────────────────────────┘

LiveNavigationScreen
     │
     ├─► GPSTrackingService
     │        │
     │        ├─► startTracking()
     │        │     └─► Geolocator.getPositionStream()
     │        │           └─► Stream<LatLng>
     │        │
     │        ├─► calculateDistance(point1, point2)
     │        │     └─► Geolocator.distanceBetween()
     │        │
     │        └─► stopTracking()
     │              └─► StreamSubscription.cancel()
     │
     ├─► VoiceGuidanceService
     │        │
     │        ├─► initialize()
     │        │     └─► FlutterTts.configure()
     │        │
     │        ├─► speakTurnInstruction(maneuver, distance)
     │        │     └─► FlutterTts.speak("Turn left in 80m")
     │        │
     │        ├─► speakRiskWarning()
     │        │     └─► FlutterTts.speak("Warning: High-risk area")
     │        │
     │        └─► setEnabled(bool)
     │
     └─► RiskAwareRoutingService
              │
              ├─► calculateSafestRoute(start, dest)
              │     │
              │     ├─► [Try] Backend API
              │     │     └─► POST /api/routing/safest-route/
              │     │           └─► NavigationRoute JSON
              │     │
              │     └─► [Fallback] OfflineRoutingService
              │           └─► calculateSafestRoute(start, dest)
              │                 │
              │                 ├─► Load Hive Cache
              │                 │     ├─► Road Graph
              │                 │     └─► Hazard Data
              │                 │
              │                 ├─► Run Modified Dijkstra
              │                 │     └─► cost = dist + (risk × 5000)
              │                 │
              │                 └─► Generate NavigationSteps
              │
              ├─► hasDeviatedFromRoute(userLoc, route)
              │     └─► findNearestSegment()
              │           └─► distance > 50m? → TRUE
              │
              ├─► getCurrentHighRiskSegment(userLoc, route)
              │     └─► findNearestSegment()
              │           └─► segment.riskLevel == "high"? → Segment
              │
              └─► hasReachedDestination(userLoc, dest)
                    └─► calculateDistance()
                          └─► distance < 30m? → TRUE
```

---

## State Management Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                     UI STATE MANAGEMENT                           │
└──────────────────────────────────────────────────────────────────┘

LiveNavigationScreen State Variables:
  ├─► _currentRoute: NavigationRoute?
  ├─► _userLocation: LatLng?
  ├─► _currentStep: NavigationStep?
  ├─► _currentHighRiskSegment: RouteSegment?
  ├─► _isLoading: bool
  ├─► _hasArrived: bool
  ├─► _isRerouting: bool
  ├─► _voiceEnabled: bool
  ├─► _distanceToNextStep: double
  └─► _totalDistanceRemaining: double

State Update Flow:

GPS Update
    │
    ▼
┌────────────────────────────────┐
│ _onLocationUpdate(LatLng)      │
│                                │
│ 1. Update _userLocation        │
│ 2. Check arrival               │ ─► _hasArrived = true
│ 3. Check high-risk             │ ─► _currentHighRiskSegment = segment
│ 4. Check deviation             │ ─► _isRerouting = true
│ 5. Update current step         │ ─► _currentStep = nextStep
│ 6. Update distances            │ ─► _distanceToNextStep = distance
│                                │
│ setState(() { ... })           │
└────────────────────────────────┘
    │
    ▼
UI Rebuild
    │
    ├─► Top Panel: Shows current step + distance
    ├─► Map: Centers on user location
    ├─► Warning Banner: Shows if high-risk
    ├─► Rerouting Indicator: Shows if rerouting
    └─► Bottom Panel: Cancel + Voice toggle
```

---

## Complete Feature Map

```
Live Turn-by-Turn Navigation System
│
├─► 📍 GPS Tracking
│   ├─ Real-time position stream
│   ├─ High accuracy mode
│   ├─ 5-meter update intervals
│   ├─ Distance calculation
│   └─ Bearing calculation
│
├─► 🗣️ Voice Guidance
│   ├─ Text-to-Speech engine
│   ├─ Turn instructions
│   ├─ Distance announcements
│   ├─ Risk warnings
│   ├─ Deviation alerts
│   ├─ Arrival notifications
│   └─ Enable/disable toggle
│
├─► 🧠 Risk-Aware Routing
│   ├─ Modified Dijkstra's Algorithm
│   ├─ Safety-first cost function
│   ├─ Hybrid online/offline
│   ├─ Backend API integration
│   ├─ Offline fallback
│   └─ Cached data usage
│
├─► 🚨 Safety Features
│   ├─ High-risk detection
│   ├─ Automatic rerouting
│   ├─ Deviation detection
│   ├─ Risk warnings
│   ├─ Haptic feedback
│   └─ Visual alerts
│
├─► 🗺️ Map Display
│   ├─ Full-screen flutter_map
│   ├─ Route polyline (blue)
│   ├─ User marker (blue circle)
│   ├─ Destination marker (green)
│   ├─ Camera following
│   └─ Smooth animations
│
├─► 📊 UI Components
│   ├─ Top Panel
│   │   ├─ Turn icon
│   │   ├─ Instruction text
│   │   ├─ Distance to turn
│   │   └─ ETA + total distance
│   ├─ Warning Banners
│   │   ├─ High-risk (red)
│   │   └─ Rerouting (orange)
│   └─ Bottom Panel
│       ├─ Cancel button
│       └─ Voice toggle
│
├─► 💾 Offline Support
│   ├─ Cached road graph
│   ├─ Cached hazard data
│   ├─ Local route calculation
│   ├─ Map tile caching
│   └─ No internet required
│
└─► 🔐 Role-Based Access
    ├─ Resident: Full access
    └─ Admin: No access (separate map)
```

---

## Technology Stack Visualization

```
┌──────────────────────────────────────────────────────────────────┐
│                      TECHNOLOGY STACK                             │
└──────────────────────────────────────────────────────────────────┘

PRESENTATION LAYER (UI)
  ├─► Flutter Framework
  ├─► Material Design
  ├─► flutter_map (Map display)
  ├─► StatefulWidget (State management)
  └─► Navigator (Screen routing)

BUSINESS LOGIC LAYER (Services)
  ├─► GPSTrackingService
  │     └─► geolocator: ^12.0.0
  │
  ├─► VoiceGuidanceService
  │     └─► flutter_tts: ^4.2.5
  │
  ├─► RiskAwareRoutingService
  │     ├─► dio: ^5.4.0 (HTTP)
  │     └─► collection: ^1.19.0
  │
  └─► OfflineRoutingService
        └─► Modified Dijkstra implementation

DATA LAYER (Models & Storage)
  ├─► Models
  │     ├─► NavigationStep
  │     ├─► RouteSegment
  │     └─► NavigationRoute
  │
  └─► Storage
        ├─► Hive (Offline cache)
        ├─► SharedPreferences
        └─► Path Provider

EXTERNAL SERVICES
  ├─► OpenStreetMap (Map tiles)
  ├─► Django Backend API (Production)
  ├─► OSRM (Route geometry)
  └─► Device GPS (Location)

PLATFORM LAYER
  ├─► Android
  └─► iOS (future)
```

This comprehensive architecture documentation provides a complete visual understanding of the Live Turn-by-Turn Navigation system implementation.
