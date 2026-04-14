from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0005_normalize_existing_barangay'),
    ]

    operations = [
        migrations.AddIndex(
            model_name='user',
            index=models.Index(fields=['email'], name='users_user_email_idx'),
        ),
    ]
