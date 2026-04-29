"""
Resolve human-readable hazard location from latitude/longitude.

Uses OpenStreetMap Nominatim reverse geocoding with a short timeout.
Failures are handled gracefully (returns empty strings).
"""
from __future__ import annotations

import json
from functools import lru_cache
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from apps.users.barangay_utils import (
    normalize_barangay_label,
    normalize_municipality_label,
)


def _extract_municipality(address: dict) -> str:
    raw = (
        address.get('city')
        or address.get('municipality')
        or address.get('town')
        or address.get('village')
        or ''
    )
    return normalize_municipality_label(raw)


def _extract_barangay(address: dict) -> str:
    raw = (
        address.get('suburb')
        or address.get('quarter')
        or address.get('neighbourhood')
        or address.get('hamlet')
        or ''
    )
    return normalize_barangay_label(raw)


@lru_cache(maxsize=512)
def _reverse_geocode_cached(lat_rounded: float, lng_rounded: float) -> tuple[str, str, str]:
    params = urlencode({
        'lat': f'{lat_rounded:.6f}',
        'lon': f'{lng_rounded:.6f}',
        'format': 'jsonv2',
        'addressdetails': 1,
        'zoom': 18,
    })
    url = f'https://nominatim.openstreetmap.org/reverse?{params}'
    req = Request(
        url,
        headers={
            # Required by Nominatim usage policy.
            'User-Agent': 'HazNav/1.0 (thesis project contact: admin@haznav.local)',
        },
    )

    with urlopen(req, timeout=4) as resp:
        payload = json.loads(resp.read().decode('utf-8'))

    address = payload.get('address', {}) if isinstance(payload, dict) else {}
    location_address = (payload.get('display_name') or '').strip() if isinstance(payload, dict) else ''
    barangay = _extract_barangay(address)
    municipality = _extract_municipality(address)
    return location_address, barangay, municipality


def resolve_hazard_location(latitude: float, longitude: float) -> dict:
    """
    Best-effort location lookup for a hazard pin.
    Returns dict with keys: location_address, location_barangay, location_municipality.
    """
    try:
        lat = round(float(latitude), 6)
        lng = round(float(longitude), 6)
    except Exception:
        return {
            'location_address': '',
            'location_barangay': '',
            'location_municipality': '',
        }

    try:
        location_address, barangay, municipality = _reverse_geocode_cached(lat, lng)
    except Exception:
        location_address, barangay, municipality = '', '', ''

    return {
        'location_address': location_address,
        'location_barangay': barangay,
        'location_municipality': municipality,
    }

