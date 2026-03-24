"""Normalize barangay strings for consistent storage and filtering."""


def normalize_barangay_label(raw: str) -> str:
    """
    Trim whitespace, collapse internal spaces, apply title case.
    Used so "ZONE 1", "zone 1", and "  Zone  1  " match.
    """
    if not raw:
        return ''
    s = ' '.join(str(raw).split())
    return s.title()
