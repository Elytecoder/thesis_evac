"""
Proximity validation utilities for hazard reports.

Validates that the user's location is within an acceptable radius of the reported hazard location.
This prevents false reports from users who are far from the actual hazard site.
"""
from math import radians, cos, sin, asin, sqrt


# ACCEPTED_RADIUS: Maximum distance (in kilometers) between user location and hazard location
# Reports with user location beyond this radius will be AUTO-REJECTED
ACCEPTED_RADIUS_KM = 1.0  # 1 kilometer


def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Calculate distance between two coordinates using Haversine formula.
    
    Args:
        lat1, lon1: First coordinate (user location)
        lat2, lon2: Second coordinate (hazard location)
    
    Returns:
        Distance in kilometers
    """
    # Convert decimal degrees to radians
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    
    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    
    # Radius of earth in kilometers
    r = 6371
    
    return c * r


def validate_user_proximity(user_lat, user_lon, hazard_lat, hazard_lon):
    """
    Validate that user is within acceptable radius of reported hazard.
    
    IMPORTANT: This is a critical validation step to ensure report authenticity.
    Users must be physically near the hazard to report it.
    
    Args:
        user_lat, user_lon: User's current location
        hazard_lat, hazard_lon: Reported hazard location
    
    Returns:
        tuple: (is_valid: bool, distance_km: float, message: str)
            - is_valid: True if within radius, False otherwise
            - distance_km: Actual distance between locations
            - message: Explanation message
    """
    # Calculate distance
    distance = calculate_distance(
        float(user_lat),
        float(user_lon),
        float(hazard_lat),
        float(hazard_lon)
    )
    
    # Check if within accepted radius
    if distance <= ACCEPTED_RADIUS_KM:
        return True, distance, f"User location verified (within {ACCEPTED_RADIUS_KM}km radius)"
    else:
        return False, distance, (
            f"Your location does not match the accepted kilometer radius "
            f"of the reported area. Distance: {distance:.2f}km "
            f"(maximum: {ACCEPTED_RADIUS_KM}km)"
        )


def should_auto_reject(user_lat, user_lon, hazard_lat, hazard_lon):
    """
    Determine if a report should be auto-rejected based on proximity.
    
    AUTO-REJECTION CRITERIA:
    - User location is more than ACCEPTED_RADIUS_KM from hazard location
    - This indicates the user is not at the scene and may be submitting false information
    
    Args:
        user_lat, user_lon: User's current location
        hazard_lat, hazard_lon: Reported hazard location
    
    Returns:
        tuple: (should_reject: bool, reason: str)
    """
    is_valid, distance, message = validate_user_proximity(
        user_lat, user_lon, hazard_lat, hazard_lon
    )
    
    if not is_valid:
        return True, message
    else:
        return False, ""
