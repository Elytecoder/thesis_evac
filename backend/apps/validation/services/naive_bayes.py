"""
Naive Bayes for hazard report validation — TEXT / CLASSIFICATION ONLY.

Primary implementation: sklearn MultinomialNB + CountVectorizer (ml_service).
    Input  = hazard_type + ' ' + description (full text, bag-of-words).
    Output = P(valid | text) in [0, 1].

Fallback (classic): manual Bayes with hazard_type + description_length bucket.
    Used only if ml_service models are not trained yet.

# Using synthetic training data (temporary)
# Replace with MDRRMO historical data when available

NOT included by design:
- distance        — handled by rule_scoring.reporter_proximity_weight
- nearby count    — handled by rule_scoring.consensus_rule_score
- confirmations   — handled by rule_scoring.consensus_rule_score

TO REPLACE WITH REAL MDRRMO DATA:
1. Collect MDRRMO-verified hazard reports: hazard_type, description, is_valid (0/1).
2. Add rows to ml_data/naive_bayes_dataset.csv (or replace it entirely).
3. Run: python manage.py train_ml_models --nb-only --force
"""
import json
import logging
import re
from pathlib import Path
from typing import Any, List, Dict

logger = logging.getLogger(__name__)

MOCK_TRAINING_PATH = Path(__file__).resolve().parent.parent.parent.parent / 'mock_data' / 'mock_training_data.json'

# Keywords that strongly suggest a real, reportable hazard event.
# Used only for 'other' type reports to compensate for the absent type signal.
_HAZARD_KEYWORDS = [
    'flood', 'flooded', 'flooding', 'water', 'submerged',
    'blocked', 'block', 'obstacle', 'debris',
    'landslide', 'slide', 'mudslide', 'rockslide', 'collapse', 'collapsed',
    'fallen', 'fell', 'tree', 'fallen tree', 'uprooted',
    'damage', 'damaged', 'broken', 'crack', 'cracked',
    'accident', 'crash', 'vehicle',
    'fire', 'burning', 'smoke',
    'road', 'bridge', 'path', 'route',
    'impassable', 'unsafe', 'danger', 'dangerous',
    'evacuation', 'evacuate',
    'power', 'electric', 'wire', 'post',
]


def _keyword_match_score(description: str) -> float:
    """
    Return 0.0–1.0 based on hazard keyword presence in description.
    Saturates at 3 distinct keyword hits → 1.0.
    Uses word-level tokenization to prevent substring double-counting
    (e.g. 'blocked' should not also match 'block').
    Used only for 'other' type boost.
    """
    if not description:
        return 0.0
    words = set(re.sub(r'[^a-z\s]', ' ', description.lower()).split())
    matches = sum(1 for kw in _HAZARD_KEYWORDS if kw in words)
    return min(1.0, matches / 3.0)


def _bucket_desc_len(length: int) -> str:
    """Bucket description character count into three quality tiers."""
    if length < 20:
        return 'short'
    if length < 60:
        return 'medium'
    return 'long'


def _bucket_nearby_count(count: int) -> str:
    """Legacy export for tests; not used in NB features."""
    if count == 0:
        return 'none'
    if count <= 2:
        return 'few'
    if count <= 5:
        return 'moderate'
    return 'many'


