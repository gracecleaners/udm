"""Move every curated verse of the day into the memory verse table.

The two models were the same idea wearing two names: a server-curated verse with
a dated window, shown on the home screen. Merging them keeps one place to
author, one licence list to respect and one word for students to learn.

A featured row has no link to a synced verse, so each one arrives as a stored
copy — reference and text carried across, `is_active` becoming `is_published`.
"""

from django.db import migrations


def featured_into_memory(apps, schema_editor):
    FeaturedVerse = apps.get_model("content", "FeaturedVerse")
    MemoryVerse = apps.get_model("content", "MemoryVerse")
    for row in FeaturedVerse.objects.all().order_by("created_at"):
        MemoryVerse.objects.create(
            verse=None,
            reference=row.reference,
            text=row.text,
            translation_code=row.translation_code,
            attribution=row.attribution,
            prompt="",
            start_date=row.start_date,
            end_date=row.end_date,
            is_published=row.is_active,
            translations=row.translations or {},
        )


def memory_back_into_featured(apps, schema_editor):
    """Undo by dropping the stored copies, which only this migration created.

    Every memory verse that existed before it pointed at a synced verse, so a
    null `verse` identifies exactly the rows to remove.
    """
    MemoryVerse = apps.get_model("content", "MemoryVerse")
    MemoryVerse.objects.filter(verse__isnull=True).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("content", "0010_contentversion_devotionalseries_and_more"),
    ]

    operations = [
        migrations.RunPython(featured_into_memory, memory_back_into_featured),
    ]
