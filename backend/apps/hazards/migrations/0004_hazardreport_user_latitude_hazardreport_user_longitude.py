# Generated migration: add user_latitude, user_longitude, auto_rejected, and restoration-related fields

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("hazards", "0003_hazardreport_admin_comment_hazardreport_video_url"),
    ]

    operations = [
        migrations.AddField(
            model_name="hazardreport",
            name="user_latitude",
            field=models.DecimalField(blank=True, decimal_places=7, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name="hazardreport",
            name="user_longitude",
            field=models.DecimalField(blank=True, decimal_places=7, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name="hazardreport",
            name="auto_rejected",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="hazardreport",
            name="restoration_reason",
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name="hazardreport",
            name="restored_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="hazardreport",
            name="rejected_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="hazardreport",
            name="deletion_scheduled_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
