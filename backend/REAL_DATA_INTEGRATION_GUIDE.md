# Real MDRRMO Data Integration Guide

This guide explains how to replace mock data with real MDRRMO (Municipal Disaster Risk Reduction and Management Office) data in the Evacuation Route Recommendation backend. It is written for developers who are new to the project.

---

## Overview

The system currently uses:

- **Mock JSON files** for baseline hazards, road network, and ML training data.
- **In-memory/simple ML models** (Naive Bayes, Random Forest) trained on that mock data.

When you integrate real MDRRMO data, you will:

1. Replace mock hazards with official hazard datasets.
2. Replace mock road network with OSM or official road data.
3. Retrain Naive Bayes and Random Forest on verified historical data.
4. Rebuild the road graph and update the mobile cache.

---

## Step 1: Replace Mock Hazards with Real MDRRMO Hazard Data

### Current (mock)

- Data is loaded from `mock_data/mock_hazards.json` via `core/utils/mock_loader.py` → `load_baseline_hazards()`.
- The management command `load_mock_data` calls this on demand.

### With real data

1. **Obtain MDRRMO data**  
   Get official hazard data as CSV or JSON (e.g. hazard type, latitude, longitude, severity, date).

2. **Remove or bypass the mock loader**  
   - In `core/utils/mock_loader.py`, either remove `load_baseline_hazards()`’s use of `mock_hazards.json` or add a switch (e.g. `USE_MOCK = False`).
   - Create a new script or management command, e.g. `import_mdrrmo_hazards`, that:
     - Reads the MDRRMO CSV/JSON.
     - Validates coordinates (lat/lng in valid ranges).
     - Normalizes hazard types (e.g. map "Flash Flood" → "flood") so they match what the app expects.
     - Creates/updates `BaselineHazard` records (source = "MDRRMO").

3. **Run the import**  
   - Run the new command (e.g. `python manage.py import_mdrrmo_hazards`) after deployment or on a schedule.
   - Optionally keep a “load mock data” path for local development only.

---

## Step 2: Import MDRRMO Data (CSV Example)

If MDRRMO provides a CSV with columns like: `hazard_type, latitude, longitude, severity, date`:

1. Create a management command, e.g. `apps/hazards/management/commands/import_mdrrmo_csv.py`.
2. Use Python’s `csv` module or pandas to read the file.
3. For each row:
   - Validate latitude (e.g. -90 to 90) and longitude (-180 to 180).
   - Normalize `hazard_type` (lowercase, map synonyms to standard names).
   - Create or update `BaselineHazard` with `source = "MDRRMO"`.
4. Log errors (e.g. invalid coordinates) and optionally store them for review.

Example structure (pseudo-code):

```python
# In import_mdrrmo_csv.py
def handle(self, *args, **options):
    path = options['file']
    with open(path) as f:
        for row in csv.DictReader(f):
            lat, lng = float(row['latitude']), float(row['longitude'])
            if not (-90 <= lat <= 90 and -180 <= lng <= 180):
                continue  # or log
            BaselineHazard.objects.update_or_create(
                latitude=lat, longitude=lng, hazard_type=normalize(row['hazard_type']),
                defaults={'severity': row['severity'], 'source': 'MDRRMO'}
            )
```

---

## Step 3: Retrain Naive Bayes When Real Data Is Available

### Current (mock)

- Training data comes from `mock_data/mock_training_data.json` → `naive_bayes_training`.
- `apps/validation/services/naive_bayes.py` → `NaiveBayesValidator.train()` loads this and fits a simple Naive Bayes model in memory.

### With real data

1. **Build a training dataset**  
   Use historical hazard reports that MDRRMO has already verified (e.g. `HazardReport` with `status='approved'` or `'rejected'`). Each row should have:
   - `hazard_type`
   - `description` or `description_length`
   - `valid` = True if approved, False if rejected.

2. **Replace the mock loader in NaiveBayesValidator**  
   - Add a method that loads from the database (e.g. `HazardReport.objects.filter(status__in=['approved','rejected'])`) and converts to the same format the trainer expects.
   - In `train()`, if no list is passed, call this method instead of `_load_mock_training()`.

3. **Optional: persist the model**  
   - Use a library like `joblib` to save the trained model to disk.
   - On app startup (or in a cron job), load the saved model so you don’t retrain on every request.
   - Retrain whenever a significant amount of new verified data is available.

4. **Comments in code**  
   The file `apps/validation/services/naive_bayes.py` already contains comments like “TO REPLACE WITH REAL MDRRMO DATA”. Use them as checklists when switching to DB-backed training.

---

## Step 4: Retrain Random Forest When MDRRMO Provides Historical Hazard Data

### Current (mock)

