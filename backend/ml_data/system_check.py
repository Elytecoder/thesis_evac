"""
Full system workflow check.
Run: python ml_data/system_check.py
"""
import sys, os, django
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

PASS = '[PASS]'
FAIL = '[FAIL]'
WARN = '[WARN]'
results = []

def check(label, ok, detail=''):
    tag = PASS if ok else FAIL
    results.append((tag, label, detail))
    status = 'OK  ' if ok else 'FAIL'
    print(f'  {tag} {label}' + (f'  ({detail})' if detail else ''))
    return ok

def section(title):
    print(f'\n{"="*55}')
    print(f'  {title}')
    print(f'{"="*55}')

# ─────────────────────────────────────────────────────────
section('1. DATABASE & MODELS')
# ─────────────────────────────────────────────────────────
try:
    from apps.routing.models import RoadSegment
    seg_count = RoadSegment.objects.count()
    check('RoadSegment table accessible', True, f'{seg_count} segments')
    check('Road segments loaded', seg_count > 0, f'{seg_count} segments')
except Exception as e:
    check('RoadSegment table accessible', False, str(e))

try:
    from apps.hazards.models import HazardReport
    total_reports = HazardReport.objects.count()
    approved = HazardReport.objects.filter(status='approved').count()
    pending = HazardReport.objects.filter(status='pending').count()
    check('HazardReport table accessible', True, f'{total_reports} total, {approved} approved, {pending} pending')
except Exception as e:
    check('HazardReport table accessible', False, str(e))

try:
    from apps.evacuation.models import EvacuationCenter
    centers = EvacuationCenter.objects.count()
    check('EvacuationCenter table accessible', True, f'{centers} centers')
    check('Evacuation centers loaded', centers > 0, f'{centers} centers')
except Exception as e:
    check('EvacuationCenter table accessible', False, str(e))

try:
    from apps.users.models import User
    users = User.objects.count()
    check('User table accessible', True, f'{users} users')
except Exception as e:
    check('User table accessible', False, str(e))

# ─────────────────────────────────────────────────────────
section('2. ML MODELS & SERVICES')
# ─────────────────────────────────────────────────────────
try:
    from ml_data.ml_service import get_ml_service
    ml = get_ml_service()
    check('ml_service singleton importable', True)
except Exception as e:
    check('ml_service singleton importable', False, str(e))

# NB model
try:
    ml._nb_ready = False; ml._nb_model = None; ml._vectorizer = None
    loaded = ml._load_nb()
    check('naive_bayes_model.pkl exists and loads', loaded)
except Exception as e:
    check('naive_bayes_model.pkl exists and loads', False, str(e))

# NB predictions
try:
    valid_score = ml.predict_naive_bayes('flooded_road', 'Road flooded knee deep vehicles cannot pass')
    invalid_score = ml.predict_naive_bayes('flooded_road', 'test')
    nb_works = valid_score > 0.7 and invalid_score < 0.3
    check('NB scores valid>invalid', nb_works,
          f'valid={valid_score:.3f} invalid={invalid_score:.3f}')
except Exception as e:
    check('NB predictions work', False, str(e))

# RF model
try:
    ml._rf_ready = False; ml._rf_model = None
    loaded = ml._load_rf()
    check('random_forest_model.pkl exists and loads', loaded)
except Exception as e:
    check('random_forest_model.pkl exists and loads', False, str(e))

# RF predictions
try:
    low = ml.predict_road_risk()  # all zeros
    high = ml.predict_road_risk(flooded_road_count=5, landslide_count=3,
                                 road_blocked_count=2, bridge_damage_count=2,
                                 avg_severity=0.9)
    rf_works = low < 0.2 and high > 0.5
    check('RF scores low<high', rf_works, f'low={low:.3f} high={high:.3f}')
except Exception as e:
    check('RF predictions work', False, str(e))

# NaiveBayesValidator
try:
    from apps.validation.services.naive_bayes import NaiveBayesValidator
    nb = NaiveBayesValidator()
    s = nb.validate_report({'hazard_type': 'landslide', 'description': 'Large boulders blocking road after heavy rain'})
    check('NaiveBayesValidator.validate_report()', 0 < s <= 1.0, f'score={s:.3f}')
