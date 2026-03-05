"""
Service for hazard report submission.

Validation is now fully handled by Naive Bayes with integrated proximity
and consensus features. Flow: compute distance -> if >1 km reject ->
else extract features -> run Naive Bayes -> apply threshold -> save.

Random Forest is used only for road segment risk prediction and not for report validation.
Modified Dijkstra is used only for routing. Neither appears in report validation.
"""
from apps.hazards.models import HazardReport
from apps.validation.services.naive_bayes import NaiveBayesValidator, nearby_count_to_category
from apps.validation.services.consensus import ConsensusScoringService
from reports.utils import (
    haversine_km,
    distance_km_to_category,
    PROXIMITY_REJECT_KM,
    should_auto_reject_report,
)


# Decision thresholds: single Naive Bayes probability (no combined score).
AUTO_APPROVE_THRESHOLD = 0.8
PENDING_THRESHOLD = 0.5
# Below PENDING_THRESHOLD -> reject.


def process_new_report(
    user,
    hazard_type: str,
    latitude,
    longitude,
    description: str = '',
    photo_url: str = '',
    user_latitude=None,
    user_longitude=None,
) -> HazardReport:
    """
    Create report, run single-algorithm validation (Naive Bayes with proximity
    and nearby-count features), apply thresholds, save and return report.

    If user_latitude/user_longitude are provided and distance to hazard > 1 km,
    report is auto-rejected. Otherwise distance is converted to a category and
    fed into Naive Bayes. Nearby report count (50 m, 1 hr) is also a feature.
    """
    report = HazardReport.objects.create(
        user=user,
        hazard_type=hazard_type,
        latitude=latitude,
        longitude=longitude,
        description=description or '',
        photo_url=photo_url or '',
        status=HazardReport.Status.PENDING,
        user_latitude=user_latitude,
        user_longitude=user_longitude,
    )

    # Step 1: Extreme distance check (> 1 km -> auto reject).
    if user_latitude is not None and user_longitude is not None:
        should_reject, reason, distance_km = should_auto_reject_report(
            float(user_latitude), float(user_longitude),
            float(latitude), float(longitude),
        )
        if should_reject:
            report.status = HazardReport.Status.REJECTED
            report.auto_rejected = True
            report.admin_comment = reason
            report.save(update_fields=['status', 'auto_rejected', 'admin_comment'])
            return report
        distance_category = distance_km_to_category(distance_km)
    else:
        distance_category = 'unknown'

    # Step 2: Nearby similar reports count (50 m, 1 hr) -> category for Naive Bayes.
    consensus = ConsensusScoringService()
    nearby = consensus.count_nearby_reports(
        float(report.latitude), float(report.longitude),
        HazardReport.objects.exclude(id=report.id),
        exclude_report_id=report.id,
        time_window_hours=1,
    )
    nearby_category = nearby_count_to_category(nearby)

    # Step 3: Run Naive Bayes (single validation algorithm).
    nb = NaiveBayesValidator()
    nb.train()
    probability = nb.validate_report({
        'hazard_type': hazard_type,
        'description': description,
        'description_length': len(description or ''),
        'distance_category': distance_category,
        'nearby_similar_report_count_category': nearby_category,
    })
    report.naive_bayes_score = probability
    # No consensus_score or combined formula; validation is NB only.

    # Step 4: Apply decision thresholds.
    if probability >= AUTO_APPROVE_THRESHOLD:
        report.status = HazardReport.Status.APPROVED
        system_decision = 'auto_approved'
    elif probability < PENDING_THRESHOLD:
        report.status = HazardReport.Status.REJECTED
        system_decision = 'rejected'
    else:
        system_decision = 'pending'

    # Random Forest is used only for road segment risk prediction and not for report validation.
    # Build validation breakdown for MDRRMO technical details (Naive Bayes only).
    desc_len = len(description or '')
    desc_bucket = 'short' if desc_len < 20 else ('medium' if desc_len < 60 else 'long')
    distance_km_val = None
    if user_latitude is not None and user_longitude is not None:
        distance_km_val = haversine_km(
            float(user_latitude), float(user_longitude),
            float(latitude), float(longitude),
        )
    report.validation_breakdown = {
        'final_probability': round(probability, 4),
        'system_decision': system_decision,
        'distance_km': round(distance_km_val, 4) if distance_km_val is not None else None,
        'distance_meters': round(distance_km_val * 1000, 0) if distance_km_val is not None else None,
        'distance_category': distance_category,
        'description_length': desc_len,
        'description_category': desc_bucket,
        'nearby_count': nearby,
        'nearby_category': nearby_category,
    }
    report.save(update_fields=['naive_bayes_score', 'status', 'validation_breakdown'])
    return report
