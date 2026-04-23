"""
Add a DB-level UNIQUE constraint on the email field.

The application layer already rejects duplicate emails, but a race condition
(two simultaneous registrations) could bypass that check. This migration
enforces uniqueness at the database level.

Safe to run on an existing database: Django will raise IntegrityError if
duplicates already exist, which would need to be resolved first.
"""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0008_password_reset_code'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='email',
            field=models.EmailField(
                max_length=254,
                unique=True,
                verbose_name='email address',
            ),
        ),
    ]