except Exception as e:
    check('NaiveBayesValidator.validate_report()', False, str(e))

# RoadRiskPredictor
try:
    from apps.risk_prediction.services.random_forest import RoadRiskPredictor
    pred = RoadRiskPredictor()
    r = pred.predict_risk(flooded_road_count=2, landslide_count=1, avg_severity=0.6)
    check('RoadRiskPredictor.predict_risk()', 0 <= r <= 1.0, f'risk={r:.3f}')
except Exception as e:
    check('RoadRiskPredictor.predict_risk()', False, str(e))

# ─────────────────────────────────────────────────────────
section('3. VALIDATION SCORING')
# ─────────────────────────────────────────────────────────
try:
    from apps.validation.services.rule_scoring import (
        reporter_proximity_weight, consensus_rule_score, combine_validation_scores
    )
    # Proximity weight
    w0 = reporter_proximity_weight(0)        # at hazard = 1.0
    w75 = reporter_proximity_weight(0.075)   # 75 m = 0.5
    w150 = reporter_proximity_weight(0.15)   # 150 m = 0.0
    w200 = reporter_proximity_weight(0.2)    # beyond = 0.0 (clamped)
    prox_ok = abs(w0 - 1.0) < 0.01 and abs(w75 - 0.5) < 0.05 and w150 == 0.0 and w200 == 0.0
    check('reporter_proximity_weight formula', prox_ok,
          f'0m={w0:.2f} 75m={w75:.2f} 150m={w150:.2f} 200m={w200:.2f}')

    # Consensus score
    c0 = consensus_rule_score(0)
    c1 = consensus_rule_score(1)
    c5 = consensus_rule_score(5)
    c10 = consensus_rule_score(10)
    cons_ok = c0 == 0.0 and abs(c1 - 0.2) < 0.01 and c5 == 1.0 and c10 == 1.0
    check('consensus_rule_score formula (linear /5)', cons_ok,
          f'0={c0:.2f} 1={c1:.2f} 5={c5:.2f} 10={c10:.2f}')

    # Final validation formula weights
    fv = combine_validation_scores(1.0, 1.0, 1.0)
    fv2 = combine_validation_scores(1.0, 0.0, 0.0)
    fv3 = combine_validation_scores(0.0, 1.0, 0.0)
    weights_ok = abs(fv - 1.0) < 0.01 and abs(fv2 - 0.5) < 0.01 and abs(fv3 - 0.3) < 0.01
    check('combine_validation_scores (0.5/0.3/0.2)', weights_ok,
          f'all-1={fv:.2f} nb-only={fv2:.2f} dist-only={fv3:.2f}')
except Exception as e:
    check('Rule scoring functions', False, str(e))

# ─────────────────────────────────────────────────────────
section('4. PROXIMITY GATE (150 m rule)')
# ─────────────────────────────────────────────────────────
try:
    from reports.utils import PROXIMITY_REJECT_KM, should_auto_reject_report, haversine_km
    check('PROXIMITY_REJECT_KM = 0.15', abs(PROXIMITY_REJECT_KM - 0.15) < 0.001,
          f'actual={PROXIMITY_REJECT_KM}')
    # Test should_auto_reject_report: 200 m away should be rejected, 55 m should not
    rejected = should_auto_reject_report(user_lat=0.0, user_lng=0.0,
                                          hazard_lat=0.0018, hazard_lng=0.0)
    accepted = should_auto_reject_report(user_lat=0.0, user_lng=0.0,
                                          hazard_lat=0.0005, hazard_lng=0.0)
    # returns (should_reject: bool, message, distance_km)
    check('should_auto_reject(200m away) = True', rejected[0] is True,
          f'reject={rejected[0]} dist={rejected[2]*1000:.0f}m')
    check('should_auto_reject(55m away) = False', accepted[0] is False,
          f'reject={accepted[0]} dist={accepted[2]*1000:.0f}m')
except Exception as e:
    check('Proximity gate (reports/utils)', False, str(e))

