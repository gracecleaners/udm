import uuid

from django.conf import settings
from django.db import models


class TimestampedModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class Devotional(TimestampedModel):
    title = models.CharField(max_length=180)
    scripture_reference = models.CharField(max_length=120)
    excerpt = models.TextField(blank=True)
    body = models.TextField()
    reflection_questions = models.JSONField(default=list, blank=True)
    application = models.TextField(blank=True)
    prayer = models.TextField(blank=True)
    reading_minutes = models.PositiveSmallIntegerField(default=5)
    publish_at = models.DateTimeField(null=True, blank=True)
    is_published = models.BooleanField(default=False)

    class Meta:
        ordering = ["-publish_at", "title"]

    def __str__(self):
        return self.title


class Article(TimestampedModel):
    title = models.CharField(max_length=220)
    category = models.CharField(max_length=80, blank=True)
    author = models.CharField(max_length=120, blank=True)
    excerpt = models.TextField(blank=True)
    body = models.TextField()
    reading_minutes = models.PositiveSmallIntegerField(default=4)
    is_published = models.BooleanField(default=False)
    publish_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-publish_at", "title"]

    def __str__(self):
        return self.title


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
        constraints = [models.UniqueConstraint(fields=["user", "kind", "content_id"], name="unique_user_content_progress")]
        indexes = [models.Index(fields=["user", "completed_at"])]
