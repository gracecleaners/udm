from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [("content", "0021_resource_views_and_new_believer")]

    operations = [
        migrations.AddField(
            model_name="devotionalseries",
            name="image",
            field=models.ImageField(
                blank=True,
                help_text="Optional series cover image. This takes priority over linked cover art.",
                null=True,
                upload_to="devotional_series/",
            ),
        ),
        migrations.AddField(
            model_name="devotionalseries",
            name="image_link",
            field=models.URLField(blank=True),
        ),
        migrations.AddField(
            model_name="devotional",
            name="scripture_text",
            field=models.TextField(blank=True),
        ),
        migrations.AlterField(
            model_name="devotional",
            name="scripture_reference",
            field=models.CharField(blank=True, max_length=120),
        ),
    ]
