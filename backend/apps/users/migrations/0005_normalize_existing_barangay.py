# One-time normalize barangay labels for consistent filtering.

from django.db import migrations


def forwards(apps, schema_editor):
    User = apps.get_model('users', 'User')
    # Inline to avoid import issues during migration
    def norm(raw):
        if not raw:
            return ''
        s = ' '.join(str(raw).split())
        return s.title()

    for row in User.objects.exclude(barangay='').iterator():
        nb = norm(row.barangay)
        if row.barangay != nb:
            User.objects.filter(pk=row.pk).update(barangay=nb)


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0004_user_public_display_id'),
    ]

    operations = [
        migrations.RunPython(forwards, migrations.RunPython.noop),
    ]
