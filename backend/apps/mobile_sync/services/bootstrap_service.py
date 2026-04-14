"""
Bootstrap sync: return data for mobile app initial load (evacuation centers, baseline hazards).
TO REPLACE: When using real MDRRMO data, this can return cached/versioned payload and delta updates.
"""
from apps.evacuation.models import EvacuationCenter
from apps.hazards.models import BaselineHazard


def get_bootstrap_data():
    """
    Return dict with evacuation_centers and baseline_hazards for mobile cache.
    Only OPERATIONAL centers are included so the app never caches deactivated ones.
    is_operational and deactivated_at are included so the client model stays accurate.
    """
    centers = list(
        EvacuationCenter.objects.filter(is_operational=True).values(
            'id', 'name', 'latitude', 'longitude', 'address', 'description',
            'is_operational', 'deactivated_at',
        )
    )
    hazards = list(
        BaselineHazard.objects.values('id', 'hazard_type', 'latitude', 'longitude', 'severity', 'source', 'created_at')
    )
    return {
        'evacuation_centers': centers,
        'baseline_hazards': hazards,
        'meta': {'source': 'mock', 'message': 'TO REPLACE: Use real MDRRMO cache when available.'},
    }
