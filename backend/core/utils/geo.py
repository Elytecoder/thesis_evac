"""
Geographic utilities for distance and proximity.
Uses Haversine for meter-based radius checks.
"""
import math


def haversine_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Return distance in meters between two WGS84 points.
    """
    R = 6371000  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def within_radius(lat1: float, lon1: float, lat2: float, lon2: float, radius_m: float) -> bool:
    """True if (lat2, lon2) is within radius_m meters of (lat1, lon1)."""
    return haversine_meters(lat1, lon1, lat2, lon2) <= radius_m
