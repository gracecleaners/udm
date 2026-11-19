import uuid

from django.db import migrations, models
import django.db.models.deletion
from django.db.models import Q


def move_new_believer_content(apps, schema_editor):
    ResourceStep = apps.get_model("content", "ResourceStep")
    ResourceTopic = apps.get_model("content", "ResourceTopic")
    NewBelieverResource = apps.get_model("content", "NewBelieverResource")
    UserContentProgress = apps.get_model("content", "UserContentProgress")

    legacy_items = ResourceStep.objects.filter(
        Q(is_new_believer=True) | Q(topic__title__iexact="New Believer")
    ).distinct()
    for item in legacy_items.iterator():
        NewBelieverResource.objects.update_or_create(
            pk=item.pk,
            defaults={
                "title": item.title,
                "author": item.author,
                "excerpt": item.excerpt,
                "body": item.body,
                "reading_minutes": item.reading_minutes,
                "is_published": item.is_published,
                "publish_at": item.publish_at,
                "scripture_reference": item.scripture_reference,
                "order": item.order or 1,
                "video_url": item.video_url,
                "created_at": item.created_at,
                "updated_at": item.updated_at,
            },
        )
        for progress in UserContentProgress.objects.filter(
            kind="resource_step", content_id=item.pk
        ).iterator():
            UserContentProgress.objects.get_or_create(
                user_id=progress.user_id,
                kind="new_believer",
                content_id=item.pk,
                defaults={"note": progress.note},
            )

    # The former seeded New Believer guide is replaced by the standalone rows.
    former_topics = ResourceTopic.objects.filter(title__iexact="New Believer")
    former_step_ids = ResourceStep.objects.filter(topic_id__in=former_topics).values_list("pk", flat=True)
    UserContentProgress.objects.filter(
        kind="resource_step", content_id__in=former_step_ids
    ).delete()
    former_topics.delete()


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0023_unique_resource_email_views"),
    ]

    operations = [
        migrations.CreateModel(
            name="NewBelieverResource",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("title", models.CharField(max_length=220)),
                ("author", models.CharField(blank=True, max_length=150)),
                ("excerpt", models.TextField(blank=True)),
                ("body", models.TextField()),
                ("reading_minutes", models.PositiveSmallIntegerField(default=5)),
                ("is_published", models.BooleanField(default=False)),
                ("publish_at", models.DateTimeField(blank=True, null=True)),
                ("scripture_reference", models.CharField(blank=True, max_length=120)),
                ("image", models.ImageField(blank=True, null=True, upload_to="new_believer/")),
                ("image_link", models.URLField(blank=True)),
                ("order", models.PositiveSmallIntegerField(default=1)),
                ("video_url", models.URLField(blank=True)),
            ],
            options={
                "ordering": ["order", "created_at"],
                "indexes": [models.Index(fields=["is_published", "publish_at"], name="content_newbeliever_pub_idx")],
            },
        ),
        migrations.RunPython(move_new_believer_content, migrations.RunPython.noop),
        migrations.RemoveField(model_name="resourcestep", name="is_new_believer"),
        migrations.AlterField(
            model_name="usercontentprogress",
            name="kind",
            field=models.CharField(
                choices=[
                    ("devotional", "Devotional"),
                    ("article", "Article"),
                    ("resource_step", "Resource step"),
                    ("new_believer", "New believer resource"),
                ],
                max_length=20,
            ),
        ),
    ]
