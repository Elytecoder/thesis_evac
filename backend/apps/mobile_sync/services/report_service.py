"""
Service for hazard report submission: Naive Bayes -> Consensus -> save.
"""
from apps.hazards.models import HazardReport
from apps.validation.services import NaiveBayesValidator, ConsensusScoringService


def process_new_report(user, hazard_type: str, latitude, longitude, description: str = '', photo_url: str = '') -> HazardReport:
    """
    Create report, run Naive Bayes validation, run consensus scoring, save and return report.
    """
    report = HazardReport.objects.create(
        user=user,
        hazard_type=hazard_type,
        latitude=latitude,
        longitude=longitude,
        description=description or '',
        photo_url=photo_url or '',
        status=HazardReport.Status.PENDING,
    )
    nb = NaiveBayesValidator()
    nb.train()
    report.naive_bayes_score = nb.validate_report({
        'hazard_type': hazard_type,
        'description': description,
        'description_length': len(description or ''),
    })
    consensus = ConsensusScoringService()
    nearby = consensus.count_nearby_reports(
        float(report.latitude), float(report.longitude),
        HazardReport.objects.exclude(id=report.id),
        exclude_report_id=report.id,
    )
    report.consensus_score = consensus.combined_score(report.naive_bayes_score, nearby)
    report.save(update_fields=['naive_bayes_score', 'consensus_score'])
    return report
