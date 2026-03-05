"""
Naive Bayes validation for crowdsourced hazard reports.

Validation is now fully handled by this single algorithm with integrated
proximity and consensus features (as input features, not separate formulas).

Features: hazard_type, description_length (bucketed), distance_category,
nearby_similar_report_count_category, optional time_of_report.
Output: P(valid | report) in [0, 1]. Decision thresholds: >=0.8 auto-approve,
0.5–0.8 pending, <0.5 reject.

TO REPLACE WITH REAL MDRRMO DATA:
1. Load historical MDRRMO-verified reports (CSV/DB) with same feature schema.
2. Call train() with real data, persist model (e.g. joblib) if needed.
3. Re-run training when new verified data is available.
"""
import json
from pathlib import Path
from typing import Any, List, Dict

# Default path; overridden by Django settings when used in app
MOCK_TRAINING_PATH = Path(__file__).resolve().parent.parent.parent.parent / 'mock_data' / 'mock_training_data.json'

# Feature names used for training and prediction
FEATURE_NAMES = ('hazard_type', 'desc_bucket', 'distance_category', 'nearby_count_category')
OPTIONAL_FEATURES = ('time_of_report',)  # Optional; bucket by hour or part-of-day if present


def _bucket_desc_len(length: int) -> str:
    if length < 20:
        return 'short'
    if length < 60:
        return 'medium'
    return 'long'


def _bucket_nearby_count(count: int) -> str:
    """Convert nearby similar report count to category for Naive Bayes."""
    if count == 0:
        return 'none'
    if count <= 2:
        return 'few'
    if count <= 5:
        return 'moderate'
    return 'many'


class NaiveBayesValidator:
    """
    Single Naive Bayes classifier for report validation.
    Features: hazard_type, description_length (bucketed), distance_category,
    nearby_similar_report_count_category, optional time_of_report.
    """
    _bucket_desc_len = staticmethod(_bucket_desc_len)

    def __init__(self):
        self._class_prior: Dict[str, float] = {}
        self._feature_likelihood: Dict[str, Any] = {}
        self._trained = False

    def _load_mock_training(self, path: Path = None) -> list:
        """Load training data from mock JSON. TO REPLACE: Load from DB or MDRRMO CSV."""
        path = path or MOCK_TRAINING_PATH
        if not path.exists():
            return []
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data.get('naive_bayes_training', [])

    def train(self, training_data: List[Dict] = None) -> None:
        """
        Train on list of dicts with keys: hazard_type, description_length (or description),
        valid; optionally distance_category, nearby_similar_report_count_category, time_of_report.
        """
        if training_data is None:
            training_data = self._load_mock_training()
        if not training_data:
            self._trained = False
            return

        valid_count = sum(1 for r in training_data if r.get('valid'))
        total = len(training_data)
        self._class_prior['valid'] = valid_count / total if total else 0.5
        self._class_prior['invalid'] = 1 - self._class_prior['valid']

        # Count features per class (include optional features if present in data)
        valid_feats: Dict[str, Dict[str, int]] = {
            'hazard_type': {}, 'desc_bucket': {},
            'distance_category': {}, 'nearby_count_category': {},
            'time_bucket': {},
        }
        invalid_feats: Dict[str, Dict[str, int]] = {
            'hazard_type': {}, 'desc_bucket': {},
            'distance_category': {}, 'nearby_count_category': {},
            'time_bucket': {},
        }

        for r in training_data:
            ht = r.get('hazard_type', 'unknown')
            desc_len = r.get('description_length', len(r.get('description', '')))
            bucket = _bucket_desc_len(desc_len)
            dist_cat = r.get('distance_category', 'unknown')
            nearby_cat = r.get('nearby_similar_report_count_category', r.get('nearby_count_category', 'unknown'))
            time_bucket = r.get('time_of_report', r.get('time_bucket', 'unknown'))
            if isinstance(time_bucket, (int, float)):
                time_bucket = 'day' if 6 <= time_bucket < 22 else 'night'

            target = valid_feats if r.get('valid') else invalid_feats
            target['hazard_type'][ht] = target['hazard_type'].get(ht, 0) + 1
            target['desc_bucket'][bucket] = target['desc_bucket'].get(bucket, 0) + 1
            target['distance_category'][dist_cat] = target['distance_category'].get(dist_cat, 0) + 1
            target['nearby_count_category'][nearby_cat] = target['nearby_count_category'].get(nearby_cat, 0) + 1
            target['time_bucket'][str(time_bucket)] = target['time_bucket'].get(str(time_bucket), 0) + 1

        self._feature_likelihood = {
            'valid': {**valid_feats, 'valid_total': valid_count, 'invalid_total': total - valid_count},
            'invalid': {**invalid_feats, 'valid_total': valid_count, 'invalid_total': total - valid_count},
        }
        self._trained = True

    def validate_report(self, report_data: Dict[str, Any]) -> float:
        """
        Return P(valid | report) in [0, 1].
        report_data: hazard_type, description or description_length,
                     distance_category (optional), nearby_similar_report_count_category (optional),
                     time_of_report (optional).
        """
        if not self._trained:
            self.train()

        hazard_type = report_data.get('hazard_type', 'unknown')
        desc = report_data.get('description', '')
        desc_len = report_data.get('description_length', len(desc))
        bucket = _bucket_desc_len(desc_len)
        distance_category = report_data.get('distance_category', 'unknown')
        nearby_category = report_data.get('nearby_similar_report_count_category', report_data.get('nearby_count_category', 'unknown'))
        time_val = report_data.get('time_of_report')
        if time_val is None:
            time_bucket = 'unknown'
        elif isinstance(time_val, (int, float)) and 6 <= time_val < 22:
            time_bucket = 'day'
        elif isinstance(time_val, (int, float)):
            time_bucket = 'night'
        else:
            time_bucket = str(time_val)

        p_valid = self._class_prior.get('valid', 0.5)
        p_invalid = self._class_prior.get('invalid', 0.5)
        v = self._feature_likelihood.get('valid', {})
        inv = self._feature_likelihood.get('invalid', {})
        k = 0.5
        n_valid = (v.get('valid_total') or 0) + 1
        n_invalid = (inv.get('invalid_total') or 0) + 1

        def lik(d: dict, key: str, val: str) -> float:
            counts = d.get(key, {})
            total = sum(counts.values()) or 1
            return (counts.get(val, 0) + k) / (total + k * 10)

        v_ht = lik(v, 'hazard_type', hazard_type)
        v_desc = lik(v, 'desc_bucket', bucket)
        v_dist = lik(v, 'distance_category', distance_category)
        v_nearby = lik(v, 'nearby_count_category', nearby_category)
        v_time = lik(v, 'time_bucket', time_bucket)
        i_ht = lik(inv, 'hazard_type', hazard_type)
        i_desc = lik(inv, 'desc_bucket', bucket)
        i_dist = lik(inv, 'distance_category', distance_category)
        i_nearby = lik(inv, 'nearby_count_category', nearby_category)
        i_time = lik(inv, 'time_bucket', time_bucket)

        post_valid = p_valid * v_ht * v_desc * v_dist * v_nearby * v_time
        post_invalid = p_invalid * i_ht * i_desc * i_dist * i_nearby * i_time
        total = post_valid + post_invalid
        return (post_valid / total) if total else 0.5


# Export for use by report service (e.g. nearby count -> category).
def nearby_count_to_category(count: int) -> str:
    return _bucket_nearby_count(count)
