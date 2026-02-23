# 🏗️ Backend Folder Structure & Algorithms Guide

**For: Someone with Little Programming Knowledge**

---

## 📚 Table of Contents
1. [Backend Folder Structure Overview](#backend-folder-structure)
2. [What Each Folder Does](#folder-by-folder-guide)
3. [The 4 AI Algorithms Explained](#the-4-algorithms)
4. [How Algorithms Work Together](#how-they-work-together)
5. [Where Everything Is Located](#file-locations)

---

## 🗂️ Backend Folder Structure

### **Main Structure (Simplified View):**

```
backend/
├── manage.py                    ← Django command tool
├── config/                      ← Project settings
│   ├── settings.py             ← Database, apps config
│   ├── urls.py                 ← Main URL routing
│   └── wsgi.py                 ← Server configuration
│
├── apps/                        ← Feature modules
│   ├── users/                  ← User accounts
│   ├── evacuation/             ← Evacuation centers
│   ├── hazards/                ← Hazard reports
│   ├── routing/                ← Route calculation
│   │   └── services/
│   │       └── dijkstra.py     ← 🔴 ALGORITHM 4: Modified Dijkstra
│   ├── validation/             ← Report validation
│   │   └── services/
│   │       ├── naive_bayes.py  ← 🔴 ALGORITHM 1: Naive Bayes
│   │       └── consensus.py    ← 🔴 ALGORITHM 2: Consensus
│   ├── risk_prediction/        ← Road risk
│   │   └── services/
│   │       └── random_forest.py ← 🔴 ALGORITHM 3: Random Forest
│   └── mobile_sync/            ← Mobile app API
│
├── core/                        ← Shared utilities
│   ├── utils/                  ← Helper functions
│   │   └── geo.py              ← GPS calculations
│   └── permissions/            ← Access control
│
├── mock_data/                   ← Training data
│   └── mock_training_data.json ← Sample data for AI
│
└── db.sqlite3                   ← Database file (when created)
```

---

## 📁 Folder-by-Folder Guide

### **1. `config/` - Project Configuration**

**What it does:** Core Django settings and URL routing

**Important files:**

#### **`settings.py`**
- Database configuration
- Installed apps list
- Security settings
- API configuration

```python
# Example from settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',  # Database type
        'NAME': BASE_DIR / 'db.sqlite3',         # Database file
    }
}
```

**Think of it as:** The control panel for the entire backend

---

#### **`urls.py`**
- Defines all API endpoints
- Routes requests to correct app

```python
# Example: URL mapping
urlpatterns = [
    path('api/evacuation-centers/', include('apps.evacuation.urls')),
    path('api/hazards/', include('apps.hazards.urls')),
    path('api/routing/', include('apps.routing.urls')),
]
```

**Think of it as:** The table of contents directing requests

---

### **2. `apps/` - Feature Modules**

Each folder in `apps/` is a **separate feature** of your system.

#### **`apps/users/` - User Management**
- User accounts (residents, MDRRMO)
- Authentication (login/register)
- User profiles

**Files:**
- `models.py` - Database structure for users
- `views.py` - Login/register logic
- `serializers.py` - Data validation

---

#### **`apps/evacuation/` - Evacuation Centers**
- Stores evacuation center data
- API for listing centers
- MDRRMO can add/edit centers

**Files:**
- `models.py` - EvacuationCenter database table
- `views.py` - API endpoints for centers
- `urls.py` - Routes like `/api/evacuation-centers/`

---

#### **`apps/hazards/` - Hazard Reports**
- Stores resident reports
- Tracks status (pending/approved/rejected)
- Stores AI validation scores

**Files:**
- `models.py` - HazardReport database table
- `views.py` - Submit report, get reports
- `serializers.py` - Validate report data

---

#### **`apps/routing/` - Route Calculation**
- 🔴 **CONTAINS ALGORITHM 4: Modified Dijkstra**
- Calculates safest routes
- Stores road segment data

**Important file:**
```
apps/routing/services/dijkstra.py  ← ALGORITHM HERE!
```

---

#### **`apps/validation/` - Report Validation**
- 🔴 **CONTAINS ALGORITHMS 1 & 2**
- Validates if reports are real or fake
- Increases confidence with multiple reports

**Important files:**
```
apps/validation/services/naive_bayes.py  ← ALGORITHM 1
apps/validation/services/consensus.py    ← ALGORITHM 2
```

---

#### **`apps/risk_prediction/` - Road Risk**
- 🔴 **CONTAINS ALGORITHM 3: Random Forest**
- Predicts which roads are dangerous
- Uses historical hazard data

**Important file:**
```
apps/risk_prediction/services/random_forest.py  ← ALGORITHM 3
```

---

#### **`apps/mobile_sync/` - Mobile App API**
- Endpoints for mobile app
- Bootstrap data sync
- Offline queue handling

**Files:**
- `views.py` - API endpoints
- `services/` - Business logic
  - `bootstrap_service.py` - Initial data load
  - `route_service.py` - Route calculation
  - `report_service.py` - Report handling

---

### **3. `core/` - Shared Utilities**

**What it does:** Helper functions used by multiple apps

#### **`core/utils/geo.py`**
- GPS distance calculation
- Check if point is within radius
- Geographic math functions

```python
# Example function
def within_radius(lat1, lng1, lat2, lng2, radius_m):
    """Check if two GPS points are within radius in meters"""
    distance = haversine_distance(lat1, lng1, lat2, lng2)
    return distance <= radius_m
```

---

### **4. `mock_data/` - Training Data**

**What it does:** Stores sample data for training AI algorithms

#### **`mock_training_data.json`**
- Sample hazard reports (real vs fake)
- Road risk training data
- Used to train the 3 ML models

**Example structure:**
```json
{
  "naive_bayes_training": [
    {
      "hazard_type": "flooded_road",
      "description_length": 45,
      "valid": true
    },
    {
      "hazard_type": "unknown",
      "description_length": 5,
      "valid": false
    }
  ],
  "road_risk_training": [
    {
      "segment_id": "seg_001",
      "nearby_hazard_count": 3,
      "avg_severity": 0.7,
      "risk_score": 0.8
    }
  ]
}
```

**TO REPLACE:** When you get real MDRRMO data, replace this file with real historical data!

---

## 🤖 The 4 Algorithms Explained

### **ALGORITHM 1: Naive Bayes Classifier** 🔵

**Location:** `apps/validation/services/naive_bayes.py`

**Purpose:** Validate if a hazard report is REAL or FAKE

**How it works (Simple explanation):**

Imagine you're a detective. You want to know if a report is real or fake by looking at clues:

```
Clue 1: What type of hazard? (flooded_road, landslide, etc.)
Clue 2: How long is the description? (short, medium, long)

Based on PAST reports you know are real/fake, you learn patterns:
- Real reports usually have medium/long descriptions
- Fake reports usually have very short descriptions
- Flooded road reports are more common (more likely real)
- "Unknown" hazard types are suspicious (more likely fake)
```

**The Math (Simplified):**

```
P(Real | Clues) = P(Real) × P(Clues | Real) / P(All possibilities)

Example:
Report: "Flooded road, 45 characters"

Step 1: Check history
  - 70% of past reports were real
  - 80% of "flooded_road" reports were real
  - 85% of medium-length descriptions were real

Step 2: Calculate
  - Probability this is real = 0.7 × 0.8 × 0.85 = 0.476
  - Probability this is fake = 0.3 × 0.2 × 0.15 = 0.009
  
Step 3: Final score
  - Real score = 0.476 / (0.476 + 0.009) = 0.98 (98% confident it's real!)
```

**Code structure:**

```python
class NaiveBayesValidator:
    def __init__(self):
        # Initialize empty model
        self._trained = False
    
    def train(self, training_data):
        """Learn from past reports (real vs fake)"""
        # Count how many reports of each type were real/fake
        # Calculate probabilities
        self._trained = True
    
    def validate_report(self, report_data):
        """Score a new report (0.0 to 1.0)"""
        # Extract features: hazard_type, description_length
        # Calculate probability it's real
        # Return score (e.g., 0.92 = 92% confident it's real)
        return score
```

**Input:**
```python
{
  "hazard_type": "flooded_road",
  "description": "Severe flooding on main highway near market"
}
```

**Output:**
```python
0.92  # 92% confidence this report is real
```

---

### **ALGORITHM 2: Consensus Scoring** 🟢

**Location:** `apps/validation/services/consensus.py`

**Purpose:** Increase confidence when MULTIPLE people report the same hazard

**How it works (Simple explanation):**

```
Scenario 1: One person reports flooding
  → Confidence: Medium (maybe true, maybe false)

Scenario 2: Five people report flooding in same area
  → Confidence: Very High (probably true!)

Think of it like: When multiple witnesses report the same crime,
police trust it more than a single report.
```

**The Logic:**

```
1. New report comes in at GPS: (12.6700, 123.8755)

2. Check: How many OTHER reports are within 50 meters?
   - Found 3 other reports nearby
   
3. Boost the confidence:
   - Each nearby report adds +10% confidence (max +30%)
   - Base confidence from Naive Bayes: 70%
   - Consensus boost: +30%
   - Final confidence: 85%
```

**Code structure:**

```python
class ConsensusScoringService:
    def __init__(self, radius_m=50):
        self.radius_m = radius_m  # 50 meters
    
    def count_nearby_reports(self, lat, lng, all_reports):
        """Count reports within 50m of this location"""
        count = 0
        for report in all_reports:
            if distance_between(lat, lng, report.lat, report.lng) <= 50:
                count += 1
        return count
    
    def combined_score(self, naive_bayes_score, nearby_count):
        """Combine NB score with consensus boost"""
        # nearby_count = 3 → boost = 0.3
        # nearby_count = 5 → boost = 0.3 (capped)
        boost = min(0.3, nearby_count * 0.1)
        
        # Weight: 70% Naive Bayes + 30% Consensus
        final = 0.7 * naive_bayes_score + 0.3 * (0.5 + boost)
        return final
```

**Example:**

```
Report A: "Flooding at (12.6700, 123.8755)"
  - Naive Bayes: 70%
  - Nearby reports: 0
  - Final: 70%

Report B: "Flooding at (12.6702, 123.8756)" (30m from A)
  - Naive Bayes: 75%
  - Nearby reports: 1 (Report A)
  - Final: 0.7 × 0.75 + 0.3 × 0.6 = 70.5%

Report C: "Flooding at (12.6701, 123.8757)" (20m from A&B)
  - Naive Bayes: 80%
  - Nearby reports: 2 (A and B)
  - Final: 0.7 × 0.80 + 0.3 × 0.7 = 77%
```

---

### **ALGORITHM 3: Random Forest (Road Risk Prediction)** 🟡

**Location:** `apps/risk_prediction/services/random_forest.py`

**Purpose:** Predict which roads are DANGEROUS based on historical hazards

**How it works (Simple explanation):**

```
Think of it like weather prediction:
- If a road had 5 flooding incidents in the past
- And average severity was high
- Then: This road is HIGH RISK for flooding again

Random Forest = Multiple "decision trees" voting together
```

**Decision Tree Example (One tree out of many):**

```
Is nearby_hazard_count > 3?
├─ YES → Is avg_severity > 0.5?
│        ├─ YES → HIGH RISK (0.8)
│        └─ NO  → MEDIUM RISK (0.5)
└─ NO  → Is avg_severity > 0.7?
         ├─ YES → MEDIUM RISK (0.4)
         └─ NO  → LOW RISK (0.2)

Random Forest = Run 10 trees, average their predictions
```

**Code structure:**

```python
class RoadRiskPredictor:
    def __init__(self):
        self._model = None  # Will be RandomForestRegressor
        self._trained = False
    
    def train(self, training_data):
        """Learn from historical road hazards"""
        # Extract features: nearby_hazard_count, avg_severity
        # Extract label: risk_score
        # Train Random Forest with 10 trees
        self._model = RandomForestRegressor(n_estimators=10)
        self._model.fit(X, y)
        self._trained = True
    
    def predict_risk(self, nearby_hazard_count, avg_severity):
        """Predict risk for a road segment"""
        # Input features to trained model
        # Get prediction (0.0 to 1.0)
        return predicted_risk
```

**Example:**

```
Road Segment #1:
  - Location: Main Highway near market
  - Historical data:
    - 5 flood incidents in past year
    - Average severity: 0.7 (high)
  
Algorithm predicts:
  - Risk score: 0.82 (HIGH RISK - Red)

Road Segment #2:
  - Location: Elevated road on hill
  - Historical data:
    - 1 minor incident
    - Average severity: 0.2 (low)
  
Algorithm predicts:
  - Risk score: 0.15 (LOW RISK - Green)
```

---

### **ALGORITHM 4: Modified Dijkstra** 🔴

**Location:** `apps/routing/services/dijkstra.py`

**Purpose:** Calculate the SAFEST route (not just shortest!)

**How it works (Simple explanation):**

**Normal Dijkstra (like Google Maps):**
- Finds shortest distance route
- Only cares about: How many kilometers?

**Modified Dijkstra (our algorithm):**
- Finds safest route
- Cares about: Distance + Risk

```
Route A: 3 km, but passes through high-risk flooded area
  Weight = 3 km + (0.8 risk × 500) = 403

Route B: 5 km, but all safe roads
  Weight = 5 km + (0.1 risk × 500) = 55

Algorithm chooses: Route B (safer, even though longer!)
```

**The Math:**

```
Weight = Distance + (Risk Score × Risk Multiplier)

Risk Multiplier = 500 (makes risk very important)

Example:
  Route through flooded road:
    - Distance: 2 km
    - Risk: 0.9 (very high)
    - Weight = 2 + (0.9 × 500) = 452

  Route through safe road:
    - Distance: 4 km
    - Risk: 0.1 (very low)
    - Weight = 4 + (0.1 × 500) = 54
    
  Winner: Safe road (lower weight = better)
```

**Code structure:**

```python
class ModifiedDijkstraService:
    def __init__(self, risk_multiplier=500):
        self.risk_multiplier = 500  # How much to penalize risk
    
    def build_graph(self, road_segments):
        """Convert road segments to graph"""
        # Each road segment is an edge
        # Weight = distance + (risk × 500)
        return graph
    
    def dijkstra_k_routes(self, graph, start, end, k=3):
        """Find k safest routes"""
        # Use priority queue (heap)
        # Always process lowest weight first
        # Build path from start to end
        # Return 3 safest routes
        return routes
    
    def _risk_level(self, total_risk):
        """Classify route as Green/Yellow/Red"""
        if total_risk < 0.3:
            return 'Green'  # Safe
        elif total_risk < 0.7:
            return 'Yellow'  # Caution
        else:
            return 'Red'  # Dangerous
```

**Visual Example:**

```
Start: Your Location (12.6699, 123.8758)
End: Evacuation Center (12.6720, 123.8770)

Road Network:
  A ──(2km, risk:0.2)──> B ──(1km, risk:0.1)──> End
  │                                              ↑
  └────────(1.5km, risk:0.9)───────────────────┘

Calculation:
  Route 1 (A → B → End):
    - Distance: 2 + 1 = 3 km
    - Risk: 0.2 + 0.1 = 0.3
    - Weight: 3 + (0.3 × 500) = 153
  
  Route 2 (A → End):
    - Distance: 1.5 km
    - Risk: 0.9
    - Weight: 1.5 + (0.9 × 500) = 451.5
  
Winner: Route 1 (safer even though longer!)
Risk Level: Green (total risk 0.3 < 0.3 threshold)
```

---

## 🔄 How the 4 Algorithms Work Together

### **Complete Flow:**

```
┌──────────────────────────────────────────────────────────┐
│ 1. Resident submits hazard report                       │
│    "Flooding on Main Street"                            │
└────────────────┬─────────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────────┐
│ 2. ALGORITHM 1: Naive Bayes                             │
│    Validates report authenticity                         │
│    Output: 85% confident it's real                      │
└────────────────┬─────────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────────┐
│ 3. ALGORITHM 2: Consensus                                │
│    Checks for nearby reports                             │
│    Found: 2 other reports within 50m                     │
│    Output: Boosts confidence to 90%                      │
└────────────────┬─────────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────────┐
│ 4. Report approved by MDRRMO                             │
│    Becomes "Verified Hazard"                            │
│    Added to historical database                          │
└────────────────┬─────────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────────┐
│ 5. ALGORITHM 3: Random Forest                            │
│    Recalculates road risk scores                         │
│    Main Street segment: 0.3 → 0.8 (HIGH RISK)          │
└────────────────┬─────────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────────┐
│ 6. User requests route to evacuation center             │
└────────────────┬─────────────────────────────────────────┘
                 ↓
┌──────────────────────────────────────────────────────────┐
│ 7. ALGORITHM 4: Modified Dijkstra                        │
│    Calculates safest routes                              │
│    Avoids Main Street (high risk)                        │
│    Suggests: Alternative road (3km, GREEN)              │
└──────────────────────────────────────────────────────────┘
```

---

### **Detailed Interaction:**

**Phase 1: Report Validation**
```
New Report → Naive Bayes → Consensus → Final Score → MDRRMO Decision
                ↓             ↓
            Pattern     Multiple Reports
            Matching    in Same Area
```

**Phase 2: Risk Update**
```
Approved Reports → Random Forest → Road Segment Risk Scores
                        ↓
                    Predicts which
                    roads are dangerous
```

**Phase 3: Route Calculation**
```
User Request → Modified Dijkstra → Risk-Weighted Routes
                    ↓
                Uses road risk scores
                from Random Forest
```

---

## 📂 Complete File Locations

### **Algorithm Files:**

| Algorithm | Location | Line Count |
|-----------|----------|------------|
| **Naive Bayes** | `apps/validation/services/naive_bayes.py` | 121 lines |
| **Consensus** | `apps/validation/services/consensus.py` | 61 lines |
| **Random Forest** | `apps/risk_prediction/services/random_forest.py` | 85 lines |
| **Modified Dijkstra** | `apps/routing/services/dijkstra.py` | 188 lines |

---

### **Database Models (Data Structure):**

| Model | Location | What It Stores |
|-------|----------|----------------|
| User | `apps/users/models.py` | User accounts |
| EvacuationCenter | `apps/evacuation/models.py` | Centers data |
| HazardReport | `apps/hazards/models.py` | Reports from residents |
| BaselineHazard | `apps/hazards/models.py` | Historical MDRRMO data |
| RoadSegment | `apps/routing/models.py` | Road network graph |

---

### **API Endpoints (Views):**

| Feature | Location | Endpoints |
|---------|----------|-----------|
| Evacuation Centers | `apps/evacuation/views.py` | GET /api/evacuation-centers/ |
| Submit Report | `apps/hazards/views.py` | POST /api/hazards/ |
| Calculate Route | `apps/routing/views.py` | POST /api/calculate-route/ |
| Bootstrap Sync | `apps/mobile_sync/views.py` | GET /api/bootstrap-sync/ |

---

## 🔧 How to Use the Algorithms

### **1. Training the Models**

When you get **real MDRRMO data**, you need to train the 3 ML algorithms:

```bash
# Navigate to backend folder
cd backend

# Option 1: Train all models
python manage.py shell

>>> from apps.validation.services.naive_bayes import NaiveBayesValidator
>>> from apps.risk_prediction.services.random_forest import RoadRiskPredictor

>>> # Load real MDRRMO data (CSV/Excel)
>>> real_data = load_mdrrmo_historical_data()

>>> # Train Naive Bayes
>>> nb = NaiveBayesValidator()
>>> nb.train(real_data)

>>> # Train Random Forest
>>> rf = RoadRiskPredictor()
>>> rf.train(real_data)
```

---

### **2. Using the Algorithms**

The algorithms are automatically used when:

**Naive Bayes & Consensus:**
- User submits report
- Backend validates it
- Stores scores in database

**Random Forest:**
- Periodically recalculate road risks
- When new hazards are verified
- Update RoadSegment table

**Modified Dijkstra:**
- User requests route
- Backend calculates safest path
- Returns 3 routes (Green/Yellow/Red)

---

## 🎓 Summary

### **Backend Structure:**
```
backend/
├── config/           → Django settings
├── apps/             → Feature modules
│   ├── validation/   → Algorithms 1 & 2
│   ├── risk_prediction/ → Algorithm 3
│   └── routing/      → Algorithm 4
├── core/             → Utilities
└── mock_data/        → Training data
```

### **The 4 Algorithms:**

1. **Naive Bayes** (Validation)
   - Detects fake reports
   - Uses: hazard type, description length
   - Output: Confidence score (0-1)

2. **Consensus** (Crowd Validation)
   - Counts nearby reports
   - Boosts confidence with multiple witnesses
   - Output: Combined score

3. **Random Forest** (Risk Prediction)
   - Predicts dangerous roads
   - Uses: Historical hazards
   - Output: Road risk score (0-1)

4. **Modified Dijkstra** (Routing)
   - Finds safest route
   - Weight = Distance + Risk
   - Output: 3 routes (Green/Yellow/Red)

---

## 💡 Key Points to Remember

✅ All 4 algorithms are **already implemented** in the backend  
✅ Currently use **mock training data** (fake historical data)  
✅ When you get **real MDRRMO data**, replace training data  
✅ Algorithms **work together** (output of one feeds into another)  
✅ **Backend is NOT running** yet, but code is ready  

---

## 📚 Want to Learn More?

**Read these files in order:**
1. `naive_bayes.py` - Simplest algorithm
2. `consensus.py` - Simple counting
3. `random_forest.py` - ML prediction
4. `dijkstra.py` - Most complex (graph algorithm)

**Each file has:**
- Comments explaining the logic
- Simple Python code
- Example usage

You don't need to understand the code deeply - just know **what each algorithm does** and **where to find it**! 📖

---

**Questions?** The algorithms are math-heavy but the **concept is simple**: Use past data to predict future risks and validate reports! 🧠
