"""Staff curation serializers for the ministry console.

These deliberately do not reuse the student serializers in
`content/serializers.py`, because the two surfaces disagree on three things:

* curation must show drafts and unpublished rows, so none of the
  `published()` / `is_active` filtering can be inherited here;
* French overrides come back as the raw `translations` map rather than a
  resolved string, because staff review what is actually stored instead of
  reading a translation provider's best guess;
* a cover is a file staff upload here, while the student API only ever reads a
  URL back — which is why `MediaItemAdminSerializer` carries both `image` and
  `image_url` and the read-only serializer carries neither.

Every write runs `Model.full_clean()`. The licensing guard on
`MemoryVerse.clean`, the HTTPS and YouTube-link rules on `MediaItem`/`Event` and
the guide ordering rules therefore cannot be sidestepped by posting JSON over
HTTP, and the models stay the single place where those rules are stated.
"""

import copy

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils import timezone
from rest_framework import serializers
from rest_framework.fields import get_error_detail
from rest_framework.validators import UniqueTogetherValidator

from .media_refs import youtube_thumbnail
from .models import (Article, BibleReadingAssignment, BibleReadingPlan, BibleTranslation,
                     BibleVerse, Campus, Devotional,
                     DevotionalSeries, DiscipleshipGroup, Event, Fellowship,
                     MediaCollection, MediaItem, MemoryVerse, ResourceStep, ResourceTopic, University)
from .services import media_file_url

# `content.translation.translate_strings` only ever speaks French, so accepting
# any other locale here would store a key no reader can ever resolve.
SUPPORTED_LOCALES = ("fr",)


class CurationSerializerMixin:
    """Push every write through the model's own validation.

    This runs in `create()`/`update()` rather than in `validate()`, because a
    nested view injects its parent after validation (
    `serializer.save(topic=...)`), and validating a row without its parent
    would reject a perfectly legal step, assignment or recording. The row is
    still checked before it reaches the database, and a refusal comes back as
    the normal 400 envelope.
    """

    def create(self, validated_data):
        draft = self.Meta.model(**validated_data)
        self._run_model_validation(draft)
        return super().create(validated_data)

    def update(self, instance, validated_data):
        draft = copy.copy(instance)
        for name, value in self._model_values(validated_data):
            setattr(draft, name, value)
        self._run_model_validation(draft)
        return super().update(instance, validated_data)

    def _run_model_validation(self, draft):
        try:
            draft.full_clean()
        except DjangoValidationError as error:
            raise serializers.ValidationError(get_error_detail(error)) from error

    def _model_values(self, attrs):
        """Map serializer field names onto model attributes.

        Computed values (`source="verse.text"` and the like) have no model
        attribute to validate, so they are skipped.
        """
        resolved = {}
        for name, value in attrs.items():
            field = self.fields.get(name)
            source = getattr(field, "source", None) or name
            if "." in source:
                continue
            resolved[source] = value
        return resolved.items()

    def validate_translations(self, value):
        if value in (None, ""):
            return {}
        if not isinstance(value, dict):
            raise serializers.ValidationError("Translations must be an object keyed by locale.")
        allowed = set(self.Meta.model.localized_fields)
        cleaned = {}
        for locale, entries in value.items():
            if locale not in SUPPORTED_LOCALES:
                raise serializers.ValidationError(
                    f"Only {', '.join(SUPPORTED_LOCALES)} translations are stored; got '{locale}'."
                )
            if not isinstance(entries, dict):
                raise serializers.ValidationError(f"The '{locale}' entry must map field names to text.")
            unknown = sorted(set(entries) - allowed)
            if unknown:
                raise serializers.ValidationError(
                    f"{', '.join(unknown)} cannot be translated on a {self.Meta.model.__name__}."
                )
            rows = {}
            for name, text in entries.items():
                if isinstance(text, str):
                    if text.strip():
                        rows[name] = text
                elif isinstance(text, list):
                    rows[name] = text
                else:
                    raise serializers.ValidationError(
                        f"The French '{name}' must be text or a list of strings."
                    )
            if rows:
                cleaned[locale] = rows
        return cleaned


