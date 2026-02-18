"""
Seed a few evacuation centers for development.
TO REPLACE: Import from MDRRMO or official source.
"""
from django.core.management.base import BaseCommand
from apps.evacuation.models import EvacuationCenter


class Command(BaseCommand):
    help = 'Create sample evacuation centers for testing.'

    def handle(self, *args, **options):
        data = [
            {'name': 'Barangay Hall Evacuation Center', 'latitude': 14.6040, 'longitude': 120.9870,
             'address': 'Sample St, Barangay', 'description': 'Primary evacuation center.'},
            {'name': 'School Gym Evacuation Center', 'latitude': 14.5960, 'longitude': 120.9790,
             'address': 'School Ave', 'description': 'Secondary evacuation center.'},
        ]
        for d in data:
            _, created = EvacuationCenter.objects.get_or_create(
                name=d['name'],
                defaults=d,
            )
            if created:
                self.stdout.write(self.style.SUCCESS(f"Created: {d['name']}"))
