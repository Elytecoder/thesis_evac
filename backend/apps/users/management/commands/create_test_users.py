"""
Django management command to create test users for development.
Run: python manage.py create_test_users
"""
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()


class Command(BaseCommand):
    help = 'Create test users for development'

    def handle(self, *args, **options):
        # Create MDRRMO admin if doesn't exist
        if not User.objects.filter(username='mdrrmo_admin').exists():
            mdrrmo = User.objects.create_user(
                username='mdrrmo_admin',
                email='admin@mdrrmo.bulan.gov.ph',
                password='admin123',
                role='mdrrmo',
                full_name='MDRRMO Administrator',
                phone_number='09171234567',
                barangay='Poblacion',
            )
            mdrrmo.email_verified = True
            mdrrmo.is_active = True
            mdrrmo.save(update_fields=['email_verified', 'is_active'])
            self.stdout.write(
                self.style.SUCCESS(
                    '[OK] Created MDRRMO user. Login with email: admin@mdrrmo.bulan.gov.ph / admin123'
                )
            )
        else:
            mdrrmo = User.objects.get(username='mdrrmo_admin')
            if not mdrrmo.email_verified or not mdrrmo.is_active:
                mdrrmo.email_verified = True
                mdrrmo.is_active = True
                mdrrmo.save(update_fields=['email_verified', 'is_active'])
                self.stdout.write(
                    self.style.SUCCESS(
                        '[OK] MDRRMO user activated. Login: admin@mdrrmo.bulan.gov.ph / admin123'
                    )
                )
            else:
                self.stdout.write(
                    self.style.WARNING('MDRRMO user already exists')
                )

        # Create test resident users if they don't exist
        test_residents = [
            {
                'username': 'resident1',
                'email': 'resident1@gmail.com',
                'password': 'resident123',
                'full_name': 'Juan Dela Cruz',
                'phone_number': '09171111111',
                'barangay': 'Zone 1',
            },
            {
                'username': 'resident2',
                'email': 'resident2@gmail.com',
                'password': 'resident123',
                'full_name': 'Maria Santos',
                'phone_number': '09172222222',
                'barangay': 'Zone 2',
            },
            {
                'username': 'test_resident',
                'email': 'test@example.com',
                'password': 'test123',
                'full_name': 'Test Resident',
                'phone_number': '09173333333',
                'barangay': 'Zone 3',
            },
        ]

        for data in test_residents:
            if not User.objects.filter(username=data['username']).exists():
                u = User.objects.create_user(
                    username=data['username'],
                    email=data['email'],
                    password=data['password'],
                    role='resident',
                    full_name=data['full_name'],
                    phone_number=data['phone_number'],
                    barangay=data['barangay'],
                )
                u.email_verified = True
                u.is_active = True
                u.save(update_fields=['email_verified', 'is_active'])
                self.stdout.write(
                    self.style.SUCCESS(
                        f"[OK] Created resident: {data['email']} / {data['password']}"
                    )
                )
            else:
                self.stdout.write(
                    self.style.WARNING(f"{data['username']} already exists")
                )

        self.stdout.write(
            self.style.SUCCESS('\n[SUCCESS] Test users setup complete!')
        )
        self.stdout.write('Login credentials (use EMAIL to log in):')
        self.stdout.write('  MDRRMO:   admin@mdrrmo.bulan.gov.ph / admin123')
        self.stdout.write('  Resident: resident1@gmail.com / resident123')
        self.stdout.write('  Resident: test_resident / test123')
