"""
Data migration: seed the MDRRMO admin account on a fresh database.

This runs exactly ONCE per database (Django records it in django_migrations).
If the admin later changes their password via Settings > Change Password,
this migration is already marked as applied and will NOT reset the password.

Default login:
  email   : admin@mdrrmo.bulan.gov.ph
  password: Admin@1234
"""
import secrets
from django.db import migrations
from django.contrib.auth.hashers import make_password


def _unique_six_digit(User):
    """Generate a unique 6-digit public_display_id not yet used in the table."""
    used = set(User.objects.values_list('public_display_id', flat=True))
    for _ in range(100):
        n = secrets.randbelow(900_000) + 100_000
        if n not in used:
            return n
    raise RuntimeError('Could not allocate a unique public_display_id')


def seed_mdrrmo_admin(apps, schema_editor):
    User = apps.get_model('users', 'User')

    # Only create if not already present — never overwrite an existing account.
    if not User.objects.filter(email='admin@mdrrmo.bulan.gov.ph').exists():
        User.objects.create(
            username='mdrrmo_admin',
            email='admin@mdrrmo.bulan.gov.ph',
            password=make_password('Admin@1234'),
            role='mdrrmo',
            full_name='MDRRMO Administrator',
            barangay='Poblacion',
            municipality='Bulan',
            province='Sorsogon',
            email_verified=True,
            is_active=True,
            is_suspended=False,
            public_display_id=_unique_six_digit(User),
        )


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0009_user_email_unique'),
    ]

    operations = [
        migrations.RunPython(seed_mdrrmo_admin, noop),
    ]
