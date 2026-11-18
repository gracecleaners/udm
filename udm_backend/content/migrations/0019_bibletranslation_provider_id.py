from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0018_remove_article_translations_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="bibletranslation",
            name="provider_id",
            field=models.CharField(blank=True, default="", max_length=80),
        ),
    ]
