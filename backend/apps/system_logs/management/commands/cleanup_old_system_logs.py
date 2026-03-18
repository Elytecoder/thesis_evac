"""
Management command to delete system logs older than the configured retention period.

RETENTION:
- Configure SYSTEM_LOG_RETENTION_DAYS in settings (default 90). Set to 0 to keep forever.
- Logs with created_at older than (now - retention_days) are deleted.
- Run manually or via cron/celery for automatic cleanup.

RUN:
  python manage.py cleanup_old_system_logs
  python manage.py cleanup_old_system_logs --days 30
  python manage.py cleanup_old_system_logs --dry-run

EXAMPLE CRON (daily at 3 AM):
  0 3 * * * cd /path/to/project && python manage.py cleanup_old_system_logs
"""
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.conf import settings

from apps.system_logs.models import SystemLog


class Command(BaseCommand):
    help = 'Delete system logs older than SYSTEM_LOG_RETENTION_DAYS (or --days)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--days',
            type=int,
            default=None,
            help='Override retention: delete logs older than this many days (ignored if 0 in settings and not provided)',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be deleted without deleting',
        )

    def handle(self, *args, **options):
        retention = getattr(settings, 'SYSTEM_LOG_RETENTION_DAYS', 90)
        days = options['days'] if options['days'] is not None else retention
        dry_run = options['dry_run']

        if days <= 0:
            self.stdout.write(
                self.style.WARNING('Retention is 0 or negative; no logs will be deleted.')
            )
            return

        cutoff = timezone.now() - timezone.timedelta(days=days)
        qs = SystemLog.objects.filter(created_at__lt=cutoff)
        count = qs.count()

        if count == 0:
            self.stdout.write(self.style.SUCCESS('No system logs older than %s days.' % days))
            return

        if dry_run:
            self.stdout.write(
                self.style.WARNING(
                    'DRY RUN: Would delete %s system log(s) older than %s days (before %s).'
                    % (count, days, cutoff.isoformat())
                )
            )
            return

        qs.delete()
        self.stdout.write(
            self.style.SUCCESS('Deleted %s system log(s) older than %s days.' % (count, days))
        )
