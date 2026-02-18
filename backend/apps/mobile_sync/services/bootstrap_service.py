"""
Bootstrap sync: return data for mobile app initial load (evacuation centers, baseline hazards).
TO REPLACE: When using real MDRRMO data, this can return cached/versioned payload and delta updates.
"""
from apps.evacuation.models import EvacuationCenter
from apps.hazards.models import BaselineHazard


def get_bootstrap_data():
    """
    Return dict with evacuation_centers and baseline_hazards for mobile cache.
    """
    centers = list(
        EvacuationCenter.objects.values('id', 'name', 'latitude', 'longitude', 'address', 'description')
    )
    hazards = list(
        BaselineHazard.objects.values('id', 'hazard_type', 'latitude', 'longitude', 'severity', 'source', 'created_at')
    )
    return {
        'evacuation_centers': centers,
        'baseline_hazards': hazards,
        'meta': {'source': 'mock', 'message': 'TO REPLACE: Use real MDRRMO cache when available.'},
    }
