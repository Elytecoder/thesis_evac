# ML Implementation: Naive Bayes & Random Forest

Complete reference for the machine learning pipeline — from synthetic training data to live predictions — for the AI-Powered Mobile Evacuation Routing Application.

> **Status:** Fully implemented and tested. Using synthetic training data (temporary).  
> Replace `ml_data/naive_bayes_dataset.csv` and `ml_data/random_forest_dataset.csv` with real MDRRMO historical data when available, then run `python manage.py train_ml_models --force`.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Directory Structure](#directory-structure)
3. [Naive Bayes — Report Validation](#naive-bayes--report-validation)
4. [Random Forest — Road Risk Prediction](#random-forest--road-risk-prediction)
5. [ML Service Architecture](#ml-service-architecture)
6. [Validation Scoring Formula](#validation-scoring-formula)
7. [Road Segment Risk Computation](#road-segment-risk-computation)
8. [Management Commands](#management-commands)
9. [How to Replace with Real Data](#how-to-replace-with-real-data)
10. [What Has Changed (Summary of Improvements)](#what-has-changed-summary-of-improvements)

---

## System Overview

```
Resident submits hazard report
  → Proximity gate (150 m rule)          ← auto-reject if > 150 m from hazard
  → Naive Bayes scoring                  ← P(valid | hazard_type + description)
  → Rule-based scoring                   ← distance_weight + consensus_score
  → final_validation_score               ← weighted blend of all three
  → Status: PENDING
  → MDRRMO reviews + approves or rejects

Approved hazard reports
  → Displayed on resident map
  → Feed into road segment risk (RF)
  → Modified Dijkstra routing (top 3 safest routes)

Road segment risk (at route time or after update_segment_risks):
  → per-segment hazard counts from approved reports
  → Random Forest → predicted_risk_score
  → calculate_segment_risk() blends base (RF × 0.6) + dynamic (live hazards × 0.4)
```

**AI assists, not decides.** MDRRMO always makes the final approve/reject call.

---

## Directory Structure

```
backend/
├── ml_data/
│   ├── __init__.py
│   ├── ml_service.py               ← singleton: loads pkl models, exposes predictions
│   ├── train_naive_bayes.py        ← dataset + CountVectorizer + MultinomialNB training
│   ├── train_random_forest.py      ← dataset + RandomForestRegressor training
│   ├── naive_bayes_dataset.csv     ← 201-row synthetic dataset (generated on first train)
│   ├── random_forest_dataset.csv   ← 300-row synthetic dataset (generated on first train)
│   └── models/
│       ├── naive_bayes_model.pkl   ← trained MultinomialNB
│       ├── vectorizer.pkl          ← fitted CountVectorizer
│       └── random_forest_model.pkl ← trained RandomForestRegressor
├── apps/
│   ├── validation/services/
│   │   ├── naive_bayes.py          ← NaiveBayesValidator (calls ml_service, fallback classic)
│   │   ├── rule_scoring.py         ← distance_weight, consensus_rule_score, combine_validation_scores
│   │   └── consensus.py            ← ConsensusScoringService (count_nearby_reports)
│   ├── risk_prediction/services/
│   │   └── random_forest.py        ← RoadRiskPredictor (calls ml_service)
│   └── mobile_sync/
│       ├── services/
│       │   ├── report_service.py   ← orchestrates NB + rules + stores validation breakdown
│       │   └── route_service.py    ← _compute_segment_rf_features, _ensure_segment_risk_scores
│       └── management/commands/
│           ├── train_ml_models.py  ← python manage.py train_ml_models
│           └── update_segment_risks.py ← python manage.py update_segment_risks
```

---

## Naive Bayes — Report Validation

### Purpose

Estimate the **credibility of a hazard report** based on its text content alone.  
`naive_bayes_score` = P(valid | hazard_type, description)

### How it works

1. **Text input** is constructed by combining `hazard_type` and `description`:
   ```python
   text = f"{hazard_type} {description}"
   ```

2. **CountVectorizer** (bigrams, `ngram_range=(1,2)`) converts text to word-count vectors.

3. **MultinomialNB** (`alpha=0.5` Laplace smoothing) classifies as `valid=1` or `valid=0`.

4. Output is `predict_proba(X)[0][1]` — probability of class 1 (valid).

### Features (final — confirmed)

| Feature | Type | Example values |
|---|---|---|
| `hazard_type` | categorical | `flooded_road`, `landslide`, `fallen_tree`, `road_damage`, `fallen_electric_post`, `road_blocked`, `bridge_damage`, `storm_surge`, `other` |
| `description` | free text | "Road flooded knee deep, vehicles cannot pass" |

**Explicitly NOT NB features:**
- Distance (reporter ↔ hazard) → handled by `rule_scoring.reporter_proximity_weight`
- Nearby report count → handled by `rule_scoring.consensus_rule_score`
- `time_of_report` → removed; hazards occur day and night, time adds no validity signal

### Training dataset (`naive_bayes_dataset.csv`)

| Property | Value |
|---|---|
| Rows | 201 |
| Valid (is_valid=1) | 101 |
| Invalid (is_valid=0) | 100 |
| Training accuracy | 99.5% |

**Valid examples** — descriptive, realistic reports in English and Filipino:
```
flooded_road, "Road flooded knee deep, vehicles cannot pass", 1
landslide, "Gumuho ang lupa sa bundok naharang ang kalsada", 1
fallen_tree, "Large tree fell across road blocking both lanes", 1
road_blocked, "Harang ang daan hindi makalusot kahit motorsiklo", 1
```

**Invalid examples** — spam, nonsense, vague, or contradictory:
```
flooded_road, "test", 0
landslide, "wala lang", 0
bridge_damage, "bridge is perfectly fine and safe", 0
other, "flood flood flood flood", 0
```

Invalid categories:
- Keyboard spam (`asdf`, `qwerty`, `x`)
- Vague Filipino phrases (`wala lang`, `basta`, `ewan`)
- Contradictory / false reports (`clear road no problem`, `walang baha`)
- Word repetition spam (`flood flood flood`)
- Off-topic (`good morning everyone`, `happy birthday`)

### Model files
- `models/naive_bayes_model.pkl` — trained MultinomialNB
- `models/vectorizer.pkl` — fitted CountVectorizer

### Fallback
If pkl files are missing, `NaiveBayesValidator.validate_report()` automatically falls back to the classic manual Bayes using `hazard_type` + description length bucket (short/medium/long). Auto-trains from CSV on first call.

---

## Random Forest — Road Risk Prediction

### Purpose

Predict a **risk score per road segment** based on the types and quantities of approved hazard reports nearby.  
`predicted_risk_score` = estimated danger of travelling through this road segment.

### How it works

1. For each road segment, **features are computed from nearby approved `HazardReport` records** within **200 meters** of the segment midpoint.
2. Feature vector is fed to the trained `RandomForestRegressor`.
3. Output is clamped to `[0, 1]`.

### Features (final — all 8 hazard types)

| Feature | Description |
|---|---|
| `flooded_road_count` | Approved `flooded_road` or `flood` reports within 200 m |
| `landslide_count` | Approved `landslide` reports within 200 m |
| `fallen_tree_count` | Approved `fallen_tree` reports within 200 m |
| `road_damage_count` | Approved `road_damage` reports within 200 m |
| `fallen_electric_post_count` | Approved `fallen_electric_post` reports within 200 m |
| `road_blocked_count` | Approved `road_blocked` reports within 200 m |
| `bridge_damage_count` | Approved `bridge_damage` reports within 200 m |
| `storm_surge_count` | Approved `storm_surge` reports within 200 m |
| `avg_severity` | Mean `final_validation_score` of all nearby approved reports |

### Risk weight per hazard type

These weights are used in the dataset generation formula and are aligned with `HAZARD_TYPE_RISK_WEIGHT` in `route_service.py`:

| Hazard type | Per-report weight | Reason |
|---|---|---|
| `road_blocked` | 0.09 | Physically impassable — highest priority |
| `bridge_damage` | 0.07 | Structural failure risk |
| `storm_surge` | 0.07 | Large area flooding |
| `landslide` | 0.07 | Complete blockage + instability |
| `fallen_electric_post` | 0.05 | Electrocution danger |
| `flooded_road` | 0.04 | Passable depending on depth |
| `road_damage` | 0.04 | Passable with caution |
| `fallen_tree` | 0.03 | Clearable, less permanent |
| `avg_severity` | 0.50 | Quality signal — always dominant |

**Risk formula (used to generate synthetic labels):**
```
risk = min(
    flooded_road_count * 0.04
  + landslide_count * 0.07
  + fallen_tree_count * 0.03
  + road_damage_count * 0.04
  + fallen_electric_post_count * 0.05
  + road_blocked_count * 0.09
  + bridge_damage_count * 0.07
  + storm_surge_count * 0.07
  + avg_severity * 0.50
, 1.0)
```

### Training dataset (`random_forest_dataset.csv`)

| Property | Value |
|---|---|
| Rows | 300 |
| Features | 9 (one per hazard type + avg_severity) |
| Risk range | 0.0 – 1.0 |
| Distribution | ~100 low, ~100 mid, ~100 high risk |
| Training R² | 0.988 |

### Live results on actual road segments (3,257 segments, 1 approved hazard)

| Category | Count | Risk range |
|---|---|---|
| Low risk (< 0.3) — no nearby hazards | 3,249 | 0.039 |
| High risk (≥ 0.7) — near approved hazard | 8 | 0.822 |

As more hazards are approved by MDRRMO, more segments will receive higher risk scores, and Dijkstra will route around them automatically.

### Feature importances (from trained model)

```
avg_severity                0.913
flooded_road_count          0.023
fallen_tree_count           0.021
landslide_count             0.016
road_blocked_count          0.012
road_damage_count           0.006
bridge_damage_count         0.004
storm_surge_count           0.003
fallen_electric_post_count  0.002
```

`avg_severity` dominates because it captures the overall quality/credibility of nearby hazard evidence. Individual type counts refine the estimate.

### Model file
- `models/random_forest_model.pkl` — trained RandomForestRegressor (150 trees, max_depth=10)

---

## ML Service Architecture

`ml_data/ml_service.py` is the central interface for all ML predictions.

### Singleton pattern

```python
from ml_data.ml_service import get_ml_service
ml = get_ml_service()
```

### Naive Bayes prediction

```python
score = ml.predict_naive_bayes(
    hazard_type='flooded_road',
    description='Road flooded knee deep, vehicles cannot pass'
)
# → 1.000 (highly valid)

score = ml.predict_naive_bayes(
    hazard_type='flooded_road',
    description='test'
)
# → 0.004 (likely invalid)
```

### Random Forest prediction

```python
risk = ml.predict_road_risk(
    flooded_road_count=0,
    landslide_count=0,
    fallen_tree_count=0,
    road_damage_count=0,
    fallen_electric_post_count=0,
    road_blocked_count=0,
    bridge_damage_count=0,
    storm_surge_count=0,
    avg_severity=0.0,
)
# → 0.039 (no nearby hazards — base risk)

risk = ml.predict_road_risk(
    flooded_road_count=4,
    landslide_count=2,
    road_blocked_count=2,
    bridge_damage_count=2,
    avg_severity=0.85,
    # other counts default to 0
)
# → 1.000 (very high risk)
```

### Auto-train on first use

If pkl files are missing, `ml_service` automatically calls `train_and_save()` from the training scripts. The CSV is generated if it also doesn't exist. This means the system works on a fresh clone without any manual training step.

### Graceful fallback

| Scenario | NB fallback | RF fallback |
|---|---|---|
| Models not trained | Classic manual Bayes (hazard_type + desc length) | Formula: weighted sum of hazard type counts |
| sklearn not installed | Same classic Bayes | Same formula |
| Prediction error | Returns 0.5 (neutral) | Returns formula result |

---

## Validation Scoring Formula

Every submitted hazard report receives a `validation_breakdown` stored in the database.

### Three components

**1. Naive Bayes score** (`naive_bayes_score`) — text credibility
```
P(valid | hazard_type + description) via sklearn MultinomialNB
Range: 0.0 – 1.0
```

**2. Distance weight** (`distance_weight`) — reporter proximity
```
distance_weight = 1 - (distance_m / 150)
Clamped to [0, 1]
```
- Reporter at the hazard location → weight = 1.0
- Reporter at 150 m → weight = 0.0
- Reporter beyond 150 m → **auto-rejected** before any scoring

**3. Consensus score** (`consensus_score`) — corroboration by others
```
consensus_score = min((confirmation_count + similar_nearby_reports) / 5.0, 1.0)
```
"Similar" = **same `hazard_type`**, within **100 meters**, status `PENDING` or `APPROVED`.

**4. Final validation score** (`final_validation_score`) — weighted blend
```
final_validation_score =
    (naive_bayes_score  × 0.5)
  + (distance_weight    × 0.3)
  + (consensus_score    × 0.2)
```

| Component | Weight | Role |
|---|---|---|
| Naive Bayes | 50% | Text credibility (AI) |
| Distance weight | 30% | Physical validation (reporter must be close) |
| Consensus | 20% | Community corroboration |

### Validation breakdown (stored in DB and shown to MDRRMO)

```json
{
  "naive_bayes_score": 0.94,
  "distance_weight": 0.73,
  "consensus_score": 0.40,
  "final_validation_score": 0.735,
  "score_weights": {"naive_bayes": 0.5, "distance": 0.3, "consensus": 0.2},
  "proximity_limit_meters": 150,
  "consensus_radius_meters": 100,
  "explanation": "This report has high confidence: hazard type matches training data well, reporter was 40m from the reported location, and 2 nearby similar reports were found."
}
```

---

## Road Segment Risk Computation

### Two-layer risk model

```
effective_risk = (base_risk × 0.6) + (dynamic_risk × 0.4)
```

**Base risk** = `predicted_risk_score` from Random Forest (stored in DB per segment).  
**Dynamic risk** = live computation at route time from approved hazards near the segment.

### Dynamic risk (at route time)

For each approved hazard within **100 m** of the segment:
- If `hazard_type == road_blocked` → `effective_risk = 1.0` immediately (fully impassable)
- Otherwise: `dynamic += type_weight × validation_impact`

Where `type_weight` is from `HAZARD_TYPE_RISK_WEIGHT`:

```python
HAZARD_TYPE_RISK_WEIGHT = {
    'road_blocked':      0.7,
    'bridge_damage':     0.5,
    'storm_surge':       0.5,
    'landslide':         0.5,
    'fallen_electric_post': 0.4,
    'flooded_road':      0.3,
    'road_damage':       0.3,
    'fallen_tree':       0.2,
    'other':             0.2,
}
```

### When segment risks update

| Event | Action |
|---|---|
| First boot / all scores = 0 | `_ensure_segment_risk_scores()` auto-runs |
| After RF model retraining | `train_ml_models` auto-calls `update_segment_risks` |
| Manually forced | `python manage.py update_segment_risks` |

---

## Management Commands

### Train both models (and refresh segments)

```bash
python manage.py train_ml_models
```

Output:
```
--- Naive Bayes ---
[NB] Dataset saved: naive_bayes_dataset.csv (201 rows, 101 valid, 100 invalid)
[NB] Training accuracy: 0.995
[NB] Models saved: naive_bayes_model.pkl, vectorizer.pkl
  [OK] Naive Bayes trained and saved

--- Random Forest ---
[RF] Dataset saved: random_forest_dataset.csv (300 rows, 9 features)
[RF] Training R²: 0.9881
[RF] Model saved: random_forest_model.pkl
  [OK] Random Forest trained and saved
  [OK] 3257 segment risk scores updated
```

### Options

```bash
python manage.py train_ml_models --force       # delete CSVs + regenerate + retrain
python manage.py train_ml_models --nb-only     # only Naive Bayes
python manage.py train_ml_models --rf-only     # only Random Forest (also updates segments)
```

### Force-update all segment risk scores

```bash
python manage.py update_segment_risks
```

Output:
```
=== Update Segment Risk Scores ===
Road segments  : 3257
Approved hazards: 1

[OK] 3257 segments updated in 32.7s
  Risk distribution:
    Low  (< 0.3)  : 3249 segments
    Mid  (0.3-0.7): 0 segments
    High (>= 0.7) : 8 segments
  Range  : 0.039 - 0.822
  Average: 0.041
```

Run this after approving many new hazard reports to keep routing risk scores current.

---

## How to Replace with Real Data

The synthetic data is a **placeholder**. The ML pipeline is designed so only the CSV files need to change — the model architecture, service layer, and integrations stay the same.

### Naive Bayes (real MDRRMO data)

**Collect from MDRRMO records:**
- `hazard_type` — the reported hazard category
- `description` — the report text as submitted by the resident
- `is_valid` — `1` if MDRRMO approved, `0` if MDRRMO rejected

**Format:**
```csv
hazard_type,description,is_valid
flooded_road,"Road flooded near evacuation center, waist deep",1
landslide,"asdf",0
```

**Minimum recommended:** 50+ examples per hazard type, balanced valid/invalid.

**Replace:**
```bash
# Replace or append to the CSV:
cp your_real_nb_data.csv backend/ml_data/naive_bayes_dataset.csv

# Retrain:
python manage.py train_ml_models --nb-only --force
```

### Random Forest (real MDRRMO road data)

**Collect per road segment** (or area/grid cell):
- `flooded_road_count` — historical flood incidents
- `landslide_count` — historical landslide incidents
- `fallen_tree_count`, `road_damage_count`, etc.
- `avg_severity` — average severity score of incidents (0–1)
- `risk` — human-labeled road danger level (0–1)

**Format:**
```csv
flooded_road_count,landslide_count,fallen_tree_count,road_damage_count,fallen_electric_post_count,road_blocked_count,bridge_damage_count,storm_surge_count,avg_severity,risk
3,0,1,2,0,0,0,0,0.72,0.55
0,2,0,0,0,1,1,0,0.88,0.80
```

**Minimum recommended:** 200+ rows covering low, medium, and high risk road segments.

**Replace:**
```bash
cp your_real_rf_data.csv backend/ml_data/random_forest_dataset.csv

# Retrain + update all segment scores:
python manage.py train_ml_models --rf-only --force
```

---

## What Has Changed (Summary of Improvements)

This section summarizes all major changes made across multiple development sessions.

### 1. Proximity validation: 1 km → 150 m

| Before | After |
|---|---|
| Reports beyond 1 km auto-rejected | Reports beyond **150 m** auto-rejected |
| `PROXIMITY_REJECT_KM = 1.0` | `PROXIMITY_REJECT_KM = 0.15` |

Files: `backend/reports/utils.py`, `backend/apps/mobile_sync/services/report_service.py`

### 2. Naive Bayes features: description_length only → full text (sklearn)

| Before | After |
|---|---|
| Features: `hazard_type` + description length bucket (short/medium/long) | Features: `hazard_type` + `description` (full text, bag-of-words) |
| Custom manual Bayes implementation | `CountVectorizer` (bigrams) + `MultinomialNB` (sklearn) |
| Mock JSON training data (`mock_training_data.json`) | Synthetic CSV (`naive_bayes_dataset.csv`, 201 rows) |
| `time_of_report` included | `time_of_report` removed |

Files: `ml_data/train_naive_bayes.py`, `ml_data/ml_service.py`, `apps/validation/services/naive_bayes.py`

### 3. Validation scoring formula: equal average → weighted blend

| Before | After |
|---|---|
| `(nb + distance + consensus) / 3` | `(nb × 0.5) + (distance × 0.3) + (consensus × 0.2)` |
| Distance weight formula based on 1 km | `1 - (distance_m / 150)` clamped to [0, 1] |
| Consensus: bucket-based (0→0.0, 1→0.25, 2→0.50, 3+→0.75, 5+→1.0) | Dynamic: `min((confirmations + similar_nearby) / 5.0, 1.0)` |
| Consensus counts any nearby report | Consensus counts only **same hazard_type**, within **100 m**, status PENDING or APPROVED |

Files: `apps/validation/services/rule_scoring.py`, `apps/validation/services/consensus.py`

### 4. Random Forest features: 2 → 9 (all hazard types)

| Before | After |
|---|---|
| Features: `nearby_hazard_count`, `avg_severity` | Features: one count per hazard type (8 types) + `avg_severity` |
| Mock JSON training data | Synthetic CSV (`random_forest_dataset.csv`, 300 rows) |
| Risk loaded from static mock JSON per segment ID | Computed per segment from nearby approved `HazardReport` objects |

Files: `ml_data/train_random_forest.py`, `ml_data/ml_service.py`, `apps/risk_prediction/services/random_forest.py`, `apps/mobile_sync/services/route_service.py`

### 5. Segment risk: static mock values → RF model applied

| Before | After |
|---|---|
| Segment risks loaded from mock JSON (fixed values 0.1–0.75) | RF model computes risk from actual nearby approved hazards |
| `_ensure_segment_risk_scores()` never ran (all segments non-zero from mock) | `recompute_all_segment_risks()` forces RF across all 3,257 segments |
| No management command | `python manage.py update_segment_risks` |

Files: `apps/mobile_sync/services/route_service.py`, `apps/mobile_sync/management/commands/update_segment_risks.py`

### 6. ML service layer: none → centralised pkl loader

| Before | After |
|---|---|
| Each service had its own training/prediction logic | Central `ml_service.py` singleton loads pkl files |
| Models retrained on every request | Models loaded once, cached in memory |
| No persistence | `.pkl` files saved to `ml_data/models/` |
| No management command for training | `python manage.py train_ml_models` |

Files: `ml_data/ml_service.py`, `apps/mobile_sync/management/commands/train_ml_models.py`

### 7. Login/Registration performance

| Improvement | Change |
|---|---|
| Email field indexed | `Meta.indexes` added to `User` model |
| Token returned immediately on login | No session lookups, DRF token only |
| Removed `SessionAuthentication` | `settings.py` — `REST_FRAMEWORK.DEFAULT_AUTHENTICATION_CLASSES` |
| Response compression | `GZipMiddleware` added to `settings.py` |
| HTTP keep-alive | `ApiClient` Dio singleton with `keep-alive` header |
| Parallel token + profile storage | `Future.wait([...])` in `auth_service.dart` |
| Cache-first role check on app start | `auth_gate_screen.dart` reads SharedPreferences before API |
| API response time logging | `time.monotonic()` in backend views |

### 8. Offline mode

| Feature | Implementation |
|---|---|
| Offline storage | Hive boxes: `verifiedHazardsBox`, `pendingReportsBox`, evacuation centers |
| Connectivity detection | `ConnectivityService` singleton (`connectivity_plus`) |
| Auto-sync | `SyncService` triggers on connectivity restore |
| Offline report queue | Status `PENDING_SYNC` in Hive, auto-sent when online |
| UI indicator | `OfflineBanner` widget with pending count |
| Offline routing | Cached evacuation centers + cached hazards |
| Failsafe | All services return empty lists / cached data instead of crashing |

Files: `mobile/lib/core/services/connectivity_service.dart`, `mobile/lib/core/services/sync_service.dart`, `mobile/lib/ui/widgets/offline_banner.dart`, `mobile/lib/features/hazards/hazard_service.dart`, `mobile/lib/features/routing/routing_service.dart`

---

## Related Documentation

| Document | Content |
|---|---|
| `Algorithms_How_They_Work.md` | Algorithm logic, formulas, step-by-step |
| `algorithm-workflow.md` | End-to-end flow from report submission to routing |
| `OFFLINE_MODE.md` | Offline mode architecture and data flows |
| `HAZARD_CONFIRMATION_SYSTEM.md` | Confirmation/consensus system details |
| `PROXIMITY_AND_MEDIA_UPDATES.md` | Proximity rules and media handling |
