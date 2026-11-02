"""Content business rules, kept out of serializers and views."""

import logging

from django.utils import timezone

from .models import Article, Devotional, FeaturedVerse

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


def todays_devotional(on_now=None):
    """The devotional scheduled for today, falling back to the newest live one."""
    on_now = on_now or timezone.now()
    day = timezone.localdate(on_now) if timezone.is_aware(on_now) else on_now.date()
    live = Devotional.objects.published(on_now)
    scheduled = live.filter(publish_at__date=day).first()
    return scheduled or live.first()


def featured_verse(on_now=None):
    return FeaturedVerse.for_date((on_now or timezone.now()).date())


def latest_articles(limit=5, on_now=None):
    return Article.objects.published(on_now)[:limit]


def home_payload(user, on_now=None):
    on_now = on_now or timezone.now()
    return {
        "greeting": greeting_for(user, on_now),
        "verse": featured_verse(on_now),
        "devotion": todays_devotional(on_now),
        "articles": latest_articles(on_now=on_now),
        "server_time": on_now,
    }
