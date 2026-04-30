from django.db import migrations, models


def approved_to_accepted(apps, schema_editor):
    ProductReview = apps.get_model('store', 'ProductReview')
    ProductReview.objects.filter(status='approved').update(status='accepted')


def accepted_to_approved(apps, schema_editor):
    ProductReview = apps.get_model('store', 'ProductReview')
    ProductReview.objects.filter(status='accepted').update(status='approved')


class Migration(migrations.Migration):

    dependencies = [
        ('store', '0009_productreview_order_item_productreview_status'),
    ]

    operations = [
        migrations.AlterField(
            model_name='productreview',
            name='status',
            field=models.CharField(choices=[('pending', 'Pending Approval'), ('accepted', 'Accepted'), ('rejected', 'Rejected')], db_index=True, default='pending', max_length=20),
        ),
        migrations.RunPython(approved_to_accepted, accepted_to_approved),
    ]