class PublishStateFields(serializers.Serializer):
    """`draft` / `scheduled` / `live`, the three states the Django Admin list
    already shows (`content.admin.PublishedContentAdmin.publish_state`).

    Publishing is a plain `PATCH` of `is_published` and `publish_at`, the same
    two fields the admin change form edits; there is no separate action route.

    This is a `Serializer` subclass rather than a bare mixin because DRF's
    metaclass only collects declared fields from serializer bases: as a plain
    mixin the field would silently vanish and `Meta.fields` would then be
    rejected as an unknown model field.
    """

    publish_state = serializers.SerializerMethodField()

    def get_publish_state(self, obj):
        if not obj.is_published:
            return "draft"
        publish_at = getattr(obj, "publish_at", None)
        if publish_at and publish_at > timezone.now():
            return "scheduled"
        return "live"


class DevotionalSeriesAdminSerializer(CurationSerializerMixin, PublishStateFields, serializers.ModelSerializer):
    day_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = DevotionalSeries
        fields = (
            "id", "title", "description", "cover_image_url", "order",
            "is_published", "publish_at", "publish_state", "day_count",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "publish_state", "day_count", "created_at", "updated_at")

    def validate_cover_image_url(self, value):
        # The app loads this with Image.network; a relative path would fail at
        # render time on a device and only in the field editor here.
        if value and not value.startswith(("http://", "https://")):
            raise serializers.ValidationError("Cover art needs a full https:// URL the app can load.")
        return value


class ConditionalUniqueValidator(UniqueTogetherValidator):
    """A model's *conditional* unique constraint, minus the implied requirement.

    DRF reads `UniqueConstraint(fields=("series", "day"), condition=…)` as a
    required-together rule and refuses any create that omits either field. That
    reading only holds for rows the condition selects: a devotion filed under no
    series is a one-off reading with no day, and there is nothing to compare it
    against. A duplicate day inside a series is still refused.
    """

    def __init__(self, original):
        super().__init__(
            queryset=original.queryset,
            fields=original.fields,
            message=original.message,
            condition_fields=original.condition_fields,
            condition=original.condition,
            code=original.code,
            nulls_distinct=original.nulls_distinct,
        )

    def enforce_required_fields(self, attrs, serializer):
        """Neither field is required on its own; only their pairing is unique."""

    def __call__(self, attrs, serializer):
        # The base validator indexes `attrs` for every field it covers, so a row
        # that carries only half the pairing is skipped instead of probed.
        sources = [serializer.fields[name].source for name in self.fields]
        if any(source not in attrs for source in sources):
            return
        super().__call__(attrs, serializer)


class DevotionalAdminSerializer(CurationSerializerMixin, PublishStateFields, serializers.ModelSerializer):
    series = serializers.PrimaryKeyRelatedField(
        queryset=DevotionalSeries.objects.all(), allow_null=True, required=False
    )
    # The console lists days from every series at once, so a bare key is not
    # enough to tell staff where a reading belongs. A method field rather than
    # `source="series.title"` because DRF drops that key entirely when the
    # devotion has no series, and the console then shows an empty cell that is
    # indistinguishable from a payload that never carried the column.
    series_title = serializers.SerializerMethodField()

    class Meta:
        model = Devotional
        fields = (
            "id", "title", "author", "scripture_reference", "excerpt", "body",
            "reflection_questions", "application", "prayer", "memory_scripture_reference",
            "reading_minutes", "series", "series_title", "day",
            "is_published", "publish_at", "publish_state",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "series_title", "publish_state", "created_at", "updated_at")

    def get_series_title(self, obj):
        return obj.series.title if obj.series_id else None

    def get_validators(self):
        return [
            ConditionalUniqueValidator(validator)
            if isinstance(validator, UniqueTogetherValidator) and validator.condition is not None
            else validator
            for validator in super().get_validators()
        ]


class ArticleAdminSerializer(CurationSerializerMixin, PublishStateFields, serializers.ModelSerializer):
    class Meta:
        model = Article
        fields = (
            "id", "title", "author", "category", "excerpt", "body", "reading_minutes",
            "is_published", "publish_at", "publish_state",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "publish_state", "created_at", "updated_at")


class ResourceTopicAdminSerializer(CurationSerializerMixin, PublishStateFields, serializers.ModelSerializer):
    step_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = ResourceTopic
        fields = (
            "id", "title", "summary", "order",
            "is_published", "publish_at", "publish_state", "step_count",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "publish_state", "step_count", "created_at", "updated_at")


