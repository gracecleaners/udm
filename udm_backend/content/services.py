"""Content business rules, kept out of serializers and views."""

import logging
from collections import namedtuple
from datetime import timedelta

from django.db.models import Count, Q
from django.utils import timezone

from .models import (
    Article,
    BibleReadingPlan,
    BibleReadingProgress,
    Devotional,
    MediaCollection,
    MediaWatch,
    MemoryVerse,
    ResourceStep,
    ResourceTopic,
    UserContentProgress,
)

logger = logging.getLogger("udm")

GREETING_MORNING = "Good morning"
GREETING_AFTERNOON = "Good afternoon"
GREETING_EVENING = "Good evening"
GREETING_NIGHT = "Peace be with you"


def greeting_for(user, now=None):
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
    if user is not None and user.is_authenticated:
        return f"{base}, {user.display_name}"
    return base


def day_streak(user, on_now=None):
    """Consecutive days this student has done something with the app's content.

    A streak counts any of the three ways a day can be a study day — a finished
    reading, a recording watched through, a plan day ticked — because the point
    is the habit, not which table it landed in. A day that has just started is
    not yet a break: yesterday still holds the streak until today is missed too.
    """
    days = set()
    for model in (UserContentProgress, MediaWatch, BibleReadingProgress):
        for value in model.objects.filter(user=user).values_list("completed_at", flat=True):
            if value is not None:
                days.add(timezone.localdate(value))
    if not days:
        return 0
    today = on_now or timezone.localdate()
    cursor = today if today in days else today - timedelta(days=1)
    streak = 0
    while cursor in days:
        streak += 1
        cursor -= timedelta(days=1)
    return streak


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
    """The home resource list: a published PDF or at least one live step.

    PDF-only guides are valid resources now. For step-based guides, the count is
    the same rule `ResourceTopic.steps_live` applies, so a row never promises a
    step the page then hides. An aggregate query discards the model's default
    ordering, so the authored list order is restated here.
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
        .filter(Q(step_count__gt=0) | (Q(pdf__isnull=False) & ~Q(pdf="")))
        .order_by("order", "created_at")
    )


GuideProgress = namedtuple("GuideProgress", "per_topic finished_steps")


def guide_progress(user, on_now=None):
    """How far each live guide has been read, for one student.

    One pass over the published steps rather than a query per guide: a campus
    with a hundred guides should not cost a hundred round trips to answer one
    number. `per_topic` maps a guide id to its `[live, finished]` pair and
    `finished_steps` holds the step ids this student has ticked, which is what
    lets a guide's own step list say which rows are done without another read.
    An anonymous visitor has finished nothing, so the pairs stay honest totals.
    """
    now = on_now or timezone.now()
    finished = set()
    if user is not None and user.is_authenticated:
        finished = set(
            UserContentProgress.objects.filter(
                user=user, kind=UserContentProgress.Kind.RESOURCE_STEP
            ).values_list("content_id", flat=True)
        )
    per_topic = {}
    for step_id, topic_id in ResourceStep.objects.published(now).values_list("id", "topic_id"):
        counts = per_topic.setdefault(topic_id, [0, 0])
        counts[0] += 1
        if step_id in finished:
            counts[1] += 1
    return GuideProgress(per_topic=per_topic, finished_steps=finished)


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


def artwork_url(item, request):
    """The picture staff chose for this content, as an address the device loads.

    An upload is the ministry's own copy and answers first; the link pasted in
    the console is read only when no file is attached. With neither the app
    draws its brand tile, which is a designed state rather than a gap, so this
    returns None rather than inventing an address.
    """
    return media_file_url(item.image, request) or (item.image_link or None)


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


def todays_reading(user, on_now=None):
    """Where a student stands in the plan the ministry marked as the daily one.

    A plan is a run of days, so the reading a student is *on* is the first day
    they have not finished rather than a date: nothing forces the plan to start
    on the first of a month, and a student who misses two days is not told they
    have no reading. The counts travel with it because the progress line is the
    plan's length, not the day's number, and only the server knows both.
    """
    plan = BibleReadingPlan.objects.filter(is_published=True, is_daily=True).order_by("title").first()
    if plan is None:
        return None
    assignments = list(plan.assignments.all())
    if not assignments:
        return None
    finished = set()
    if user is not None and user.is_authenticated:
        finished = set(
            BibleReadingProgress.objects.filter(
                user=user, assignment__in=assignments, completed_at__isnull=False
            ).values_list("assignment_id", flat=True)
        )
    current = next((row for row in assignments if row.pk not in finished), assignments[-1])
    return {
        "plan_title": plan.title,
        "assignment": current,
        "total": len(assignments),
        "completed": len(finished),
    }


def home_payload(user, on_now=None):
    on_now = on_now or timezone.now()
    return {
        "greeting": greeting_for(user, on_now),
        "memory_verse": memory_verse(on_now),
        "devotion": todays_devotional(on_now),
        "reading": todays_reading(user, on_now),
        "articles": latest_articles(on_now=on_now),
        "resources": live_resource_topics(on_now),
        "server_time": on_now,
    }