class NaiveBayesValidator:
    """
    Naive Bayes: hazard_type + description_length bucket only.

    Bayes rule applied:
        P(valid | features) ∝ P(valid) × P(hazard_type | valid) × P(desc_bucket | valid)
        P(invalid | features) ∝ P(invalid) × P(hazard_type | invalid) × P(desc_bucket | invalid)
        score = P(valid | features) / (P(valid | features) + P(invalid | features))

    Laplace smoothing (k=0.5) prevents zero probabilities for unseen feature values.
    """

    _bucket_desc_len = staticmethod(_bucket_desc_len)

    def __init__(self):
        self._class_prior: Dict[str, float] = {}
        self._feature_likelihood: Dict[str, Any] = {}
        self._trained = False

    def _load_mock_training(self, path: Path = None) -> list:
        path = path or MOCK_TRAINING_PATH
        if not path.exists():
            return []
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data.get('naive_bayes_training', [])

    def train(self, training_data: List[Dict] = None) -> None:
        """
        Train on dicts with: hazard_type, description_length or description, valid.
        Any extra keys (time_of_report, distance_*, nearby_*) are silently ignored.
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

        valid_feats: Dict[str, Dict[str, int]] = {
            'hazard_type': {},
            'desc_bucket': {},
        }
        invalid_feats: Dict[str, Dict[str, int]] = {
            'hazard_type': {},
            'desc_bucket': {},
        }

        for r in training_data:
            ht = r.get('hazard_type', 'unknown')
            desc_len = r.get('description_length', len(r.get('description', '')))
            bucket = _bucket_desc_len(desc_len)

            target = valid_feats if r.get('valid') else invalid_feats
            target['hazard_type'][ht] = target['hazard_type'].get(ht, 0) + 1
            target['desc_bucket'][bucket] = target['desc_bucket'].get(bucket, 0) + 1

        self._feature_likelihood = {
            'valid': {**valid_feats, 'valid_total': valid_count, 'invalid_total': total - valid_count},
            'invalid': {**invalid_feats, 'valid_total': valid_count, 'invalid_total': total - valid_count},
        }
        self._trained = True

    def validate_report(self, report_data: Dict[str, Any]) -> float:
        """
        Compute P(valid | hazard_type, description).

        Primary path: sklearn MultinomialNB via ml_service (CountVectorizer on full text).
        Fallback: manual Bayes on hazard_type + description_length bucket.

        Parameters
        ----------
        report_data : dict with keys:
            - hazard_type        (str)
            - description        (str, optional)
            - description_length (int, optional)

        Returns
        -------
        float in [0, 1] — probability the report is valid based on text features.

        # Using synthetic training data (temporary)
        # Replace with MDRRMO historical data when available
        """
        hazard_type = report_data.get('hazard_type', 'other') or 'other'
        description = report_data.get('description', '') or ''
        is_other = hazard_type.lower() == 'other'

        # For 'other' type, replace the type token with 'unknown_hazard' so that
        # Laplace smoothing provides a neutral prior instead of the misleadingly
        # balanced 'other' distribution from training data.
        nb_type = 'unknown_hazard' if is_other else hazard_type

        # ── Primary: sklearn MultinomialNB via ml_service ─────────────────────
        try:
            from ml_data.ml_service import get_ml_service
            score = get_ml_service().predict_naive_bayes(nb_type, description)
            if score is not None:
                if is_other:
                    keyword_score = _keyword_match_score(description)
                    return round((score * 0.6) + (keyword_score * 0.4), 4)
                return score
        except Exception as e:
            logger.warning('ml_service NB unavailable, using fallback: %s', e)

        # ── Fallback: classic manual Bayes (hazard_type + desc_length bucket) ─
        if not self._trained:
            self.train()

        desc_len = report_data.get('description_length', len(description))
        bucket = _bucket_desc_len(desc_len)

        p_valid = self._class_prior.get('valid', 0.5)
        p_invalid = self._class_prior.get('invalid', 0.5)
        v = self._feature_likelihood.get('valid', {})
        inv = self._feature_likelihood.get('invalid', {})
        k = 0.5  # Laplace smoothing factor

        def lik(d: dict, key: str, val: str) -> float:
            counts = d.get(key, {})
            total = sum(counts.values()) or 1
            return (counts.get(val, 0) + k) / (total + k * len(counts.keys() or [val]))

        v_ht   = lik(v,   'hazard_type', nb_type)
        v_desc = lik(v,   'desc_bucket', bucket)
        i_ht   = lik(inv, 'hazard_type', nb_type)
        i_desc = lik(inv, 'desc_bucket', bucket)

        post_valid   = p_valid   * v_ht * v_desc
        post_invalid = p_invalid * i_ht * i_desc
        total = post_valid + post_invalid
        base_score = (post_valid / total) if total else 0.5

        if is_other:
            keyword_score = _keyword_match_score(description)
            return round((base_score * 0.6) + (keyword_score * 0.4), 4)

        return base_score


def nearby_count_to_category(count: int) -> str:
    """Used outside NB for breakdown labels; not an NB feature."""
    return _bucket_nearby_count(count)
