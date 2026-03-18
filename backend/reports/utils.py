"""
Reports utility functions including proximity validation.

Validation is now fully handled by Naive Bayes with integrated proximity
and consensus features. Only extreme distance (>1 km) causes auto-reject.
"""
from math import radians, sin, cos, sqrt, atan2


# Reject report if user is more than this distance from hazard (extreme misuse protection).
PROXIMITY_REJECT_KM = 1.0

# Legacy alias for backward compatibility.
ACCEPTED_RADIUS_KM = PROXIMITY_REJECT_KM


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Return distance in kilometers between two WGS84 points."""
    EARTH_RADIUS_KM = 6371.0
    user_lat_rad = radians(lat1)
    user_lng_rad = radians(lng1)
    hazard_lat_rad = radians(lat2)
    hazard_lng_rad = radians(lng2)
    dlat = hazard_lat_rad - user_lat_rad
    dlng = hazard_lng_rad - user_lng_rad
    a = sin(dlat / 2) ** 2 + cos(user_lat_rad) * cos(hazard_lat_rad) * sin(dlng / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return EARTH_RADIUS_KM * c


def distance_km_to_category(distance_km: float) -> str:
    """
    Convert user-to-hazard distance into a category for Naive Bayes.
    Used only when distance_km <= PROXIMITY_REJECT_KM (no auto-reject).
    """
    if distance_km <= 0.05:   # 0–50 m
        return 'very_near'
    if distance_km <= 0.1:    # 50–100 m
        return 'near'
    if distance_km <= 0.2:    # 100–200 m
        return 'moderate'
    # 200 m – 1 km
    return 'far'


def validate_user_proximity(user_lat, user_lng, hazard_lat, hazard_lng):
    """
    Validate if user is within accepted radius of reported hazard location.
    
    Uses Haversine formula to calculate distance between two GPS coordinates.
    
    Args:
        user_lat: User's current latitude
        user_lng: User's current longitude
        hazard_lat: Reported hazard latitude
        hazard_lng: Reported hazard longitude
    
    Returns:
        tuple: (is_valid: bool, distance_km: float)
        - is_valid: True if user is within ACCEPTED_RADIUS_KM
        - distance_km: Actual distance in kilometers
    
    Example:
        is_valid, distance = validate_user_proximity(12.6699, 123.8758, 12.6750, 123.8800)
        if not is_valid:
            # Auto-reject report
            pass
    """
    distance_km = haversine_km(user_lat, user_lng, hazard_lat, hazard_lng)
    is_valid = distance_km <= PROXIMITY_REJECT_KM
    return is_valid, distance_km


def should_auto_reject_report(user_lat, user_lng, hazard_lat, hazard_lng):
    """
    Determine if a report should be auto-rejected based on proximity.
    
    This is called during report submission to validate user location.
    If user is too far from reported hazard location, report is auto-rejected.
    
    Args:
        user_lat: User's current latitude
        user_lng: User's current longitude
        hazard_lat: Reported hazard latitude
        hazard_lng: Reported hazard longitude
    
    Returns:
        tuple: (should_reject: bool, reason: str, distance_km: float)
    
    Example:
        should_reject, reason, distance = should_auto_reject_report(...)
        if should_reject:
            report.auto_rejected = True
            report.status = 'rejected'
            report.admin_comment = reason
    """
    is_valid, distance_km = validate_user_proximity(
        user_lat, user_lng, hazard_lat, hazard_lng
    )
    
    if not is_valid:
        reason = (
            f"Auto-rejected: User location is {distance_km:.2f} km away from reported hazard location. "
            f"Exceeds maximum of {PROXIMITY_REJECT_KM} km (extreme misuse protection)."
        )
        return True, reason, distance_km
    
    return False, None, distance_km
