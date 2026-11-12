"""Ministry content: devotion series and days, articles, memory verses, progress."""

import uuid
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import F, Q
from django.utils import timezone

from .media_refs import youtube_video_id


class TimestampedModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class LocalizedModel(TimestampedModel):
    """Admin-authored strings with optional locale overrides."""

    translations = models.JSONField(
        default=dict,
        blank=True,
        help_text="Language-specific text is edited in the translation fields below.",
    )
    localized_fields = ()

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


class PublishableModel(LocalizedModel):
    title = models.CharField(max_length=220)
    author = models.CharField(max_length=150, blank=True)
    excerpt = models.TextField(blank=True)
    body = models.TextField()
    reading_minutes = models.PositiveSmallIntegerField(default=5)
    is_published = models.BooleanField(default=False)
    publish_at = models.DateTimeField(null=True, blank=True)
    localized_fields = ("title", "excerpt", "body")

    objects = PublishedQuerySet.as_manager()

    class Meta:
        abstract = True

    def __str__(self):
        return self.title

    @property
    def is_live(self):
        return self.is_published and (self.publish_at is None or self.publish_at <= timezone.now())


class DevotionalSeries(LocalizedModel):
    """A named set of devotions read day by day — *The Book of James*, *Christmas*.

    The app's Devotions tab is this table and nothing more, so a series with no
    published day is hidden rather than shown as an empty folder. Covers are
    stored as URLs rather than uploads: the art belongs to the ministry's own
    host, and this deployment has no second file store to keep in sync.
    """

    title = models.CharField(max_length=220)
    description = models.TextField(blank=True)
    cover_image_url = models.URLField(blank=True)
    order = models.PositiveSmallIntegerField(default=1, help_text="Position in the Devotions grid, lowest first.")
    is_published = models.BooleanField(default=False)
    publish_at = models.DateTimeField(null=True, blank=True)
    localized_fields = ("title", "description")

    objects = PublishedQuerySet.as_manager()

    class Meta:
        ordering = ["order", "created_at"]
        indexes = [models.Index(fields=["is_published", "publish_at"], name="content_devseries_pub_idx")]

    def __str__(self):
        return self.title

    @property
    def is_live(self):
        return self.is_published and (self.publish_at is None or self.publish_at <= timezone.now())

    def days_live(self, at=None):
        """This series' readable days: Introduction first, then numbered order.

        Postgres sorts a null day last by default, and an unnumbered
        Introduction is read before Day 1, so the null is asked for explicitly.
        """
        return (
            Devotional.objects.filter(series_id=self.pk)
            .published(at)
            .order_by(F("day").asc(nulls_first=True), "publish_at", "created_at")
        )


class Devotional(PublishableModel):
    series = models.ForeignKey(
        DevotionalSeries,
        on_delete=models.SET_NULL,
        related_name="devotions",
        null=True,
        blank=True,
        help_text="Leave empty for a one-off devotion; the home feed reads those too.",
    )
    day = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        help_text="Day number within the series. Empty sorts first, which is where an Introduction belongs.",
    )
    scripture_reference = models.CharField(max_length=120)
    reflection_questions = models.JSONField(default=list, blank=True)
    application = models.TextField(blank=True)
    prayer = models.TextField(blank=True)
    memory_scripture_reference = models.CharField(max_length=120, blank=True)
    localized_fields = PublishableModel.localized_fields + (
        "reflection_questions", "application", "prayer",
    )

    class Meta:
        ordering = ["-publish_at", "-created_at"]
        indexes = [models.Index(fields=["is_published", "publish_at"], name="content_dev_pub_idx")]
        constraints = [
            models.UniqueConstraint(
                fields=["series", "day"],
                condition=Q(day__isnull=False) & Q(series__isnull=False),
                name="devotional_day_unique_within_series",
            )
        ]


class Article(PublishableModel):
    category = models.CharField(max_length=80, blank=True)
    localized_fields = PublishableModel.localized_fields + ("category",)

    class Meta:
        ordering = ["-publish_at", "-created_at"]
        indexes = [models.Index(fields=["is_published", "publish_at"], name="content_art_pub_idx")]


