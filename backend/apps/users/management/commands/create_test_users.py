"""
Django management command to create / ensure test users exist.
Run: python manage.py create_test_users

Safe to run repeatedly — idempotent.
Re-enables any accidentally deactivated account and resets the password
to the known default so the demo always has working login credentials.
"""
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()

# Default credentials printed to Render deploy logs on every startup.
# MDRRMO admin can change this later via Settings > Change Password.
MDRRMO_EMAIL    = 'admin@mdrrmo.bulan.gov.ph'
MDRRMO_PASSWORD = 'Admin@1234'   # meets uppercase + digit + 8-char requirement

RESIDENT_PASSWORD = 'Resident@1'

class Command(BaseCommand):
    help = 'Create (or repair) demo users for development / thesis demo.'

    def handle(self, *args, **options):
        self._ensure_mdrrmo()
        self._ensure_residents()

        self.stdout.write(self.style.SUCCESS('\n[HAZNAV] Login credentials (use EMAIL):'))
        self.stdout.write(f'  MDRRMO Admin : {MDRRMO_EMAIL} / {MDRRMO_PASSWORD}')
        self.stdout.write( '  Resident 1   : resident1@gmail.com / Resident@1')
        self.stdout.write( '  Resident 2   : resident2@gmail.com / Resident@1')

    # ── helpers ────────────────────────────────────────────────────────────────

    def _ensure_mdrrmo(self):
        """Create MDRRMO admin if missing; repair if account is locked out."""
        user, created = User.objects.get_or_create(
            username='mdrrmo_admin',
            defaults=dict(
                email=MDRRMO_EMAIL,
                role='mdrrmo',
                full_name='MDRRMO Administrator',
                barangay='Poblacion',
                municipality='Bulan',
                province='Sorsogon',
                email_verified=True,
                is_active=True,
            ),
        )

        # Always set password on fresh PostgreSQL DB so the credentials work
        # even if a previous deploy seeded the account with a wrong password.
        user.set_password(MDRRMO_PASSWORD)
        user.email_verified = True
        user.is_active = True
        user.is_suspended = False
        user.save(update_fields=['password', 'email_verified', 'is_active', 'is_suspended'])

        if created:
            self.stdout.write(self.style.SUCCESS(
                f'[OK] MDRRMO admin created → {MDRRMO_EMAIL}'
            ))
        else:
            self.stdout.write(self.style.SUCCESS(
                f'[OK] MDRRMO admin verified → {MDRRMO_EMAIL}'
            ))

    def _ensure_residents(self):
        test_residents = [
            {
                'username': 'resident1',
                'email': 'resident1@gmail.com',
                'full_name': 'Juan Dela Cruz',
                'barangay': 'Zone 1',
            },
            {
                'username': 'resident2',
                'email': 'resident2@gmail.com',
                'full_name': 'Maria Santos',
                'barangay': 'Zone 2',
            },
        ]

        for data in test_residents:
            user, created = User.objects.get_or_create(
                username=data['username'],
                defaults=dict(
                    email=data['email'],
                    role='resident',
                    full_name=data['full_name'],
                    barangay=data['barangay'],
                    municipality='Bulan',
                    province='Sorsogon',
                    email_verified=True,
                    is_active=True,
                ),
            )
            user.set_password(RESIDENT_PASSWORD)
            user.email_verified = True
            user.is_active = True
            user.is_suspended = False
            user.save(update_fields=['password', 'email_verified', 'is_active', 'is_suspended'])

            label = 'created' if created else 'verified'
            self.stdout.write(self.style.SUCCESS(
                f"[OK] Resident {label} → {data['email']}"
            ))
