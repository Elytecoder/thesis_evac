from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0006_user_email_index'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='user',
            name='phone_number',
        ),
    ]
