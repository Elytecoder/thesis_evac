"""
Data migration: seed the MDRRMO admin account on a fresh database.

This runs exactly ONCE per database (Django records it in django_migrations).
If the admin later changes their password via Settings > Change Password,
this migration is already marked as applied and will NOT reset the password.

Default login:
  email   : admin@mdrrmo.bulan.gov.ph
  password: Admin@1234
"""
from django.db import migrations
from django.contrib.auth.hashers import make_password


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
