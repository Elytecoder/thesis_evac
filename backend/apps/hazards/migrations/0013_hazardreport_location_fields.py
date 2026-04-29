from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('hazards', '0012_hazardreport_client_submission_id'),
    ]

    operations = [
        migrations.AddField(
            model_name='hazardreport',
            name='location_address',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='hazardreport',
            name='location_barangay',
            field=models.CharField(blank=True, default='', max_length=100),
        ),
        migrations.AddField(
            model_name='hazardreport',
            name='location_municipality',
            field=models.CharField(blank=True, default='', max_length=100),
        ),
    ]