class ResourceStepAdminSerializer(CurationSerializerMixin, PublishStateFields, serializers.ModelSerializer):
    topic = serializers.PrimaryKeyRelatedField(queryset=ResourceTopic.objects.all())
    # A step listed alongside every other topic's steps is meaningless without
    # its guide's name, and a bare key cannot give it one.
    topic_title = serializers.SerializerMethodField()

    class Meta:
        model = ResourceStep
        fields = (
            "id", "topic", "topic_title", "title", "author", "scripture_reference",
            "excerpt", "body", "reading_minutes", "order", "video_url",
            "is_published", "publish_at", "publish_state",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "topic_title", "publish_state", "created_at", "updated_at")

    def get_topic_title(self, obj):
        return obj.topic.title if obj.topic_id else None

    def get_validators(self):
        return [
            ConditionalUniqueValidator(validator)
            if isinstance(validator, UniqueTogetherValidator) and validator.condition is not None
            else validator
            for validator in super().get_validators()
        ]


class BibleReadingPlanAdminSerializer(CurationSerializerMixin, PublishStateFields, serializers.ModelSerializer):
    assignment_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = BibleReadingPlan
        fields = (
            "id", "title", "description", "is_published", "publish_state", "assignment_count",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "publish_state", "assignment_count", "created_at", "updated_at")


class BibleReadingAssignmentAdminSerializer(CurationSerializerMixin, serializers.ModelSerializer):
    class Meta:
        model = BibleReadingAssignment
        fields = (
            "id", "plan", "day", "reference",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "plan", "created_at", "updated_at")


class MediaCollectionAdminSerializer(CurationSerializerMixin, PublishStateFields, serializers.ModelSerializer):
    """A shelf of recordings. `image` is a real upload, so the console posts
    multipart for it and Django Admin offers the same file picker."""

    item_count = serializers.IntegerField(read_only=True)
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = MediaCollection
        fields = (
            "id", "title", "description", "order", "image", "image_url",
            "is_published", "publish_at", "publish_state", "item_count",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "image_url", "publish_state", "item_count", "created_at", "updated_at")

    def get_image_url(self, obj):
        return media_file_url(obj.image, self.context.get("request"))


