import django.core.validators
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0019_bibletranslation_provider_id"),
    ]

    operations = [
        migrations.AddField(
            model_name="resourcetopic",
            name="pdf",
            field=models.FileField(
                blank=True,
                null=True,
                upload_to="resource_pdfs/",
                validators=[django.core.validators.FileExtensionValidator(["pdf"])],
                help_text="Optional PDF opened by Read now in the mobile app.",
            ),
        ),
    ]