class ResourceTopic(LocalizedModel):
    """One guided answer to a question a student actually asks — *Receive Christ*,
    *Prayer*, *The Bible*.

    The home screen's "Find resources on" list is this table and nothing else, so
    a topic with no published step is hidden rather than shown as a folder that
    opens on nothing — the same rule the Devotions grid follows for a series with
    no day.
    """

    title = models.CharField(max_length=220)
    summary = models.TextField(blank=True)
    order = models.PositiveSmallIntegerField(
        default=1,
        help_text="Position in the home 'Find resources on' list, lowest first.",
    )
    is_published = models.BooleanField(default=False)
    publish_at = models.DateTimeField(null=True, blank=True)
    localized_fields = ("title", "summary")

    objects = PublishedQuerySet.as_manager()

    class Meta:
        ordering = ["order", "created_at"]
        indexes = [models.Index(fields=["is_published", "publish_at"], name="content_restopic_pub_idx")]

    def __str__(self):
        return self.title

    @property
    def is_live(self):
        return self.is_published and (self.publish_at is None or self.publish_at <= timezone.now())

    def steps_live(self, at=None):
        """This topic's readable steps, in the order they are meant to be worked through.

        Postgres sorts a null last by default, and an unnumbered starting point is
        read before Step 1, so the null is asked for explicitly.
        """
        return (
            ResourceStep.objects.filter(topic_id=self.pk)
            .published(at)
            .order_by(F("order").asc(nulls_first=True), "publish_at", "created_at")
        )


class ResourceStep(PublishableModel):
    """One part of a guide: what the topic teaches, the verse it stands on, and an
    optional video the ministry chose to attach.

    Nothing plays inside the app. `video_url` is a curated https:// link handed to
    the device's own browser, which is the same rule learning media follows — this
    deployment has no media store of its own, and an unlicensed player would be a
    worse promise than no button at all.
    """

    topic = models.ForeignKey(
        ResourceTopic,
        on_delete=models.CASCADE,
        related_name="steps",
        help_text="A step with no topic cannot be reached, so deleting a topic takes its steps with it.",
    )
    order = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        help_text="Step number within the topic. Empty sorts first, which is where a starting point belongs.",
    )
    scripture_reference = models.CharField(max_length=120, blank=True)
    video_url = models.URLField(
        blank=True,
        help_text="Optional https:// link the ministry hosts. Leave empty and the app shows no video action.",
    )
    localized_fields = PublishableModel.localized_fields

    class Meta:
        ordering = ["-publish_at", "-created_at"]
        indexes = [models.Index(fields=["is_published", "publish_at"], name="content_reststep_pub_idx")]
        constraints = [
            models.UniqueConstraint(
                fields=["topic", "order"],
                condition=Q(order__isnull=False) & Q(topic__isnull=False),
                name="resourcestep_order_unique_within_topic",
            )
        ]

    def clean(self):
        super().clean()
        if self.video_url and not self.video_url.lower().startswith("https://"):
            raise ValidationError({"video_url": "Resource videos must use a secure HTTPS link."})


class MemoryVerseQuerySet(models.QuerySet):
    def active(self, on_date=None):
        """Rows whose window covers today — what the home feed rotates through."""
        on_date = on_date or timezone.localdate()
        return self.filter(is_published=True).filter(
            Q(start_date__isnull=True) | Q(start_date__lte=on_date)
        ).filter(Q(end_date__isnull=True) | Q(end_date__gte=on_date))