- Training data comes from `mock_data/mock_training_data.json` → `road_risk_training` (segment_id, nearby_hazard_count, avg_severity, risk_score).
- `apps/risk_prediction/services/random_forest.py` → `RoadRiskPredictor.train()` fits a Random Forest regressor and uses it to predict `predicted_risk_score` for road segments.

### With real data

1. **Build segment-level features**  
   For each road segment (or segment ID):
   - **nearby_hazard_count**: number of baseline/verified hazards within a radius (e.g. 100 m).
   - **avg_severity**: average severity of those hazards.
   - You can add more features (e.g. flood history, landslide zone) if MDRRMO provides them.

2. **Build labels**  
   - If MDRRMO has historical “incident” or “road risk” data, use it as the target (e.g. `risk_score` or binary “high risk”).
   - Otherwise, derive a proxy (e.g. number of incidents near the segment, normalized).

3. **Replace the mock loader in RoadRiskPredictor**  
   - Add a function that loads `RoadSegment` and `BaselineHazard`, computes the above features and labels, and returns a list of dicts in the same shape as `road_risk_training`.
   - In `train()`, use this instead of `_load_mock_training()` when not in mock mode.

4. **Retrain and write back**  
   - After training, run prediction for every `RoadSegment` (using its computed features) and set `segment.predicted_risk_score`.
   - Optionally save the model with joblib and reload it on startup; retrain when new MDRRMO hazard or incident data is available.

5. **Comments in code**  
   See “TO REPLACE WITH REAL MDRRMO DATA” in `apps/risk_prediction/services/random_forest.py` for the same workflow.

---

## Step 5: Rebuild the Road Network Graph

### Current (mock)

- Road segments are loaded from `mock_data/mock_road_network.json` via `load_road_network()` in `core/utils/mock_loader.py`.
- The routing service builds a graph from `RoadSegment` (start/end coordinates, base_distance, predicted_risk_score).

### With real data

1. **Obtain road network data**  
   Use OpenStreetMap (OSM) or an official road dataset. Extract segments (e.g. start/end coordinates, length).

2. **Replace the mock loader**  
   - Create an import script or management command that:
     - Reads OSM or official source.
     - Creates/updates `RoadSegment` with `start_lat`, `start_lng`, `end_lat`, `end_lng`, `base_distance`.
     - Leaves `predicted_risk_score` as 0 until Step 4 (Random Forest) is run.

3. **Run Random Forest**  
   - After importing segments and baseline hazards, run the Random Forest training and prediction (Step 4) so that `predicted_risk_score` is filled for each segment.

4. **No code change in Dijkstra**  
   - The routing service already reads all `RoadSegment` rows and builds the graph. Once segments and risk scores are in the DB, routing will use the new network.

---

## Step 6: Update Cache for Mobile

### Current (mock)

- `GET /api/bootstrap-sync/` returns evacuation centers and baseline hazards from the database (currently filled by mock loaders).

### With real data

1. **Keep the same API**  
   - Continue returning evacuation centers and baseline hazards (and any other data the app needs) from the database.

2. **Data source**  
   - Once you stop loading mock data and use MDRRMO imports (Steps 1–2), the database will hold real data and the bootstrap endpoint will automatically serve it.

3. **Optional improvements**  
   - Add a “last_updated” or version field so the mobile app can cache and refresh only when needed.
   - If you have large payloads, consider pagination or delta updates.

---

## Quick Checklist

- [ ] Replace mock hazard loading with MDRRMO CSV/JSON import; validate coordinates and normalize hazard types.
- [ ] Retrain Naive Bayes using verified (approved/rejected) report history; optionally persist model and retrain periodically.
- [ ] Build road network from OSM or official source; fill `RoadSegment` and then run Random Forest to set `predicted_risk_score`.
- [ ] Retrain Random Forest when new MDRRMO hazard or incident data is available; optionally persist model.
- [ ] Ensure bootstrap-sync (and any other cache endpoints) read from the updated database; add versioning if needed.

---

## File Reference

| Purpose                    | Current location / file                                      |
|---------------------------|--------------------------------------------------------------|
| Mock hazard loader        | `core/utils/mock_loader.py` → `load_baseline_hazards()`       |
| Mock road loader          | `core/utils/mock_loader.py` → `load_road_network()`          |
| Naive Bayes training      | `apps/validation/services/naive_bayes.py`                    |
| Consensus scoring         | `apps/validation/services/consensus.py`                      |
| Random Forest training    | `apps/risk_prediction/services/random_forest.py`             |
| Graph / routing           | `apps/routing/services/dijkstra.py`                          |
| Bootstrap API             | `apps/mobile_sync/views.py` → `bootstrap_sync`               |
| Load mock data command    | `apps/mobile_sync/management/commands/load_mock_data.py`      |

Use this guide as a step-by-step plan when switching from mock data to real MDRRMO data.
