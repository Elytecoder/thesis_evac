# Generated manually: unique 6-digit public display IDs for MDRRMO UI.

import secrets

from django.db import migrations, models


def backfill_public_display_ids(apps, schema_editor):
    User = apps.get_model('users', 'User')
    used = set(
        User.objects.exclude(public_display_id__isnull=True).values_list(
            'public_display_id', flat=True
        )
    )
    for row in User.objects.filter(public_display_id__isnull=True).iterator():
        for _ in range(80):
            c = secrets.randbelow(900_000) + 100_000
            if c not in used:
                used.add(c)
                User.objects.filter(pk=row.pk).update(public_display_id=c)
                break


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0003_emailverificationcode_user_email_verified_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='public_display_id',
            field=models.PositiveIntegerField(blank=True, null=True, unique=True),
        ),
        migrations.RunPython(backfill_public_display_ids, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='user',
            name='public_display_id',
            field=models.PositiveIntegerField(unique=True),
        ),
    ]
