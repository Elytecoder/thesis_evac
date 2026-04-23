"""
Service for hazard report submission.

Flow: create report -> if user-hazard distance > 150 m then auto-reject ->
else Naive Bayes (text features only) + rule scoring (distance weight,
consensus) -> combined final_validation_score -> PENDING for MDRRMO.

MDRRMO approves or rejects; no auto-approve.

Random Forest is used only for road segment risk prediction (routing),
not report validation.
"""
from apps.hazards.models import HazardReport
from apps.validation.services.naive_bayes import NaiveBayesValidator, nearby_count_to_category
from apps.validation.services.consensus import ConsensusScoringService
from apps.validation.services.rule_scoring import (
    combine_validation_scores,
    consensus_rule_score,
    reporter_proximity_weight,
)
from reports.utils import distance_km_to_category, should_auto_reject_report


def _build_explanation(
    hazard_type: str,
    distance_m: float | None,
    distance_category: str,
    nb_score: float,
    confirmation_count: int,
    nearby_count: int,
    final_score: float,
) -> str:
    """
    Generate a plain-English explanation of the validation result for MDRRMO.
    Each contributing factor is listed with its observed value.
    """
    lines = []

    # Naive Bayes confidence
    if nb_score >= 0.75:
        lines.append(f"Common hazard type reported with a detailed description ({hazard_type.replace('_', ' ').title()})")
    elif nb_score >= 0.5:
        lines.append(f"Hazard type ({hazard_type.replace('_', ' ').title()}) is moderately consistent with known valid reports")
    else:
        lines.append(f"Hazard type ({hazard_type.replace('_', ' ').title()}) is uncommon or description is too brief")

    # Distance / proximity
    if distance_m is not None:
        if distance_category == 'very_near':
            lines.append(f"Reporter is very close to the hazard ({distance_m:.0f} m) — high confidence they witnessed it")
        elif distance_category == 'near':
            lines.append(f"Reporter is near the hazard ({distance_m:.0f} m)")
        elif distance_category == 'moderate':
            lines.append(f"Reporter is within the acceptable radius ({distance_m:.0f} m)")
        else:
            lines.append(f"Reporter distance ({distance_m:.0f} m) is at the edge of the acceptable range")
    else:
        lines.append("Reporter location was not provided; proximity could not be verified")

    # Consensus
    total_support = nearby_count + confirmation_count
    if total_support == 0:
        lines.append("No other reports or confirmations for this incident yet")
    elif total_support == 1:
        lines.append(f"1 supporting signal ({nearby_count} nearby report(s) + {confirmation_count} confirmation(s))")
    else:
        lines.append(f"Multiple supporting signals: {nearby_count} nearby same-type report(s) and {confirmation_count} confirmation(s)")

    # Overall summary
    if final_score >= 0.75:
        summary = "Overall: HIGH confidence — report is very likely valid."
    elif final_score >= 0.5:
        summary = "Overall: MODERATE confidence — report appears credible but verification is recommended."
    else:
        summary = "Overall: LOW confidence — manual review and on-site verification is advised."

    return (
        "This report has a confidence score of {:.0f}% based on:\n• ".format(final_score * 100)
        + "\n• ".join(lines)
        + "\n\n" + summary
    )


def process_new_report(
    user,
    hazard_type: str,
    latitude,
    longitude,
    description: str = '',
    photo_url: str = '',
    video_url: str = '',
    user_latitude=None,
    user_longitude=None,
    client_submission_id: str | None = None,
) -> HazardReport:
    """
    Create report, run NB (type + description only) and separate rule scores,
    combine into final_validation_score, save breakdown for MDRRMO.
    """
    report = HazardReport.objects.create(
        user=user,
        hazard_type=hazard_type,
        latitude=latitude,
        longitude=longitude,
        description=description or '',
        photo_url=photo_url or '',
        video_url=video_url or '',
        status=HazardReport.Status.PENDING,
        user_latitude=user_latitude,
        user_longitude=user_longitude,
        client_submission_id=client_submission_id or None,
    )

    # Step 1: Proximity check — auto-reject if user is > 150 m from hazard.
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
        distance_km_val = float(distance_km)
        distance_m_val = distance_km_val * 1000
        distance_category = distance_km_to_category(distance_km_val)
        distance_weight = reporter_proximity_weight(distance_km_val)
    else:
        distance_km_val = None
        distance_m_val = None
        distance_category = 'unknown'
        distance_weight = 0.0

    # Step 2: Consensus — count nearby reports of the SAME hazard_type that
    # are PENDING or APPROVED, within 100 m, submitted in the last hour.
    consensus = ConsensusScoringService()
    nearby = consensus.count_nearby_reports(
        float(report.latitude), float(report.longitude),
        HazardReport.objects.exclude(id=report.id),
        exclude_report_id=report.id,
        time_window_hours=1,
        hazard_type=hazard_type,
    )
    nearby_category = nearby_count_to_category(nearby)
    confirmation_count = report.confirmation_count
    consensus_score_val = consensus_rule_score(nearby, confirmation_count)

    # Step 3: Naive Bayes — text / classification features only.
    nb = NaiveBayesValidator()
    nb.train()
    probability = nb.validate_report({
        'hazard_type': hazard_type,
        'description': description,
        'description_length': len(description or ''),
    })

    # Step 4: Weighted final score.
    final_score = combine_validation_scores(probability, distance_weight, consensus_score_val)

    # Step 5: Build human-readable explanation for MDRRMO officer.
    explanation = _build_explanation(
        hazard_type=hazard_type,
        distance_m=distance_m_val,
        distance_category=distance_category,
        nb_score=probability,
        confirmation_count=confirmation_count,
        nearby_count=nearby,
        final_score=final_score,
    )

    report.naive_bayes_score = probability
    report.distance_weight = distance_weight
    report.consensus_score = consensus_score_val
    report.final_validation_score = final_score
    report.status = HazardReport.Status.PENDING

    desc_len = len(description or '')
    desc_bucket = 'short' if desc_len < 20 else ('medium' if desc_len < 60 else 'long')

    report.validation_breakdown = {
        # Core scores (always present)
        'naive_bayes_score': round(probability, 4),
        'distance_weight': round(distance_weight, 4),
        'consensus_score': round(consensus_score_val, 4),
        'final_validation_score': round(final_score, 4),
        # Score weights applied
        'score_weights': {
            'naive_bayes': 0.5,
            'distance': 0.3,
            'consensus': 0.2,
        },
        # System decision (always PENDING — MDRRMO makes final call)
        'system_decision': 'pending',
        # Distance details
        'distance_km': round(distance_km_val, 4) if distance_km_val is not None else None,
        'distance_meters': round(distance_m_val, 0) if distance_m_val is not None else None,
        'distance_category': distance_category,
        'proximity_limit_meters': 150,
        # Description details
        'description_length': desc_len,
        'description_category': desc_bucket,
        # Consensus details
        'nearby_count': nearby,
        'nearby_category': nearby_category,
        'confirmation_count': confirmation_count,
        'consensus_radius_meters': 100,
        # Plain-English explanation for MDRRMO
        'explanation': explanation,
    }
    report.save(update_fields=[
        'naive_bayes_score',
        'distance_weight',
        'consensus_score',
        'final_validation_score',
        'status',
        'validation_breakdown',
    ])
    return report