class MemoryVerse(LocalizedModel):
    """A verse students hide in their heart, curated on the server.

    One model serves both jobs the app has: the home screen's verse of the day
    (a dated window, deterministic rotation) and the memorization list with its
    per-user progress. The text is either a synced `BibleVerse` row, in which
    case that translation's licence and attribution govern it, or a copy stored
    here with its own attribution — which is what lets a deployment feature a
    verse whose translation has not been imported. Only public-domain or
    licensed text may be stored; the app never scrapes Bible text.
    """

    verse = models.ForeignKey(
        "BibleVerse",
        on_delete=models.CASCADE,
        related_name="memory_verses",
        null=True,
        blank=True,
        help_text="Optional. Pick a synced verse and its text, reference and attribution are read from it.",
    )
    reference = models.CharField(max_length=120, blank=True)
    text = models.TextField(blank=True)
    translation_code = models.CharField(max_length=16, default="kjv")
    attribution = models.CharField(max_length=200, blank=True)
    prompt = models.CharField(max_length=220, blank=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    is_published = models.BooleanField(default=False)
    localized_fields = ("reference", "text", "attribution", "prompt")
    translation_excluded_fields = ("reference", "text", "attribution")

    objects = MemoryVerseQuerySet.as_manager()

    class Meta:
        ordering = ["created_at"]
        constraints = [
            models.CheckConstraint(
                name="memoryverse_window_valid",
                condition=Q(end_date__isnull=True) | Q(end_date__gte=models.F("start_date")),
            ),
            models.CheckConstraint(
                name="memoryverse_text_source",
                condition=Q(verse__isnull=False) | (~Q(reference="") & ~Q(text="")),
            ),
            # One drill per synced verse. A null verse is a stored copy, and
            # Postgres keeps those out of the unique index automatically.
            models.UniqueConstraint(fields=["verse"], name="unique_memory_verse"),
        ]

    def __str__(self):
        return self.display_reference

    @property
    def display_reference(self):
        if self.verse_id is not None:
            verse = self.verse
            chapter = verse.chapter
            return f"{chapter.book.name} {chapter.number}:{verse.number}"
        return self.reference

    @property
    def display_text(self):
        return self.verse.text if self.verse_id is not None else self.text

    @property
    def display_translation_code(self):
        if self.verse_id is not None:
            return self.verse.chapter.book.translation.code
        return self.translation_code

    @property
    def display_attribution(self):
        """Licensed credit always comes from the translation row when there is one."""
        if self.verse_id is not None:
            return self.verse.chapter.book.translation.attribution
        return self.attribution

    def clean(self):
        super().clean()
        if self.verse_id is None and not (self.reference.strip() and self.text.strip()):
            raise ValidationError(
                {"text": "Either pick a synced verse or write the reference and the text."}
            )
        allowed = getattr(settings, "UDM_MEMORY_VERSE_TRANSLATIONS", [])
        if self.verse_id is None and allowed and self.translation_code not in allowed:
            raise ValidationError(
                {"translation_code": f"{self.translation_code} is not an allowed translation for memory verses."}
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
        RESOURCE_STEP = "resource_step", "Resource step"

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


class BibleTranslation(TimestampedModel):
    code = models.CharField(max_length=40, unique=True)
    name = models.CharField(max_length=120)
    license_name = models.CharField(max_length=160)
    attribution = models.TextField()
    source_url = models.URLField(blank=True)
    offline_allowed = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    source_provider = models.CharField(max_length=32, blank=True, default="")

    class Meta:
        constraints = [
            models.CheckConstraint(condition=~Q(license_name=""), name="bible_license_required"),
            models.CheckConstraint(condition=~Q(attribution=""), name="bible_attribution_required"),
        ]

    def __str__(self):
        return f"{self.name} ({self.code})"


class BibleBook(TimestampedModel):
    translation = models.ForeignKey(BibleTranslation, on_delete=models.CASCADE, related_name="books")
    name = models.CharField(max_length=80)
    provider_id = models.CharField(max_length=40, blank=True, default="")
    order = models.PositiveSmallIntegerField()
    testament = models.CharField(max_length=12, choices=(("old", "Old Testament"), ("new", "New Testament")))

    class Meta:
        ordering = ["order"]
        constraints = [models.UniqueConstraint(fields=["translation", "order"], name="unique_bible_book_order"), models.UniqueConstraint(fields=["translation", "name"], name="unique_bible_book_name")]


class BibleChapter(TimestampedModel):
    book = models.ForeignKey(BibleBook, on_delete=models.CASCADE, related_name="chapters")
    number = models.PositiveSmallIntegerField()

    class Meta:
        ordering = ["number"]
        constraints = [models.UniqueConstraint(fields=["book", "number"], name="unique_bible_chapter")]


class BibleVerse(TimestampedModel):
    chapter = models.ForeignKey(BibleChapter, on_delete=models.CASCADE, related_name="verses")
    number = models.PositiveSmallIntegerField()
    text = models.TextField()

    class Meta:
        ordering = ["number"]
        constraints = [models.UniqueConstraint(fields=["chapter", "number"], name="unique_bible_verse")]


class BibleBookmark(TimestampedModel):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="bible_bookmarks")
    verse = models.ForeignKey(BibleVerse, on_delete=models.CASCADE, related_name="bookmarks")

    class Meta:
        ordering = ["-updated_at"]
        constraints = [models.UniqueConstraint(fields=["user", "verse"], name="unique_user_bible_bookmark")]


class BibleNote(TimestampedModel):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="bible_notes")
    verse = models.ForeignKey(BibleVerse, on_delete=models.CASCADE, related_name="notes")
    body = models.TextField()

    class Meta:
        ordering = ["-updated_at"]
        constraints = [models.UniqueConstraint(fields=["user", "verse"], name="unique_user_bible_note")]


