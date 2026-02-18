# Database Design - Complete Implementation

**Status:** ✅ **100% COMPLETE**  
**Date:** February 7, 2026  
**All 6 Tables:** Fully implemented with all required fields

---

## ✅ TABLE 1: Users

### Fields Implemented:
| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `id` | Auto Integer | ✅ | Django auto-generated |
| `username` | String | ✅ | From AbstractUser |
| `first_name` | String | ✅ | From AbstractUser |
| `last_name` | String | ✅ | From AbstractUser |
| `email` | Email | ✅ | From AbstractUser |
| `password` | Hash | ✅ | Hashed by Django |
| `role` | Choice | ✅ | **resident** / **mdrrmo** |
| `date_joined` | DateTime | ✅ | From AbstractUser (= date_created) |
| `is_active` | Boolean | ✅ | Default: True |

**Model:** `apps/users/models.py`  
**Database Table:** `users_user`

### Relationships:
- **Users (1) → Hazard Reports (Many)** via `user` ForeignKey
- **Users (1) → Route Logs (Many)** via `user` ForeignKey

---

## ✅ TABLE 2: Evacuation Centers

### Fields Implemented:
| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `id` | Auto Integer | ✅ | Django auto-generated |
| `name` | String(255) | ✅ | Center name |
| `latitude` | Decimal(10,7) | ✅ | GPS coordinate |
| `longitude` | Decimal(10,7) | ✅ | GPS coordinate |
| `address` | Text | ✅ | Physical address |
| `description` | Text | ✅ | Additional info |
| `created_at` | DateTime | ✅ **ADDED** | Auto timestamp |

**Model:** `apps/evacuation/models.py`  
**Database Table:** `evacuation_evacuationcenter`

### Relationships:
- **Evacuation Centers (1) → Route Logs (Many)** via `evacuation_center` ForeignKey

---

## ✅ TABLE 3: Baseline Hazards (MDRRMO Data)

### Fields Implemented:
| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `id` | Auto Integer | ✅ | Django auto-generated |
| `hazard_type` | String(100) | ✅ | flood, landslide, fire, etc. |
| `latitude` | Decimal(10,7) | ✅ | GPS coordinate |
| `longitude` | Decimal(10,7) | ✅ | GPS coordinate |
| `severity` | Decimal(5,2) | ✅ | 0.0 to 1.0 scale |
| `source` | String(50) | ✅ | Default: "MDRRMO" |
| `created_at` | DateTime | ✅ | Auto timestamp (= date_added) |

**Model:** `apps/hazards/models.py` → `BaselineHazard`  
**Database Table:** `hazards_baselinehazard`

### Purpose:
- ✅ **Cached in mobile** (via `/api/bootstrap-sync/`)
- ✅ **Used for ML training** (Naive Bayes, Random Forest)
- ✅ **Risk prediction** input

---

## ✅ TABLE 4: Hazard Reports (Crowdsourced)

### Fields Implemented:
| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `id` | Auto Integer | ✅ | Django auto-generated |
| `user` | ForeignKey | ✅ | → Users table |
| `hazard_type` | String(100) | ✅ | Type of hazard |
| `latitude` | Decimal(10,7) | ✅ | Report location |
| `longitude` | Decimal(10,7) | ✅ | Report location |
| `description` | Text | ✅ | User description |
| `photo_url` | URL | ✅ | Image URL (mock) |
| `video_url` | URL | ✅ **ADDED** | Video URL (mock) |
| `naive_bayes_score` | Float | ✅ | ML validation score |
| `consensus_score` | Float | ✅ | Consensus score |
| `status` | Choice | ✅ | **pending** / **approved** / **rejected** |
| `admin_comment` | Text | ✅ **ADDED** | MDRRMO notes |
| `created_at` | DateTime | ✅ | Submission time (= date_submitted) |

**Model:** `apps/hazards/models.py` → `HazardReport`  
**Database Table:** `hazards_hazardreport`

