"""
Train Random Forest regressor for road segment risk prediction.

# Using synthetic training data (temporary)
# Replace with MDRRMO historical data when available

Features per road segment (one count per actual hazard type in the system):
    flooded_road_count       — nearby approved flooded_road reports
    landslide_count          — nearby approved landslide reports
    fallen_tree_count        — nearby approved fallen_tree reports
    road_damage_count        — nearby approved road_damage reports
    fallen_electric_post_count — nearby approved fallen_electric_post reports
    road_blocked_count       — nearby approved road_blocked reports
    bridge_damage_count      — nearby approved bridge_damage reports
    storm_surge_count        — nearby approved storm_surge reports
    avg_severity             — average final_validation_score of nearby reports

Risk formula weights (aligned with route_service HAZARD_TYPE_RISK_WEIGHT):
    road_blocked:           0.09 per report  (physically blocks passage — highest)
    bridge_damage:          0.07 per report
    storm_surge:            0.07 per report
    landslide:              0.07 per report
    fallen_electric_post:   0.05 per report
    flooded_road:           0.04 per report
    road_damage:            0.04 per report
    fallen_tree:            0.03 per report
    avg_severity:           0.50             (dominant quality signal)

Output:
    models/random_forest_model.pkl
    random_forest_dataset.csv   (generated if not exists)

Run:
    python ml_data/train_random_forest.py
    OR: python manage.py train_ml_models
"""
import csv
import math
import pickle
import random
from pathlib import Path

ML_DATA_DIR = Path(__file__).parent
MODELS_DIR = ML_DATA_DIR / 'models'
CSV_PATH = ML_DATA_DIR / 'random_forest_dataset.csv'

FEATURE_COLUMNS = [
    'flooded_road_count',
    'landslide_count',
    'fallen_tree_count',
    'road_damage_count',
    'fallen_electric_post_count',
    'road_blocked_count',
    'bridge_damage_count',
    'storm_surge_count',
    'avg_severity',
]

# Per-report risk contribution (aligned with HAZARD_TYPE_RISK_WEIGHT in route_service)
RISK_WEIGHTS = {
    'flooded_road':        0.04,
    'landslide':           0.07,
    'fallen_tree':         0.03,
    'road_damage':         0.04,
    'fallen_electric_post': 0.05,
    'road_blocked':        0.09,
    'bridge_damage':       0.07,
    'storm_surge':         0.07,
    'avg_severity':        0.50,
}


def _risk(counts: dict, avg_severity: float, noise: float = 0.0) -> float:
    """Compute risk label from per-type hazard counts + severity."""
    raw = (
        counts.get('flooded_road', 0)         * RISK_WEIGHTS['flooded_road']
        + counts.get('landslide', 0)           * RISK_WEIGHTS['landslide']
        + counts.get('fallen_tree', 0)         * RISK_WEIGHTS['fallen_tree']
        + counts.get('road_damage', 0)         * RISK_WEIGHTS['road_damage']
        + counts.get('fallen_electric_post', 0) * RISK_WEIGHTS['fallen_electric_post']
        + counts.get('road_blocked', 0)        * RISK_WEIGHTS['road_blocked']
        + counts.get('bridge_damage', 0)       * RISK_WEIGHTS['bridge_damage']
        + counts.get('storm_surge', 0)         * RISK_WEIGHTS['storm_surge']
        + avg_severity                         * RISK_WEIGHTS['avg_severity']
        + noise
    )
    return max(0.0, min(1.0, round(raw, 4)))


def _gauss(sigma: float = 0.02) -> float:
    """Box-Muller Gaussian noise (no numpy needed in generation step)."""
    import math
    u1 = max(random.random(), 1e-10)
    u2 = random.random()
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2) * sigma