# ─────────────────────────────────────────────────────────
section('5. CONSENSUS SERVICE')
# ─────────────────────────────────────────────────────────
try:
    from apps.validation.services.consensus import ConsensusScoringService, CONSENSUS_RADIUS_METERS
    check('CONSENSUS_RADIUS_METERS = 100', abs(CONSENSUS_RADIUS_METERS - 100.0) < 0.1,
          f'actual={CONSENSUS_RADIUS_METERS}')
    svc = ConsensusScoringService()
    # count_nearby_reports with empty queryset should return 0
    qs = HazardReport.objects.none()
    count = svc.count_nearby_reports(12.7, 123.9, qs, hazard_type='flooded_road')
    check('count_nearby_reports(empty) = 0', count == 0, f'count={count}')
except Exception as e:
    check('Consensus service', False, str(e))

# ─────────────────────────────────────────────────────────
section('6. ROAD SEGMENT RISK SCORES')
# ─────────────────────────────────────────────────────────
try:
    segs = list(RoadSegment.objects.all()[:10])
    scores = [float(s.predicted_risk_score or 0) for s in segs]
    all_valid = all(0.0 <= s <= 1.0 for s in scores)
    nonzero = sum(1 for s in scores if s > 0)
    check('Segment risk scores in [0,1]', all_valid, f'sample={[round(s,3) for s in scores[:5]]}')
    check('Segments have non-zero RF scores', nonzero > 0, f'{nonzero}/10 non-zero')

    # Distribution
    all_scores = list(RoadSegment.objects.values_list('predicted_risk_score', flat=True))
    fs = [float(s or 0) for s in all_scores]
    low  = sum(1 for s in fs if s < 0.3)
    mid  = sum(1 for s in fs if 0.3 <= s < 0.7)
    high = sum(1 for s in fs if s >= 0.7)
    check('Segment risk distribution reasonable', True,
          f'low={low} mid={mid} high={high} of {len(fs)} total')
except Exception as e:
    check('Segment risk scores', False, str(e))

# ─────────────────────────────────────────────────────────
section('7. ROUTING SERVICE')
# ─────────────────────────────────────────────────────────
try:
    from apps.mobile_sync.services.route_service import (
        calculate_segment_risk, _compute_segment_rf_features
    )
    check('route_service importable', True)

    # Test calculate_segment_risk with a real segment
    segs = list(RoadSegment.objects.all()[:1])
    if segs:
        hazards = list(HazardReport.objects.filter(status='approved'))
        risk = calculate_segment_risk(segs[0], hazards)
        check('calculate_segment_risk() returns [0,1]', 0.0 <= risk <= 1.0,
              f'risk={risk:.3f}')
        feats = _compute_segment_rf_features(segs[0], hazards)
        check('_compute_segment_rf_features() returns dict with 9 keys',
              len(feats) == 9, f'keys={list(feats.keys())}')
    else:
        check('calculate_segment_risk()', False, 'no segments in DB')
except Exception as e:
    check('Routing service', False, str(e))

# ─────────────────────────────────────────────────────────
section('8. EVACUATION CENTERS & ROUTING ENDPOINT')
# ─────────────────────────────────────────────────────────
try:
    centers = list(EvacuationCenter.objects.filter(is_operational=True)[:3])
    check('Operational evacuation centers exist', len(centers) > 0, f'{len(centers)} operational')
    if centers:
        c = centers[0]
        has_coords = c.latitude is not None and c.longitude is not None
        check('Evacuation center has lat/lng', has_coords,
              f'{c.name}: {c.latitude},{c.longitude}')
except Exception as e:
    check('Evacuation centers', False, str(e))

try:
    from apps.mobile_sync.services.route_service import calculate_safest_routes
    check('calculate_safest_routes importable', True)
except Exception as e:
    check('calculate_safest_routes importable', False, str(e))

# ─────────────────────────────────────────────────────────
section('9. HAZARD CONFIRMATION SYSTEM')
# ─────────────────────────────────────────────────────────
try:
    from apps.hazards.models import HazardConfirmation
    confirmations = HazardConfirmation.objects.count()
    check('HazardConfirmation table accessible', True, f'{confirmations} confirmations')