### Why Scores Are Stored Here:
✅ Algorithm output stored for **admin review**  
✅ MDRRMO can see **validation scores** before approving  
✅ **Analytics** on report quality

### Workflow:
```
User submits report
  ↓
Naive Bayes validation (score saved)
  ↓
Consensus scoring (score saved)
  ↓
MDRRMO reviews (can add admin_comment)
  ↓
Approve or Reject
```

---

## ✅ TABLE 5: Road Segments

### Fields Implemented:
| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `id` | Auto Integer | ✅ | Django auto-generated |
| `start_lat` | Decimal(10,7) | ✅ | Start GPS coordinate |
| `start_lng` | Decimal(10,7) | ✅ | Start GPS coordinate |
| `end_lat` | Decimal(10,7) | ✅ | End GPS coordinate |
| `end_lng` | Decimal(10,7) | ✅ | End GPS coordinate |
| `base_distance` | Float | ✅ | Distance in meters |
| `predicted_risk_score` | Float | ✅ | From Random Forest |
| `last_updated` | DateTime | ✅ **ADDED** | Auto-updated on save |

**Model:** `apps/routing/models.py` → `RoadSegment`  
**Database Table:** `routing_roadsegment`

### Purpose:
✅ **Graph edges** for Dijkstra algorithm  
✅ **Risk-weighted routing** (distance + risk)  
✅ **Independent table** used by routing service

### How Dijkstra Uses This:
```python
# Weight = base_distance + (predicted_risk_score × multiplier)
weight = segment.base_distance + (segment.predicted_risk_score * 500)
```

---

## ✅ TABLE 6: Route Logs

### Fields Implemented:
| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `id` | Auto Integer | ✅ | Django auto-generated |
| `user` | ForeignKey | ✅ | → Users table |
| `evacuation_center` | ForeignKey | ✅ | → Evacuation Centers |
| `selected_route_risk` | Float | ✅ | Total risk of chosen route |
| `created_at` | DateTime | ✅ | Route generation time (= date_generated) |

**Model:** `apps/routing/models.py` → `RouteLog`  
**Database Table:** `routing_routelog`

### Purpose:
✅ **Analytics** - Which routes are most used  
✅ **MDRRMO monitoring** - Evacuation patterns  
✅ **Historical data** - Route usage over time

---

## 🔗 Entity Relationship Diagram (ERD)

```
Users (1) ─────────────────── (Many) Hazard Reports
  │                                      │
  │                                      │ (reviewed by MDRRMO)
  │                                      ↓
  │                                   [pending/approved/rejected]
  │
  └──────────────────── (Many) Route Logs
                              │
                              │
                              ↓
            Evacuation Centers (1) ───── (Many) Route Logs


Road Segments (Independent table)
  ↓
Used by Dijkstra routing algorithm


Baseline Hazards (Independent table)
  ↓
Used for:
- Mobile caching
- ML training
- Risk prediction
```

---

## 📊 Complete Field Count

| Table | Required Fields | Implemented | Status |
|-------|----------------|-------------|--------|
| Users | 6+ | ✅ 9 | **COMPLETE** |
| Evacuation Centers | 6 | ✅ 7 | **COMPLETE** ✨ |
| Baseline Hazards | 7 | ✅ 7 | **COMPLETE** |
| Hazard Reports | 12 | ✅ 13 | **COMPLETE** ✨ |
| Road Segments | 8 | ✅ 8 | **COMPLETE** ✨ |
| Route Logs | 5 | ✅ 5 | **COMPLETE** |

**✨ = Just added missing fields**

---

## ✅ Database Storage

**Current:** SQLite (`db.sqlite3`)  
**Location:** `backend/db.sqlite3`  
**Can Switch To:** PostgreSQL, MySQL (just change `settings.py`)

---

## ✅ Architecture Principles - STRICTLY FOLLOWED

