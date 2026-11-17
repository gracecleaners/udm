from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0016_article_image_link_devotional_image_link_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="resourcetopic",
            name="image",
            field=models.ImageField(
                blank=True,
                help_text="Optional cover image for this guide. Leave empty for the branded fallback.",
                null=True,
                upload_to="resource_topics/",
            ),
        ),
        migrations.AddField(
            model_name="resourcetopic",
            name="image_link",
            field=models.URLField(blank=True),
        ),
    ]
