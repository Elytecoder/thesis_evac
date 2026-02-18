"""
Naive Bayes validation for crowdsourced hazard reports.
Trains on mock_training_data.json; outputs probability score for report validity.

TO REPLACE WITH REAL MDRRMO DATA:
1. Remove mock loader and load historical MDRRMO-verified reports (CSV/DB).
2. Use same feature schema (hazard_type, location, description_length, valid).
3. Call train() with real data, then persist model (e.g. joblib) if needed.
4. Re-run training when new verified data is available.
"""
import json
from pathlib import Path
from typing import Any

# Default path; overridden by Django settings when used in app
MOCK_TRAINING_PATH = Path(__file__).resolve().parent.parent.parent.parent / 'mock_data' / 'mock_training_data.json'


class NaiveBayesValidator:
    """
    Simple Naive Bayes classifier for report validation.
    Features: hazard_type, description_length (bucketed). Label: valid (bool).
    """

    def __init__(self):
        self._class_prior = {}  # P(valid)
        self._feature_likelihood = {}  # P(feature|valid)
        self._trained = False

    def _load_mock_training(self, path: Path = None) -> list:
        """
        Load training data from mock JSON.
        TO REPLACE: Load from DB or MDRRMO CSV instead.
        """
        path = path or MOCK_TRAINING_PATH
        if not path.exists():
            return []
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data.get('naive_bayes_training', [])

    def _bucket_desc_len(self, length: int) -> str:
        if length < 20:
            return 'short'
        if length < 60:
            return 'medium'
        return 'long'

    def train(self, training_data: list = None) -> None:
        """
        Train on list of dicts with keys: hazard_type, description_length (or lat, lng), valid.
        If training_data is None, loads from mock_training_data.json.
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

        # Count features per class
        valid_feats = {'hazard_type': {}, 'desc_bucket': {}}
        invalid_feats = {'hazard_type': {}, 'desc_bucket': {}}
        for r in training_data:
            ht = r.get('hazard_type', 'unknown')
            desc_len = r.get('description_length', 0)
            bucket = self._bucket_desc_len(desc_len)
            if r.get('valid'):
                valid_feats['hazard_type'][ht] = valid_feats['hazard_type'].get(ht, 0) + 1
                valid_feats['desc_bucket'][bucket] = valid_feats['desc_bucket'].get(bucket, 0) + 1
            else:
                invalid_feats['hazard_type'][ht] = invalid_feats['hazard_type'].get(ht, 0) + 1
                invalid_feats['desc_bucket'][bucket] = invalid_feats['desc_bucket'].get(bucket, 0) + 1

        # Laplace smoothing
        def likelihood(counts: dict, key: str, k: float = 0.5) -> float:
            total = sum(counts.values()) or 1
            return (counts.get(key, 0) + k) / (total + k * 10)

        self._feature_likelihood = {
            'valid': {'hazard_type': valid_feats['hazard_type'], 'desc_bucket': valid_feats['desc_bucket'],
                      'valid_total': valid_count, 'invalid_total': total - valid_count},
            'invalid': {'hazard_type': invalid_feats['hazard_type'], 'desc_bucket': invalid_feats['desc_bucket'],
                       'valid_total': valid_count, 'invalid_total': total - valid_count},
        }
        self._trained = True

    def validate_report(self, report_data: dict) -> float:
        """
        Return P(valid | report) as a score in [0, 1].
        report_data should have: hazard_type, description (text) or description_length.
        """
        if not self._trained:
            self.train()

        hazard_type = report_data.get('hazard_type', 'unknown')
        desc = report_data.get('description', '')
        desc_len = report_data.get('description_length', len(desc))
        bucket = self._bucket_desc_len(desc_len)

        p_valid = self._class_prior.get('valid', 0.5)
        p_invalid = self._class_prior.get('invalid', 0.5)

        v = self._feature_likelihood.get('valid', {})
        inv = self._feature_likelihood.get('invalid', {})
        # P(features | valid)
        v_ht = (v.get('hazard_type', {}).get(hazard_type, 0) + 0.5) / ((v.get('valid_total') or 0) + 2)
        v_bucket = (v.get('desc_bucket', {}).get(bucket, 0) + 0.5) / ((v.get('valid_total') or 0) + 2)
        # P(features | invalid)
        i_ht = (inv.get('hazard_type', {}).get(hazard_type, 0) + 0.5) / ((inv.get('invalid_total') or 0) + 2)
        i_bucket = (inv.get('desc_bucket', {}).get(bucket, 0) + 0.5) / ((inv.get('invalid_total') or 0) + 2)

        post_valid = p_valid * v_ht * v_bucket
        post_invalid = p_invalid * i_ht * i_bucket
        total = post_valid + post_invalid
        return (post_valid / total) if total else 0.5
