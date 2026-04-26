"""Add fcm_token field to User for Firebase Cloud Messaging push notifications."""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0010_seed_mdrrmo_user'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='fcm_token',
            field=models.CharField(blank=True, default='', max_length=255),
        ),
    ]