class MediaItemAdminSerializer(CurationSerializerMixin, PublishStateFields, serializers.ModelSerializer):
    collection = serializers.PrimaryKeyRelatedField(queryset=MediaCollection.objects.all())
    # A recording listed alongside every other shelf's items is meaningless
    # without the shelf it sits on, and a bare key cannot give it one.
    collection_title = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = MediaItem
        fields = (
            "id", "collection", "collection_title", "title", "author", "excerpt", "body",
            "order", "youtube_url", "download_url", "duration_seconds", "image", "image_url",
            "is_published", "publish_at", "publish_state",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = (
            "id", "collection_title", "image_url", "publish_state", "created_at", "updated_at",
        )

    def get_collection_title(self, obj):
        return obj.collection.title if obj.collection_id else None

    def get_image_url(self, obj):
        return media_file_url(obj.image, self.context.get("request")) or youtube_thumbnail(obj.youtube_url)

    def get_validators(self):
        return [
            ConditionalUniqueValidator(validator)
            if isinstance(validator, UniqueTogetherValidator) and validator.condition is not None
            else validator
            for validator in super().get_validators()
        ]


class MemoryVerseAdminSerializer(CurationSerializerMixin, PublishStateFields, serializers.ModelSerializer):
    """One row serves both jobs the app has: the verse of the day and the drill.

    `verse` is optional. Leave it empty, write the reference and the text, and
    this is how a deployment features a verse whose translation has not been
    imported; the licence list below is then what it may print. Pick a synced
    verse instead and its own translation's licence and attribution govern.
    """

    verse = serializers.PrimaryKeyRelatedField(
        queryset=BibleVerse.objects.filter(chapter__book__translation__is_active=True),
        allow_null=True,
        required=False,
    )
    display_reference = serializers.SerializerMethodField()
    display_text = serializers.SerializerMethodField()
    display_translation = serializers.SerializerMethodField()
    display_attribution = serializers.SerializerMethodField()
    allowed_translation_codes = serializers.SerializerMethodField()

    class Meta:
        model = MemoryVerse
        fields = (
            "id", "verse", "reference", "text", "translation_code", "attribution",
            "display_reference", "display_text", "display_translation", "display_attribution",
            "allowed_translation_codes", "prompt", "start_date", "end_date",
            "is_published", "publish_state",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = (
            "id", "display_reference", "display_text", "display_translation",
            "display_attribution", "allowed_translation_codes", "publish_state",
            "created_at", "updated_at",
        )

    def get_display_reference(self, obj):
        return obj.display_reference

    def get_display_text(self, obj):
        return obj.display_text

    def get_display_translation(self, obj):
        return obj.display_translation_code

    def get_display_attribution(self, obj):
        return obj.display_attribution

    def get_allowed_translation_codes(self, obj):
        # The console builds its translation dropdown from this, so the licence
        # list lives in settings alone.
        return list(getattr(settings, "UDM_MEMORY_VERSE_TRANSLATIONS", []))


class UniversityAdminSerializer(CurationSerializerMixin, serializers.ModelSerializer):
    campus_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = University
        fields = (
            "id", "name", "country", "city", "website", "is_active", "campus_count",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "campus_count", "created_at", "updated_at")


class CampusAdminSerializer(CurationSerializerMixin, serializers.ModelSerializer):
    university_name = serializers.CharField(source="university.name", read_only=True)
    fellowship_count = serializers.IntegerField(read_only=True)
    group_count = serializers.IntegerField(read_only=True)
    event_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Campus
        fields = (
            "id", "university", "university_name", "name", "location", "is_active",
            "fellowship_count", "group_count", "event_count",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "university_name", "fellowship_count", "group_count", "event_count",
                            "created_at", "updated_at")


class FellowshipAdminSerializer(CurationSerializerMixin, serializers.ModelSerializer):
    campus_name = serializers.CharField(source="campus.name", read_only=True)

    class Meta:
        model = Fellowship
        fields = (
            "id", "campus", "campus_name", "name", "description", "meeting_schedule",
            "is_public", "is_active",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "campus_name", "created_at", "updated_at")


class GroupAdminSerializer(CurationSerializerMixin, serializers.ModelSerializer):
    campus_name = serializers.CharField(source="campus.name", read_only=True)
    leader_name = serializers.CharField(source="leader.display_name", read_only=True)
    member_count = serializers.IntegerField(read_only=True)
    leader = serializers.PrimaryKeyRelatedField(
        queryset=get_user_model().objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = DiscipleshipGroup
        fields = (
            "id", "campus", "campus_name", "name", "description", "group_type",
            "leader", "leader_name", "visibility", "capacity", "is_active", "member_count",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "campus_name", "leader_name", "member_count", "created_at", "updated_at")


class EventAdminSerializer(CurationSerializerMixin, serializers.ModelSerializer):
    campus_name = serializers.CharField(source="campus.name", read_only=True)
    organizer_name = serializers.CharField(source="organizer.display_name", read_only=True)
    registration_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Event
        fields = (
            "id", "campus", "campus_name", "organizer", "organizer_name",
            "title", "description", "starts_at", "ends_at", "timezone", "location",
            "online_url", "capacity", "status", "registration_count",
            "translations", "created_at", "updated_at",
        )
        read_only_fields = ("id", "campus_name", "organizer_name", "registration_count",
                            "created_at", "updated_at")


class BibleVerseAdminSerializer(serializers.ModelSerializer):
    """Lookup rows for the memory-verse picker.

    A `MemoryVerse` points at a `BibleVerse` primary key, which nobody can type
    from memory. This reads the synced verse rows back by reference so the
    console can offer them as choices; it exposes no student data of any kind.
    """

    reference = serializers.SerializerMethodField()
    book = serializers.CharField(source="chapter.book.name", read_only=True)
    chapter = serializers.IntegerField(source="chapter.number", read_only=True)
    translation = serializers.CharField(source="chapter.book.translation.code", read_only=True)

    class Meta:
        model = BibleVerse
        fields = ("id", "reference", "book", "chapter", "number", "text", "translation")

    def get_reference(self, obj):
        return f"{obj.chapter.book.name} {obj.chapter.number}:{obj.number}"


class BibleTranslationAdminSerializer(serializers.ModelSerializer):
    """Read a translation record, flip `is_active`, nothing else.

    Scripture rows arrive from the YouVersion sync and from `scripts/`, never
    from a form, and deleting a translation would cascade through its verses to
    the bookmarks and notes students attached to them. So the console may only
    switch a translation on or off.
    """

    book_count = serializers.IntegerField(read_only=True)
    chapter_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = BibleTranslation
        fields = (
            "id", "code", "name", "license_name", "attribution", "source_url",
            "offline_allowed", "is_active", "source_provider", "book_count", "chapter_count",
            "created_at", "updated_at",
        )
        read_only_fields = tuple(name for name in fields if name != "is_active")