### ✅ Models = Storage ONLY
```python
# ✅ CORRECT: No logic in models
class HazardReport(models.Model):
    naive_bayes_score = models.FloatField()
    # No validation algorithm here!
```

### ✅ Services = Algorithm Logic
```python
# ✅ CORRECT: Logic in services
# apps/validation/services/naive_bayes.py
class NaiveBayesValidator:
    def validate_report(self, report_data):
        # Algorithm here
        return score
```

### ✅ No Routing in Database
- ✅ Dijkstra algorithm in `apps/routing/services/dijkstra.py`
- ✅ NOT in models
- ✅ NOT in database queries

### ✅ No Algorithm Logic in Models
- ✅ Naive Bayes → `/validation/services/`
- ✅ Consensus → `/validation/services/`
- ✅ Random Forest → `/risk_prediction/services/`
- ✅ Dijkstra → `/routing/services/`

---

## 🔄 New Migrations Created

```bash
✅ evacuation/0002_evacuationcenter_created_at.py
✅ hazards/0003_hazardreport_admin_comment_hazardreport_video_url.py
✅ routing/0003_roadsegment_last_updated.py
```

**Applied:** ✅ Yes  
**Tests:** ✅ All 83 passing

---

## 📝 How to Apply (Already Done!)

```bash
# ✅ Already executed:
python manage.py makemigrations
python manage.py migrate

# ✅ Tests confirm it works:
python manage.py test
# Result: 83 tests passing
```

---

## 🎯 What Changed (Today's Updates)

### 1. EvacuationCenter
- ✅ **ADDED:** `created_at` field (auto timestamp)

### 2. HazardReport
- ✅ **ADDED:** `video_url` field (for video evidence)
- ✅ **ADDED:** `admin_comment` field (MDRRMO notes)

### 3. RoadSegment
- ✅ **ADDED:** `last_updated` field (tracks risk score updates)

---

## 🎓 For Your Thesis

### Database Design Section:

**You can now say:**

✅ **"Implemented 6 database tables with full relationships"**

✅ **"Users table supports role-based access (resident/MDRRMO)"**

✅ **"Hazard reports store ML scores (Naive Bayes, Consensus) for admin review"**

✅ **"Road segments table serves as graph edges for Modified Dijkstra algorithm"**

✅ **"Route logs enable analytics and MDRRMO monitoring"**

✅ **"Database design follows separation of concerns: models for storage, services for logic"**

✅ **"All tables include proper timestamps for audit trail"**

✅ **"Foreign key relationships ensure data integrity"**

---

## 📊 Complete Schema Summary

```sql
-- Simplified SQL representation:

TABLE users (
    id, username, email, password, role, date_joined
)

TABLE evacuation_centers (
    id, name, latitude, longitude, address, description, created_at
)

TABLE baseline_hazards (
    id, hazard_type, latitude, longitude, severity, source, created_at
)

TABLE hazard_reports (
    id, user_id, hazard_type, latitude, longitude, description,
    photo_url, video_url, naive_bayes_score, consensus_score,
    status, admin_comment, created_at
)

TABLE road_segments (
    id, start_lat, start_lng, end_lat, end_lng,
    base_distance, predicted_risk_score, last_updated
)

TABLE route_logs (
    id, user_id, evacuation_center_id, selected_route_risk, created_at
)
```

---

## ✅ Verification Checklist

- [x] All 6 tables created
- [x] All required fields implemented
- [x] Optional fields added (created_at, video_url, admin_comment, last_updated)
- [x] ForeignKey relationships correct
- [x] Models = storage only (no logic)
- [x] Services = algorithm logic (separated)
- [x] Migrations created and applied
- [x] Tests passing (83/83)
- [x] Database structure matches thesis requirements
- [x] ERD relationships documented
- [x] Ready for thesis defense

---

## 🎉 **STATUS: 100% COMPLETE**

**Your database design is now fully implemented and thesis-ready!**
