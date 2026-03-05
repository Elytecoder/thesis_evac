"""
Management command to clean up rejected hazard reports after 15 days.

DATA RETENTION POLICY:
- Rejected reports are kept for 15 days to allow for restoration
- After 15 days, rejected reports are permanently deleted
- This keeps the database clean and maintains data privacy

RUN THIS COMMAND:
- Manually: python manage.py cleanup_rejected_reports
- Scheduled: Use cron job or Celery periodic task

EXAMPLE CRON (daily at 2 AM):
0 2 * * * cd /path/to/project && python manage.py cleanup_rejected_reports
"""
from django.core.management.base import BaseCommand
from django.utils import timezone
from apps.hazards.models import HazardReport


class Command(BaseCommand):
    help = 'Auto-delete rejected hazard reports after 15 days'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be deleted without actually deleting',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        now = timezone.now()
        
        # Find rejected reports scheduled for deletion
        # deletion_scheduled_at is set when report is rejected (current_time + 15 days)
        reports_to_delete = HazardReport.objects.filter(
            status=HazardReport.Status.REJECTED,
            deletion_scheduled_at__lte=now,  # Scheduled date has passed
        )
        
        count = reports_to_delete.count()
        
        if count == 0:
            self.stdout.write(self.style.SUCCESS('✅ No rejected reports to delete'))
            return
        
        if dry_run:
            self.stdout.write(self.style.WARNING(
                f'🔍 DRY RUN: Would delete {count} rejected reports:'
            ))
            for report in reports_to_delete:
                days_old = (now - report.rejected_at).days if report.rejected_at else 0
                self.stdout.write(
                    f'  - Report #{report.id} '
                    f'({report.hazard_type}) '
                    f'rejected {days_old} days ago'
                )
        else:
            # Get info before deletion
            deleted_info = [
                f'Report #{r.id} ({r.hazard_type})' 
                for r in reports_to_delete
            ]
            
            # Permanently delete
            reports_to_delete.delete()
            
            self.stdout.write(self.style.SUCCESS(
                f'✅ Deleted {count} rejected reports (15+ days old):'
            ))
            for info in deleted_info:
                self.stdout.write(f'  - {info}')
            
            self.stdout.write(self.style.WARNING(
                '⚠️  These reports have been permanently removed from the database'
            ))
