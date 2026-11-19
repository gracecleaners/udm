from django.db import migrations, models
import django.db.models.deletion


def clear_legacy_view_totals(apps, schema_editor):
    # Old totals were raw opens and cannot be converted into unique email views.
    ResourceTopic = apps.get_model("content", "ResourceTopic")
    ResourceTopic.objects.all().update(views=0)


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0022_devotional_series_artwork_and_scripture"),
    ]

    operations = [
        migrations.CreateModel(
            name="ResourceTopicView",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("email_hash", models.CharField(max_length=64)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "topic",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="email_views",
                        to="content.resourcetopic",
                    ),
                ),
            ],
            options={
                "constraints": [
                    models.UniqueConstraint(
                        fields=("topic", "email_hash"),
                        name="resource_topic_view_email_unique",
                    ),
                ],
            },
        ),
        migrations.RunPython(clear_legacy_view_totals, migrations.RunPython.noop),
    ]
