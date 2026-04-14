"""
Django management command: train_ml_models

Generates synthetic datasets (if not present) and trains both ML models:
    1. Naive Bayes  — for hazard report validation scoring
    2. Random Forest — for road segment risk prediction

# Using synthetic training data (temporary)
# Replace with MDRRMO historical data when available

Usage:
    python manage.py train_ml_models
    python manage.py train_ml_models --force   # regenerate CSV and retrain
    python manage.py train_ml_models --nb-only
    python manage.py train_ml_models --rf-only
"""
from django.core.management.base import BaseCommand
from pathlib import Path

ML_DATA_DIR = Path(__file__).resolve().parents[4] / 'ml_data'


class Command(BaseCommand):
    help = (
        'Train Naive Bayes (report validation) and Random Forest (road risk) '
        'from synthetic datasets. '
        'Using synthetic training data (temporary) — '
        'replace with MDRRMO historical data when available.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Delete existing CSV datasets and regenerate before training.',
        )
        parser.add_argument(
            '--nb-only',
            action='store_true',
            help='Train only the Naive Bayes model.',
        )
        parser.add_argument(
            '--rf-only',
            action='store_true',
            help='Train only the Random Forest model.',
        )

    def handle(self, *args, **options):
        force    = options['force']
        nb_only  = options['nb_only']
        rf_only  = options['rf_only']
        run_nb   = not rf_only
        run_rf   = not nb_only

        self.stdout.write(
            '\n=== ML Model Training ===\n'
            '# Using synthetic training data (temporary)\n'
            '# Replace with MDRRMO historical data when available\n'
        )

        import sys
        sys.path.insert(0, str(ML_DATA_DIR.parent))

        if run_nb:
            self._train_nb(force)
        if run_rf:
            self._train_rf(force)

        self.stdout.write(self.style.SUCCESS('\nAll requested models trained successfully.'))
        self.stdout.write(
            'Models are stored in: '
            + str(ML_DATA_DIR / 'models') + '\n'
        )

    def _train_nb(self, force: bool) -> None:
        self.stdout.write('--- Naive Bayes ---')
        try:
            from ml_data.train_naive_bayes import train_and_save, CSV_PATH
            if force and CSV_PATH.exists():
                try:
                    CSV_PATH.unlink()
                    self.stdout.write(f'  Removed existing dataset: {CSV_PATH.name}')
                except PermissionError:
                    self.stdout.write(
                        f'  Note: {CSV_PATH.name} is open in editor — '
                        'training from existing data instead.'
                    )
            train_and_save()
            self.stdout.write(self.style.SUCCESS('  [OK] Naive Bayes trained and saved'))
        except Exception as e:
            self.stderr.write(self.style.ERROR(f'  [FAIL] Naive Bayes training failed: {e}'))

    def _train_rf(self, force: bool) -> None:
        self.stdout.write('--- Random Forest ---')
        try:
            from ml_data.train_random_forest import train_and_save, CSV_PATH
            if force and CSV_PATH.exists():
                try:
                    CSV_PATH.unlink()
                    self.stdout.write(f'  Removed existing dataset: {CSV_PATH.name}')
                except PermissionError:
                    self.stdout.write(
                        f'  Note: {CSV_PATH.name} is open in editor — '
                        'training from in-memory data instead.'
                    )
            train_and_save()
            self.stdout.write(self.style.SUCCESS('  [OK] Random Forest trained and saved'))
        except Exception as e:
            self.stderr.write(self.style.ERROR(f'  [FAIL] Random Forest training failed: {e}'))
            return

        # After RF retraining, refresh segment risk scores automatically
        self.stdout.write('  Refreshing segment risk scores ...')
        try:
            from apps.mobile_sync.services.route_service import recompute_all_segment_risks
            from apps.routing.models import RoadSegment
            recompute_all_segment_risks()
            count = RoadSegment.objects.count()
            self.stdout.write(self.style.SUCCESS(f'  [OK] {count} segment risk scores updated'))
        except Exception as e:
            self.stdout.write(f'  Note: segment risk update skipped ({e})')
