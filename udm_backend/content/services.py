"""Content business rules, kept out of serializers and views."""

import logging

from django.db.models import Count, Q
from django.utils import timezone

from .models import Article, Devotional, MediaCollection, MemoryVerse, ResourceTopic

logger = logging.getLogger("udm")

GREETING_MORNING = "Good morning"
GREETING_AFTERNOON = "Good afternoon"
GREETING_EVENING = "Good evening"
GREETING_NIGHT = "Peace be with you"


def greeting_for(user, now=None, language="en"):
    now = now or timezone.localtime()
    hour = now.hour
    if 5 <= hour < 12:
        base = GREETING_MORNING
    elif 12 <= hour < 17:
        base = GREETING_AFTERNOON
    elif 17 <= hour < 21:
        base = GREETING_EVENING
    else:
        base = GREETING_NIGHT
    if str(language).lower().startswith("fr"):
        base = {
            GREETING_MORNING: "Bonjour",
            GREETING_AFTERNOON: "Bon après-midi",
            GREETING_EVENING: "Bonsoir",
            GREETING_NIGHT: "Que la paix soit avec vous",
        }[base]
    if user is not None and user.is_authenticated:
        return f"{base}, {user.display_name}"
    return base


def todays_devotional(on_now=None):
    """The devotional scheduled for today, falling back to the newest live one."""
    on_now = on_now or timezone.now()
    day = timezone.localdate(on_now) if timezone.is_aware(on_now) else on_now.date()
    live = Devotional.objects.published(on_now)
    scheduled = live.filter(publish_at__date=day).first()
    return scheduled or live.first()


def memory_verse(on_now=None):
    return MemoryVerse.for_date((on_now or timezone.now()).date())


def latest_articles(limit=5, on_now=None):
    return Article.objects.published(on_now)[:limit]


def live_resource_topics(on_now=None):
    """The home 'Find resources on' list: every guide with something to read.

    The count is the same rule `ResourceTopic.steps_live` applies, so a row never
    promises a step the page then hides. An aggregate query discards the model's
    default ordering, so the authored list order is restated here.
    """
    now = on_now or timezone.now()
    return (
        ResourceTopic.objects.published(now)
        .annotate(
            step_count=Count(
                "steps",
                filter=(
                    Q(steps__is_published=True)
                    & (Q(steps__publish_at__isnull=True) | Q(steps__publish_at__lte=now))
                ),
            )
        )
        .filter(step_count__gt=0)
        .order_by("order", "created_at")
    )


def media_file_url(upload, request):
    """An uploaded cover as an address the device can load, or None.

    `ImageField.url` raises rather than returning something usable when the file
    row exists but its bytes were never written, which is a state an operator can
    reach by hand. A missing cover is a plain tile in the app, not a 500.
    """
    if not upload:
        return None
    try:
        url = upload.url
    except (ValueError, NotImplementedError):
        return None
    return request.build_absolute_uri(url) if request is not None else url


def live_media_collections(on_now=None):
    """The Learn tab's shelves: every collection with a recording on it.

    The count is the same rule `MediaCollection.items_live` applies, so a shelf
    never promises a recording the page then hides. Whether each recording
    actually plays is a property of the row itself — `youtube_video_id` is null
    when staff attached a file instead of a video — so the app renders per
    recording rather than the shelf deciding for it. An aggregate query discards
    the model's default ordering, so the authored list order is restated here.
    """
    now = on_now or timezone.now()
    return (
        MediaCollection.objects.published(now)
        .annotate(
            item_count=Count(
                "items",
                filter=(
                    Q(items__is_published=True)
                    & (Q(items__publish_at__isnull=True) | Q(items__publish_at__lte=now))
                ),
            )
        )
        .filter(item_count__gt=0)
        .order_by("order", "created_at")
    )


def home_payload(user, on_now=None, language="en"):
    on_now = on_now or timezone.now()
    return {
        "greeting": greeting_for(user, on_now, language),
        "memory_verse": memory_verse(on_now),
        "devotion": todays_devotional(on_now),
        "articles": latest_articles(on_now=on_now),
        "resources": live_resource_topics(on_now),
        "server_time": on_now,
    }
