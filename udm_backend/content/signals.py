"""Every authored change counts once, so the app can tell stale from fresh.

`ContentVersion` is the number the mobile app compares before it decides to
refetch; these handlers are what keeps it honest. A screen that refetches for
nothing is cheap, but a screen that stays stale after an edit is the failure the
student sees, so the tracked set is everything the app renders rather than only
the obvious tables.
"""

from django.db.models.signals import post_delete, post_save

from .models import (
    Article,
    BibleBook,
    BibleChapter,
    BibleReadingAssignment,
    BibleReadingPlan,
    BibleTranslation,
    BibleVerse,
    Campus,
    ContentVersion,
    Devotional,
    DevotionalSeries,
    DiscipleshipGroup,
    Event,
    Fellowship,
    MediaCollection,
    MediaItem,
    MemoryVerse,
    PrayerRequest,
    ResourceStep,
    ResourceTopic,
    University,
)

TRACKED_MODELS = (
    DevotionalSeries,
    Devotional,
    Article,
    ResourceTopic,
    ResourceStep,
    MediaCollection,
    MediaItem,
    MemoryVerse,
    BibleTranslation,
    BibleBook,
    BibleChapter,
    BibleVerse,
    BibleReadingPlan,
    BibleReadingAssignment,
    University,
    Campus,
    Fellowship,
    DiscipleshipGroup,
    Event,
    PrayerRequest,
)


def mark_content_changed():
    """Call from a path that writes tracked rows without a per-row signal.

    `bulk_create` and `queryset.update()` skip `post_save`, so an import that
    loads four thousand verses would otherwise leave every device on the old
    version number.
    """
    ContentVersion.bump()


def _bump(sender, instance, **kwargs):
    mark_content_changed()


def connect():
    for model in TRACKED_MODELS:
        post_save.connect(_bump, sender=model, dispatch_uid=f"content_version_save_{model.__name__}")
        post_delete.connect(_bump, sender=model, dispatch_uid=f"content_version_delete_{model.__name__}")
