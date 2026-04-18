from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('hazards', '0010_hazardconfirmation'),
    ]

    operations = [
        migrations.AddField(
            model_name='hazardreport',
            name='is_deleted',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='hazardreport',
            name='deleted_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