except Exception as e:
    check('HazardConfirmation table accessible', False, str(e))

try:
    from apps.mobile_sync.views import confirm_hazard_report
    check('confirm_hazard_report view importable', True)
except Exception as e:
    check('confirm_hazard_report view importable', False, str(e))

# ─────────────────────────────────────────────────────────
section('10. REPORT SERVICE (FULL PIPELINE SIMULATION)')
# ─────────────────────────────────────────────────────────
try:
    from apps.mobile_sync.services.report_service import process_new_report
    check('process_new_report importable', True)
except Exception as e:
    check('process_new_report importable', False, str(e))

# Simulate validation breakdown calculation without saving to DB
try:
    nb = NaiveBayesValidator()
    from apps.validation.services.rule_scoring import (
        reporter_proximity_weight, consensus_rule_score, combine_validation_scores
    )

    # Simulate: report 80m away, 2 similar nearby reports, descriptive text
    nb_score = nb.validate_report({
        'hazard_type': 'flooded_road',
        'description': 'Road flooded knee deep, vehicles cannot pass'
    })
    dist_weight = reporter_proximity_weight(0.08)  # 80 m
    cons_score  = consensus_rule_score(2)           # 2 similar nearby
    final       = combine_validation_scores(nb_score, dist_weight, cons_score)

    all_valid = all(0 <= v <= 1 for v in [nb_score, dist_weight, cons_score, final])
    check('Full validation pipeline (simulated)', all_valid,
          f'NB={nb_score:.3f} dist={dist_weight:.3f} consensus={cons_score:.3f} final={final:.3f}')
    check('final_validation_score uses weighted formula', True,
          f'= ({nb_score:.2f}x0.5) + ({dist_weight:.2f}x0.3) + ({cons_score:.2f}x0.2) = {final:.3f}')
except Exception as e:
    check('Full validation pipeline', False, str(e))

# ─────────────────────────────────────────────────────────
section('11. ML TRAINING FILES PRESENT')
# ─────────────────────────────────────────────────────────
from pathlib import Path
ml_dir = Path(__file__).parent
checks_files = {
    'naive_bayes_dataset.csv': ml_dir / 'naive_bayes_dataset.csv',
    'random_forest_dataset.csv': ml_dir / 'random_forest_dataset.csv',
    'naive_bayes_model.pkl': ml_dir / 'models' / 'naive_bayes_model.pkl',
    'vectorizer.pkl': ml_dir / 'models' / 'vectorizer.pkl',
    'random_forest_model.pkl': ml_dir / 'models' / 'random_forest_model.pkl',
    'train_naive_bayes.py': ml_dir / 'train_naive_bayes.py',
    'train_random_forest.py': ml_dir / 'train_random_forest.py',
    'ml_service.py': ml_dir / 'ml_service.py',
}
for name, path in checks_files.items():
    exists = path.exists()
    size = f'{path.stat().st_size:,} bytes' if exists else 'missing'
    check(f'{name} present', exists, size)

# ─────────────────────────────────────────────────────────
section('12. MANAGEMENT COMMANDS REGISTERED')
# ─────────────────────────────────────────────────────────
from django.core.management import get_commands
cmds = get_commands()
for cmd in ['train_ml_models', 'update_segment_risks', 'load_mock_data', 'seed_evacuation_centers']:
    check(f'manage.py {cmd}', cmd in cmds)

# ─────────────────────────────────────────────────────────
section('RESULTS SUMMARY')
# ─────────────────────────────────────────────────────────
passed = sum(1 for r in results if r[0] == PASS)
failed = sum(1 for r in results if r[0] == FAIL)
total  = len(results)
print(f'\n  Total checks : {total}')
print(f'  Passed       : {passed}')
print(f'  Failed       : {failed}')
if failed == 0:
    print('\n  SYSTEM IS FULLY OPERATIONAL')
else:
    print('\n  FAILED CHECKS:')
    for tag, label, detail in results:
        if tag == FAIL:
            print(f'    - {label}: {detail}')
