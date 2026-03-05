# Generated migration: add validation_breakdown for Naive Bayes technical details display

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("hazards", "0004_hazardreport_user_latitude_hazardreport_user_longitude"),
    ]

    operations = [
        migrations.AddField(
            model_name="hazardreport",
            name="validation_breakdown",
            field=models.JSONField(blank=True, null=True),
        ),
    ]
