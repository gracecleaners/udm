"""Ministry content: devotionals, articles, the featured verse, and reading progress."""

import uuid

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import Q
from django.utils import timezone


class TimestampedModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class PublishedQuerySet(models.QuerySet):
    def published(self, at=None):
        """Rows an ordinary reader may see right now.

        A scheduled row stays hidden until its `publish_at` passes, so
        administrators can queue a day's devotion in advance.
        """
        at = at or timezone.now()
        return self.filter(is_published=True).filter(Q(publish_at__isnull=True) | Q(publish_at__lte=at))


class PublishableModel(TimestampedModel):
    title = models.CharField(max_length=220)
    author = models.CharField(max_length=150, blank=True)
    excerpt = models.TextField(blank=True)
    body = models.TextField()
    reading_minutes = models.PositiveSmallIntegerField(default=5)
    is_published = models.BooleanField(default=False)
    publish_at = models.DateTimeField(null=True, blank=True)

    objects = PublishedQuerySet.as_manager()

    class Meta:
        abstract = True

    def __str__(self):
        return self.title

    @property
    def is_live(self):
        return self.is_published and (self.publish_at is None or self.publish_at <= timezone.now())


class Devotional(PublishableModel):
    scripture_reference = models.CharField(max_length=120)
    reflection_questions = models.JSONField(default=list, blank=True)
    application = models.TextField(blank=True)
    prayer = models.TextField(blank=True)
    memory_scripture_reference = models.CharField(max_length=120, blank=True)

    class Meta:
        ordering = ["-publish_at", "-created_at"]
        indexes = [models.Index(fields=["is_published", "publish_at"], name="content_dev_pub_idx")]


class Article(PublishableModel):
    category = models.CharField(max_length=80, blank=True)

    class Meta:
        ordering = ["-publish_at", "-created_at"]
        indexes = [models.Index(fields=["is_published", "publish_at"], name="content_art_pub_idx")]


class FeaturedVerseQuerySet(models.QuerySet):
    def active(self, on_date=None):
        on_date = on_date or timezone.localdate()
        return self.filter(is_active=True).filter(
            Q(start_date__isnull=True) | Q(start_date__lte=on_date)
        ).filter(Q(end_date__isnull=True) | Q(end_date__gte=on_date))


class FeaturedVerse(TimestampedModel):
    """Curated verse-of-the-day text served to every reader.

    Only public-domain or licensed translations may be stored; the app never
    scrapes Bible text, and rotation is deterministic so the featured verse is
    stable for a given day across devices.
    """

    reference = models.CharField(max_length=120)
    text = models.TextField()
    translation_code = models.CharField(max_length=16, default="kjv")
    attribution = models.CharField(max_length=200, blank=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    is_active = models.BooleanField(default=True)

    objects = FeaturedVerseQuerySet.as_manager()

    class Meta:
        ordering = ["created_at"]
        constraints = [
            models.CheckConstraint(
                name="featuredverse_window_valid",
                condition=Q(end_date__isnull=True) | Q(end_date__gte=models.F("start_date")),
            )
        ]

    def __str__(self):
        return self.reference

    def clean(self):
        super().clean()
        allowed = getattr(settings, "UDM_FEATURED_VERSE_TRANSLATIONS", [])
        if allowed and self.translation_code not in allowed:
            raise ValidationError(
                {"translation_code": f"{self.translation_code} is not an allowed translation for featured verses."}
            )

    @classmethod
    def for_date(cls, on_date=None):
        on_date = on_date or timezone.localdate()
        candidates = list(cls.objects.active(on_date))
        if not candidates:
            return None
        return candidates[on_date.toordinal() % len(candidates)]


class UserContentProgress(TimestampedModel):
    class Kind(models.TextChoices):
        DEVOTIONAL = "devotional", "Devotional"
        ARTICLE = "article", "Article"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="content_progress")
    kind = models.CharField(max_length=20, choices=Kind.choices)
    content_id = models.UUIDField()
    completed_at = models.DateTimeField(auto_now_add=True)
    note = models.TextField(blank=True)

    class Meta:
        ordering = ["-completed_at"]
        constraints = [
            models.UniqueConstraint(fields=["user", "kind", "content_id"], name="unique_user_content_progress")
        ]
        indexes = [models.Index(fields=["user", "completed_at"])]