def generate_dataset(n: int = 300, seed: int = 42) -> list:
    """
    Generate n synthetic road segment risk records covering all 8 hazard types.

    Distribution:
        ~100 rows low risk  (risk < 0.3)   — few/no nearby hazards
        ~100 rows mid risk  (0.3–0.7)      — moderate nearby hazards
        ~100 rows high risk (risk ≥ 0.7)   — many/severe hazards, road_blocked present

    # Using synthetic training data (temporary)
    # Replace with MDRRMO historical data when available
    """
    random.seed(seed)
    rows = []

    def wf(lo, hi):
        """Weighted float feature: simulates recency × type_severity contribution."""
        return round(random.uniform(lo, hi), 3)

    # ── Low risk: no/few hazards, or only old/minor ones (low weighted values) ─
    for _ in range(n // 3):
        counts = {
            'flooded_road':         wf(0.0, 0.5),
            'landslide':            wf(0.0, 0.4),
            'fallen_tree':          wf(0.0, 0.3),
            'road_damage':          wf(0.0, 0.5),
            'fallen_electric_post': wf(0.0, 0.2),
            'road_blocked':         0.0,
            'bridge_damage':        0.0,
            'storm_surge':          0.0,
        }
        sev = round(random.uniform(0.0, 0.35), 2)
        risk = _risk(counts, sev, _gauss())
        rows.append([
            counts['flooded_road'], counts['landslide'], counts['fallen_tree'],
            counts['road_damage'], counts['fallen_electric_post'],
            counts['road_blocked'], counts['bridge_damage'], counts['storm_surge'],
            sev, risk,
        ])

    # ── Medium risk: several recent/mixed hazards across types ────────────────
    for _ in range(n // 3):
        counts = {
            'flooded_road':         wf(0.0, 2.0),
            'landslide':            wf(0.0, 1.5),
            'fallen_tree':          wf(0.0, 1.2),
            'road_damage':          wf(0.0, 1.5),
            'fallen_electric_post': wf(0.0, 1.0),
            'road_blocked':         wf(0.0, 0.8),
            'bridge_damage':        wf(0.0, 1.0),
            'storm_surge':          wf(0.0, 1.0),
        }
        sev = round(random.uniform(0.30, 0.70), 2)
        risk = _risk(counts, sev, _gauss())
        rows.append([
            counts['flooded_road'], counts['landslide'], counts['fallen_tree'],
            counts['road_damage'], counts['fallen_electric_post'],
            counts['road_blocked'], counts['bridge_damage'], counts['storm_surge'],
            sev, risk,
        ])

    # ── High risk: many recent hazards, severe types present ─────────────────
    remaining = n - 2 * (n // 3)
    for _ in range(remaining):
        counts = {
            'flooded_road':         wf(1.0, 4.0),
            'landslide':            wf(0.5, 3.5),
            'fallen_tree':          wf(0.3, 2.5),
            'road_damage':          wf(0.5, 3.0),
            'fallen_electric_post': wf(0.0, 2.5),
            'road_blocked':         wf(0.5, 4.0),  # always present in high risk
            'bridge_damage':        wf(0.5, 3.5),
            'storm_surge':          wf(0.0, 3.0),
        }
        sev = round(random.uniform(0.65, 1.00), 2)
        risk = _risk(counts, sev, _gauss())
        rows.append([
            counts['flooded_road'], counts['landslide'], counts['fallen_tree'],
            counts['road_damage'], counts['fallen_electric_post'],
            counts['road_blocked'], counts['bridge_damage'], counts['storm_surge'],
            sev, risk,
        ])

    random.shuffle(rows)
    return rows


def generate_csv(path: Path = CSV_PATH, n: int = 300) -> None:
    """Write synthetic RF dataset to CSV."""
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = generate_dataset(n)
    with open(path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(FEATURE_COLUMNS + ['risk'])
        writer.writerows(rows)
    risks = [r[-1] for r in rows]
    low  = sum(1 for r in risks if r < 0.3)
    mid  = sum(1 for r in risks if 0.3 <= r < 0.7)
    high = sum(1 for r in risks if r >= 0.7)
    print(f'[RF] Dataset saved: {path} ({len(rows)} rows, {len(FEATURE_COLUMNS)} features '
          f'— low:{low} mid:{mid} high:{high})')


def train_and_save(csv_path: Path = CSV_PATH) -> None:
    """
    Generate CSV (if missing), train RandomForestRegressor on all hazard type features, save pkl.

    # Using synthetic training data (temporary)
    # Replace with MDRRMO historical data when available
    """
    try:
        from sklearn.ensemble import RandomForestRegressor
        import numpy as np
    except ImportError:
        print('[RF] scikit-learn not installed — skipping training.')
        return

    # Check if CSV exists and has the correct schema
    needs_regen = not csv_path.exists()
    if not needs_regen:
        try:
            with open(csv_path, 'r', encoding='utf-8') as f:
                existing_cols = csv.DictReader(f).fieldnames or []
            if set(FEATURE_COLUMNS) - set(existing_cols):
                print('[RF] CSV schema outdated — regenerating dataset.')
                needs_regen = True
        except Exception:
            needs_regen = True

    if needs_regen:
        try:
            generate_csv(csv_path)
        except PermissionError:
            print('[RF] CSV file is locked (open in editor) — training from in-memory data.')

    # Load from CSV if readable, otherwise generate in memory
    X_list, y_list = [], []
    csv_readable = False
    if csv_path.exists():
        try:
            with open(csv_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                cols = reader.fieldnames or []
                if not (set(FEATURE_COLUMNS) - set(cols)):
                    for row in reader:
                        X_list.append([float(row[col]) for col in FEATURE_COLUMNS])
                        y_list.append(float(row['risk']))
                    csv_readable = True
        except Exception:
            pass

    if not csv_readable:
        print('[RF] Generating data in memory for training.')
        raw_rows = generate_dataset()
        for row in raw_rows:
            X_list.append(row[:-1])   # all columns except last (risk)
            y_list.append(row[-1])

    X = np.array(X_list)
    y = np.array(y_list)
    print(f'[RF] Training on {len(X)} rows, {X.shape[1]} features '
          f'(risk range {y.min():.3f}–{y.max():.3f}) ...')

    model = RandomForestRegressor(
        n_estimators=150,
        max_depth=10,
        min_samples_leaf=3,
        random_state=42,
    )
    model.fit(X, y)

    train_r2 = model.score(X, y)
    print(f'[RF] Training R²: {train_r2:.4f}')
    importances = dict(zip(FEATURE_COLUMNS, model.feature_importances_))
    print('[RF] Feature importances:')
    for feat, imp in sorted(importances.items(), key=lambda x: -x[1]):
        print(f'       {feat:<28} {imp:.3f}')

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    rf_path = MODELS_DIR / 'random_forest_model.pkl'
    # Also save the feature column order so ml_service can verify alignment
    meta_path = MODELS_DIR / 'random_forest_features.pkl'
    with open(rf_path, 'wb') as f:
        pickle.dump(model, f)
    with open(meta_path, 'wb') as f:
        pickle.dump(FEATURE_COLUMNS, f)
    print(f'[RF] Model saved: {rf_path.name}')


if __name__ == '__main__':
    train_and_save()
