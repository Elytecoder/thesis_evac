# URLField max_length=200 truncates data URLs and long storage URLs.

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("hazards", "0006_alter_hazardreport_options"),
    ]

    operations = [
        migrations.AlterField(
            model_name="hazardreport",
            name="photo_url",
            field=models.TextField(blank=True),
        ),
        migrations.AlterField(
            model_name="hazardreport",
            name="video_url",
            field=models.TextField(blank=True),
        ),
    ]