class BibleReadingPlan(LocalizedModel):
    title = models.CharField(max_length=220)
    description = models.TextField(blank=True)
    is_published = models.BooleanField(default=False)
    localized_fields = ("title", "description")

    class Meta:
        ordering = ["title"]


class BibleReadingAssignment(LocalizedModel):
    plan = models.ForeignKey(BibleReadingPlan, on_delete=models.CASCADE, related_name="assignments")
    day = models.PositiveSmallIntegerField()
    reference = models.CharField(max_length=220)
    localized_fields = ("reference",)
    translation_excluded_fields = ("reference",)

    class Meta:
        ordering = ["day"]
        constraints = [models.UniqueConstraint(fields=["plan", "day"], name="unique_bible_plan_day")]


class BibleReadingProgress(TimestampedModel):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="bible_reading_progress")
    assignment = models.ForeignKey(BibleReadingAssignment, on_delete=models.CASCADE, related_name="progress")
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-updated_at"]
        constraints = [models.UniqueConstraint(fields=["user", "assignment"], name="unique_user_bible_assignment")]


class MediaCollection(LocalizedModel):
    """A named shelf of video or audio teaching — *SOMA*, *Uliza*, *Podcast*.

    The Learn tab is this table and nothing else, so a collection with no
    published recording is hidden rather than shown as a folder that opens on
    nothing — the same rule the guides follow for a step.
    """

    title = models.CharField(max_length=220)
    description = models.TextField(blank=True)
    image = models.ImageField(
        upload_to="media_collections/",
        null=True,
        blank=True,
        help_text="The shelf artwork students recognise. Leave empty for a plain tile.",
    )
    order = models.PositiveSmallIntegerField(default=1, help_text="Position in the Learn tab, lowest first.")
    is_published = models.BooleanField(default=False)
    publish_at = models.DateTimeField(null=True, blank=True)
    localized_fields = ("title", "description")

    objects = PublishedQuerySet.as_manager()

    class Meta:
        ordering = ["order", "created_at"]
        indexes = [models.Index(fields=["is_published", "publish_at"], name="content_medcoll_pub_idx")]

    def __str__(self):
        return self.title

    @property
    def is_live(self):
        return self.is_published and (self.publish_at is None or self.publish_at <= timezone.now())

    def items_live(self, at=None):
        """This collection's readable recordings, in the order it is presented.

        An authored position wins; the rows left unnumbered fall back to newest
        first, which is what a podcast feed looks like.
        """
        return (
            MediaItem.objects.filter(collection_id=self.pk)
            .published(at)
            .order_by(F("order").asc(nulls_last=True), "-publish_at", "-created_at")
        )


class MediaItem(LocalizedModel):
    """One recording inside a collection.

    The footage belongs to the ministry and lives on YouTube; staff paste the
    link and the app plays it inline. `download_url` is separate on purpose: a
    YouTube recording may not be downloaded under its terms, so the app only
    offers that action when staff point it at a file the ministry distributes
    itself.
    """

    collection = models.ForeignKey(
        MediaCollection,
        on_delete=models.CASCADE,
        related_name="items",
        help_text="A recording with no collection cannot be reached, so deleting a collection takes its items with it.",
    )
    order = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        help_text="Position within the collection, lowest first. Leave empty to keep newest recordings at the top.",
    )
    title = models.CharField(max_length=220)
    author = models.CharField(max_length=150, blank=True)
    excerpt = models.TextField(blank=True)
    body = models.TextField(blank=True)
    youtube_url = models.URLField(
        blank=True,
        help_text="Paste any YouTube link — watch, youtu.be, shorts, embed or the bare video id.",
    )
    download_url = models.URLField(
        blank=True,
        help_text="Optional https link to a file the ministry hosts, such as a sermon mp3. Only then does the app offer Download.",
    )
    duration_seconds = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Total length in seconds, so a 15:40 recording is 940.",
    )
    image = models.ImageField(
        upload_to="media_items/",
        null=True,
        blank=True,
        help_text="Optional artwork. With none, a YouTube recording shows its own thumbnail.",
    )
    is_published = models.BooleanField(default=False)
    publish_at = models.DateTimeField(null=True, blank=True)
    localized_fields = ("title", "excerpt", "body")

    objects = PublishedQuerySet.as_manager()

    class Meta:
        ordering = ["-publish_at", "-created_at"]
        indexes = [models.Index(fields=["is_published", "publish_at"], name="content_meditem_pub_idx")]
        constraints = [
            models.UniqueConstraint(
                fields=["collection", "order"],
                condition=Q(order__isnull=False) & Q(collection__isnull=False),
                name="mediaitem_order_unique_within_collection",
            )
        ]

    def __str__(self):
        return self.title

    @property
    def is_live(self):
        return self.is_published and (self.publish_at is None or self.publish_at <= timezone.now())

    @property
    def youtube_video_id(self):
        return youtube_video_id(self.youtube_url)

    @property
    def is_playable(self):
        return self.youtube_video_id is not None

    def clean(self):
        super().clean()
        for field in ("youtube_url", "download_url"):
            value = getattr(self, field)
            if value and not value.lower().startswith("https://"):
                raise ValidationError({field: "Media must be served over a secure HTTPS URL."})
        if self.youtube_url and self.youtube_video_id is None:
            raise ValidationError(
                {"youtube_url": "That is not a YouTube link the app can play. Paste the video's watch or youtu.be address."}
            )


