# Generated manually: unique 6-digit public references for hazard reports (MDRMMO display).

import secrets

from django.db import migrations, models


def backfill_public_references(apps, schema_editor):
    HazardReport = apps.get_model('hazards', 'HazardReport')
    used = set(
        HazardReport.objects.exclude(public_reference__isnull=True).values_list(
            'public_reference', flat=True
        )
    )
    for row in HazardReport.objects.filter(public_reference__isnull=True).iterator():
        for _ in range(80):
            c = secrets.randbelow(900_000) + 100_000
            if c not in used:
                used.add(c)
                HazardReport.objects.filter(pk=row.pk).update(public_reference=c)
                break


class Migration(migrations.Migration):

    dependencies = [
        ('hazards', '0007_alter_hazardreport_photo_url_video_url_textfield'),
    ]

    operations = [
        migrations.AddField(
            model_name='hazardreport',
            name='public_reference',
            field=models.PositiveIntegerField(blank=True, null=True, unique=True),
        ),
        migrations.RunPython(backfill_public_references, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='hazardreport',
            name='public_reference',
            field=models.PositiveIntegerField(unique=True),
        ),
    ]
