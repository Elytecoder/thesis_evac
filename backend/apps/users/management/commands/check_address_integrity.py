"""
Management command: check_address_integrity

Scans User and EvacuationCenter records for address data issues:
  - blank municipality or barangay
  - municipality not in the official Sorsogon list
  - barangay not belonging to its saved municipality

Usage:
    python manage.py check_address_integrity          # report only
    python manage.py check_address_integrity --fix    # auto-normalise case mismatches
"""

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from apps.users.barangay_utils import (
    canonical_municipality,
    canonical_barangay,
    normalize_barangay_label,
    normalize_municipality_label,
    SORSOGON_MUNICIPALITIES,
)

User = get_user_model()


class Command(BaseCommand):
    help = "Audit and optionally fix municipality/barangay data integrity."

    def add_arguments(self, parser):
        parser.add_argument(
            "--fix",
            action="store_true",
            default=False,
            help="Auto-fix obvious case-normalisation issues (safe, non-destructive).",
        )

    def handle(self, *args, **options):
        fix = options["fix"]
        self.stdout.write(self.style.MIGRATE_HEADING("=== Address Integrity Audit ===\n"))

        self._audit_users(fix)
        self._audit_evacuation_centers(fix)

        self.stdout.write(self.style.SUCCESS("\nAudit complete."))

    # ── Users ──────────────────────────────────────────────────────────────

    def _audit_users(self, fix: bool) -> None:
        self.stdout.write(self.style.HTTP_INFO("\n[Users]"))
        users = User.objects.exclude(role="mdrrmo").only(
            "id", "email", "municipality", "barangay"
        )
        blank_muni = blank_brgy = wrong_combo = fixed = 0

        for u in users:
            muni = (u.municipality or "").strip()
            brgy = (u.barangay or "").strip()

            if not muni:
                blank_muni += 1
                self.stdout.write(
                    f"  BLANK_MUNI  user_id={u.id} email={u.email}"
                )
                continue

            if not brgy:
                blank_brgy += 1
                self.stdout.write(
                    f"  BLANK_BRGY  user_id={u.id} email={u.email} municipality={muni}"
                )
                continue

            canonical_m = canonical_municipality(muni)
            canonical_b = canonical_barangay(brgy, muni) if canonical_m else None

            if canonical_m and canonical_m != muni:
                self.stdout.write(
                    f"  CASE_MUNI   user_id={u.id}  '{muni}' → '{canonical_m}'"
                )
                if fix:
                    User.objects.filter(pk=u.pk).update(municipality=canonical_m)
                    fixed += 1

            if canonical_b and canonical_b != brgy:
                self.stdout.write(
                    f"  CASE_BRGY   user_id={u.id}  '{brgy}' → '{canonical_b}'"
                )
                if fix:
                    User.objects.filter(pk=u.pk).update(barangay=canonical_b)
                    fixed += 1

            if canonical_m is None:
                self.stdout.write(
                    f"  UNKNOWN_MUNI user_id={u.id}  municipality='{muni}'"
                )
            elif canonical_b is None:
                wrong_combo += 1
                self.stdout.write(
                    f"  WRONG_COMBO  user_id={u.id}  municipality='{muni}'  barangay='{brgy}'"
                )

        self.stdout.write(
            f"  Summary — blank_municipality={blank_muni}  blank_barangay={blank_brgy}"
            f"  wrong_combo={wrong_combo}  fixed={fixed}"
        )

    # ── Evacuation Centers ─────────────────────────────────────────────────

    def _audit_evacuation_centers(self, fix: bool) -> None:
        self.stdout.write(self.style.HTTP_INFO("\n[Evacuation Centers]"))
        try:
            from apps.evacuation.models import EvacuationCenter  # noqa: PLC0415
        except ImportError:
            self.stdout.write("  (evacuation app not found — skipped)")
            return

        centers = EvacuationCenter.objects.only("id", "name", "municipality", "barangay")
        blank_muni = blank_brgy = wrong_combo = fixed = 0

        for ec in centers:
            muni = (ec.municipality or "").strip()
            brgy = (ec.barangay or "").strip()

            if not muni:
                blank_muni += 1
                self.stdout.write(f"  BLANK_MUNI  center_id={ec.id} name={ec.name}")
                continue

            if not brgy:
                blank_brgy += 1
                self.stdout.write(
                    f"  BLANK_BRGY  center_id={ec.id} name={ec.name} municipality={muni}"
                )
                continue

            canonical_m = canonical_municipality(muni)
            canonical_b = canonical_barangay(brgy, muni) if canonical_m else None

            if canonical_m and canonical_m != muni:
                self.stdout.write(
                    f"  CASE_MUNI   center_id={ec.id}  '{muni}' → '{canonical_m}'"
                )
                if fix:
                    EvacuationCenter.objects.filter(pk=ec.pk).update(municipality=canonical_m)
                    fixed += 1

            if canonical_b and canonical_b != brgy:
                self.stdout.write(
                    f"  CASE_BRGY   center_id={ec.id}  '{brgy}' → '{canonical_b}'"
                )
                if fix:
                    EvacuationCenter.objects.filter(pk=ec.pk).update(barangay=canonical_b)
                    fixed += 1

            if canonical_m is None:
                self.stdout.write(
                    f"  UNKNOWN_MUNI center_id={ec.id}  municipality='{muni}'"
                )
            elif canonical_b is None:
                wrong_combo += 1
                self.stdout.write(
                    f"  WRONG_COMBO  center_id={ec.id}  municipality='{muni}'  barangay='{brgy}'"
                )

        self.stdout.write(
            f"  Summary — blank_municipality={blank_muni}  blank_barangay={blank_brgy}"
            f"  wrong_combo={wrong_combo}  fixed={fixed}"
        )