class MediaNote(TimestampedModel):
    """What a student wrote about one recording, to themselves.

    Notes are owner-scoped and deliberately absent from every staff listing: a
    reflection on a sermon is not an operations record.
    """

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="media_notes")
    item = models.ForeignKey(MediaItem, on_delete=models.CASCADE, related_name="notes")
    body = models.TextField()

    class Meta:
        ordering = ["-updated_at"]
        constraints = [models.UniqueConstraint(fields=["user", "item"], name="unique_user_media_note")]


class MediaWatch(TimestampedModel):
    """Where a student stopped, so a long recording resumes instead of restarting."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="media_watches")
    item = models.ForeignKey(MediaItem, on_delete=models.CASCADE, related_name="watches")
    position_seconds = models.PositiveIntegerField(default=0)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-updated_at"]
        constraints = [models.UniqueConstraint(fields=["user", "item"], name="unique_user_media_watch")]


class UserMemoryVerseProgress(TimestampedModel):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="memory_verse_progress")
    memory_verse = models.ForeignKey(MemoryVerse, on_delete=models.CASCADE, related_name="progress")
    completed_at = models.DateTimeField(null=True, blank=True)
    review_count = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["-updated_at"]
        constraints = [models.UniqueConstraint(fields=["user", "memory_verse"], name="unique_user_memory_verse")]


class University(LocalizedModel):
    name = models.CharField(max_length=180, unique=True)
    country = models.CharField(max_length=100)
    city = models.CharField(max_length=100, blank=True)
    website = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)
    localized_fields = ("name", "country", "city")

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Campus(LocalizedModel):
    university = models.ForeignKey(University, on_delete=models.CASCADE, related_name="campuses")
    name = models.CharField(max_length=180)
    location = models.CharField(max_length=220, blank=True)
    is_active = models.BooleanField(default=True)
    localized_fields = ("name", "location")

    class Meta:
        ordering = ["university__name", "name"]
        constraints = [models.UniqueConstraint(fields=["university", "name"], name="unique_university_campus")]


class Fellowship(LocalizedModel):
    campus = models.ForeignKey(Campus, on_delete=models.CASCADE, related_name="fellowships")
    name = models.CharField(max_length=180)
    description = models.TextField(blank=True)
    meeting_schedule = models.CharField(max_length=220, blank=True)
    is_public = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    localized_fields = ("name", "description", "meeting_schedule")

    class Meta:
        ordering = ["campus__university__name", "name"]
        constraints = [models.UniqueConstraint(fields=["campus", "name"], name="unique_campus_fellowship")]


class DiscipleshipGroup(LocalizedModel):
    class Visibility(models.TextChoices):
        PUBLIC = "public", "Discoverable"
        PRIVATE = "private", "Members only"

    campus = models.ForeignKey(Campus, on_delete=models.SET_NULL, null=True, blank=True, related_name="groups")
    name = models.CharField(max_length=180)
    description = models.TextField(blank=True)
    group_type = models.CharField(max_length=60, blank=True)
    leader = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="led_discipleship_groups")
    capacity = models.PositiveSmallIntegerField(null=True, blank=True)
    visibility = models.CharField(max_length=12, choices=Visibility.choices, default=Visibility.PUBLIC)
    is_active = models.BooleanField(default=True)
    localized_fields = ("name", "description", "group_type")

    class Meta:
        ordering = ["name"]


class GroupMembership(TimestampedModel):
    class Status(models.TextChoices):
        REQUESTED = "requested", "Requested"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="group_memberships")
    group = models.ForeignKey(DiscipleshipGroup, on_delete=models.CASCADE, related_name="memberships")
    role = models.CharField(max_length=20, default="member")
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.REQUESTED)
    requested_at = models.DateTimeField(auto_now_add=True)
    approved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-requested_at"]
        constraints = [models.UniqueConstraint(fields=["user", "group"], name="unique_user_group_membership")]


class Event(LocalizedModel):
    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        PUBLISHED = "published", "Published"
        CANCELLED = "cancelled", "Cancelled"

    campus = models.ForeignKey(Campus, on_delete=models.SET_NULL, null=True, blank=True, related_name="events")
    organizer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="organized_events")
    title = models.CharField(max_length=220)
    description = models.TextField(blank=True)
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField(null=True, blank=True)
    timezone = models.CharField(max_length=64, default="UTC")
    location = models.CharField(max_length=220, blank=True)
    online_url = models.URLField(blank=True)
    capacity = models.PositiveIntegerField(null=True, blank=True)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.DRAFT)
    localized_fields = ("title", "description", "location")

    class Meta:
        ordering = ["starts_at"]

    def clean(self):
        super().clean()
        if self.ends_at and self.ends_at <= self.starts_at:
            raise ValidationError({"ends_at": "Event end must be after its start."})
        if self.online_url and not self.online_url.lower().startswith("https://"):
            raise ValidationError({"online_url": "Online events must use a secure HTTPS link."})
        try:
            ZoneInfo(self.timezone or "UTC")
        except (ValueError, ZoneInfoNotFoundError):
            raise ValidationError(
                {"timezone": "Use an IANA time zone name, for example “Africa/Kampala”."}
            )


class EventRegistration(TimestampedModel):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="event_registrations")
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name="registrations")
    status = models.CharField(max_length=16, default="registered")

    class Meta:
        ordering = ["-created_at"]
        constraints = [models.UniqueConstraint(fields=["user", "event"], name="unique_user_event_registration")]


class PrayerRequest(TimestampedModel):
    class Visibility(models.TextChoices):
        PRIVATE = "private", "Only me"
        GROUP = "group", "My selected group"
        PUBLIC = "public", "Community prayer wall"

    class ModerationState(models.TextChoices):
        PENDING = "pending", "Pending review"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Not approved"

    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="prayer_requests")
    group = models.ForeignKey(DiscipleshipGroup, on_delete=models.SET_NULL, null=True, blank=True, related_name="prayer_requests")
    body = models.TextField()
    visibility = models.CharField(max_length=12, choices=Visibility.choices, default=Visibility.PRIVATE)
    share_consent = models.BooleanField(default=False)
    moderation_state = models.CharField(max_length=12, choices=ModerationState.choices, default=ModerationState.PENDING)

    class Meta:
        ordering = ["-created_at"]

    def clean(self):
        super().clean()
        if self.visibility != self.Visibility.PRIVATE and not self.share_consent:
            raise ValidationError({"share_consent": "Consent is required before sharing a prayer request."})
        if self.visibility == self.Visibility.GROUP and self.group_id is None:
            raise ValidationError({"group": "Choose the group that may see this request."})
        if self.visibility != self.Visibility.GROUP and self.group_id is not None:
            raise ValidationError({"group": "A group can only be selected for group sharing."})


class ContentVersion(models.Model):
    """One row, one integer: has anything the app reads changed?

    The mobile app keeps a copy of every list it has shown, and a student who
    returns to it after a worker edits a devotion should not have to restart the
    app to see that edit. Rather than refetch every endpoint on every resume,
    the app reads this number: unchanged means the copies it holds are still the
    copies the server would send, changed means the screens that loaded under an
    older number refetch themselves.

    It lives in the database rather than in the cache because the cache this
    deployment runs on is per-process memory: a bump made by one web worker
    would be invisible to another, and a restart would forget it entirely.
    """

    value = models.BigIntegerField(default=1)

    def __str__(self):
        return str(self.value)

    @classmethod
    def current(cls):
        row = cls.objects.filter(pk=1).first()
        return row.value if row is not None else 0

    @classmethod
    def bump(cls):
        """Count one authored change and return the new number.

        The row is created before it is incremented because an UPDATE that
        matches nothing silently loses the bump. `get_or_create` absorbs the
        two-workers-creating-the-same-row race, and the increment is a single
        `F` update rather than a read-modify-write, so two saves in the same
        millisecond cannot land on one version.
        """
        cls.objects.get_or_create(pk=1, defaults={"value": 0})
        cls.objects.filter(pk=1).update(value=F("value") + 1)
        return cls.objects.get(pk=1).value
