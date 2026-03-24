# One-time normalize evacuation center barangay labels.

from django.db import migrations


def forwards(apps, schema_editor):
    EvacuationCenter = apps.get_model('evacuation', 'EvacuationCenter')

    def norm(raw):
        if not raw:
            return ''
        s = ' '.join(str(raw).split())
        return s.title()

    for row in EvacuationCenter.objects.exclude(barangay='').iterator():
        nb = norm(row.barangay)
        if row.barangay != nb:
            EvacuationCenter.objects.filter(pk=row.pk).update(barangay=nb)


class Migration(migrations.Migration):

    dependencies = [
        ('evacuation', '0003_evacuationcenter_barangay_and_more'),
    ]

    operations = [
        migrations.RunPython(forwards, migrations.RunPython.noop),
    ]
