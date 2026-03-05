"""
Django management command to clean up rejected reports older than 15 days.

Usage:
    python manage.py cleanup_rejected_reports

This should be run as a scheduled task (cron job or Celery beat).

Data Retention Policy:
- Rejected reports are kept for 15 days
- After 15 days, they are permanently deleted
- This includes both manually rejected and auto-rejected reports
"""
from django.core.management.base import BaseCommand
from django.utils import timezone
from reports.models import HazardReport


class Command(BaseCommand):
    help = 'Auto-delete rejected reports after 15 days (data retention policy)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be deleted without actually deleting',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        
        # Find rejected reports that are past their deletion_scheduled_at date
        now = timezone.now()
        reports_to_delete = HazardReport.objects.filter(
            status='rejected',
            deletion_scheduled_at__lte=now,
        )
        
        count = reports_to_delete.count()
        
        if dry_run:
            self.stdout.write(
                self.style.WARNING(f'DRY RUN: Would delete {count} rejected reports')
            )
            for report in reports_to_delete:
                self.stdout.write(
                    f'  - Report #{report.id}: {report.hazard_type} '
                    f'(rejected on {report.rejected_at.date()})'
                )
        else:
            if count > 0:
                # Log what's being deleted
                self.stdout.write(f'Deleting {count} rejected reports...')
                for report in reports_to_delete:
                    self.stdout.write(
                        f'  - Deleting Report #{report.id}: {report.hazard_type} '
                        f'(rejected on {report.rejected_at.date()})'
                    )
                
                # Perform deletion
                reports_to_delete.delete()
                
                self.stdout.write(
                    self.style.SUCCESS(
                        f'Successfully deleted {count} rejected reports older than 15 days'
                    )
                )
            else:
                self.stdout.write(
                    self.style.SUCCESS('No rejected reports to delete')
                )
