from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers

from .media_refs import youtube_thumbnail
from .services import media_file_url
from .translation import translate_value
from .models import (Article, BibleBookmark, BibleBook, BibleChapter, BibleNote, BibleReadingAssignment,
                     BibleReadingPlan, BibleReadingProgress, BibleTranslation, BibleVerse, ContentVersion,
                     MediaCollection, MediaItem, MediaNote, MediaWatch,
                     MemoryVerse, UserMemoryVerseProgress,
                     Campus, DiscipleshipGroup, Event, EventRegistration, Fellowship, GroupMembership,
                     PrayerRequest, University, Devotional, DevotionalSeries, ResourceStep, ResourceTopic,
                     UserContentProgress)


def request_language(context):
    request = context.get("request")
    if request is None:
        return "en"
    requested = request.query_params.get("language") or request.headers.get("Accept-Language", "")
    return "fr" if str(requested).strip().lower().startswith("fr") else "en"


def localized_value(instance, field, context):
    value = getattr(instance, field)
    if request_language(context) != "fr":
        return value
    translations = getattr(instance, "translations", {}) or {}
    french = translations.get("fr", {}) if isinstance(translations, dict) else {}
    translated = french.get(field) if isinstance(french, dict) else None
    if translated not in (None, ""):
        return translated
    # Scripture text and references must come from a reviewed Bible edition,
    # never from general-purpose machine translation.
    if field in getattr(instance, "translation_excluded_fields", ()):
        return value
    return translate_value(value, "fr")


class LocalizedModelSerializer(serializers.ModelSerializer):
    localized_fields = ()

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if request_language(self.context) != "fr":
            return data
        for field in self.localized_fields:
            if field in data:
                data[field] = localized_value(instance, field, self.context)
        return data


class ContentStampedSerializerMixin(serializers.Serializer):
    """Say which copy of the library a payload carries.

    The app stamps the copy it saves with this number, so a screen can tell that
    what it has on the device is older than what the ministry published next.
    The number travels with the content rather than only on its own endpoint
    because a response cannot be dated by a request that raced it.

    Based on `Serializer` so that the declared field below is collected: DRF
    only inherits declared fields from serializer classes.
    """

    content_version = serializers.SerializerMethodField(
        help_text="The server's change stamp for this payload."
    )

    def get_content_version(self, instance):
        return ContentVersion.current()


class BibleTranslationSerializer(serializers.ModelSerializer):
    class Meta:
        model = BibleTranslation
        fields = ("id", "code", "name", "license_name", "attribution", "source_url", "offline_allowed", "source_provider")


class BibleBookSerializer(serializers.ModelSerializer):
    chapter_count = serializers.IntegerField(read_only=True)
    provider_id = serializers.CharField(read_only=True)

    class Meta:
        model = BibleBook
        fields = ("id", "provider_id", "name", "order", "testament", "chapter_count")


class BibleVerseSerializer(serializers.ModelSerializer):
    reference = serializers.SerializerMethodField()

    class Meta:
        model = BibleVerse
        fields = ("id", "number", "text", "reference")

    def get_reference(self, verse):
        return f"{verse.chapter.book.name} {verse.chapter.number}:{verse.number}"


class BibleChapterSerializer(serializers.ModelSerializer):
    book = serializers.CharField(source="book.name", read_only=True)
    translation = serializers.CharField(source="book.translation.code", read_only=True)
    verses = BibleVerseSerializer(many=True, read_only=True)

    class Meta:
        model = BibleChapter
        fields = ("id", "book", "number", "translation", "verses")


class BibleAssignmentSerializer(LocalizedModelSerializer):
    localized_fields = BibleReadingAssignment.localized_fields
    completed = serializers.SerializerMethodField()

    class Meta:
        model = BibleReadingAssignment
        fields = ("id", "day", "reference", "completed")

    def get_completed(self, assignment):
        user = self.context["request"].user
        return BibleReadingProgress.objects.filter(user=user, assignment=assignment, completed_at__isnull=False).exists() if user.is_authenticated else False


class BiblePlanSerializer(LocalizedModelSerializer):
    localized_fields = BibleReadingPlan.localized_fields
    assignments = BibleAssignmentSerializer(many=True, read_only=True)

    class Meta:
        model = BibleReadingPlan
        fields = ("id", "title", "description", "assignments")


class BibleBookmarkSerializer(serializers.ModelSerializer):
    verse_id = serializers.PrimaryKeyRelatedField(
        source="verse", queryset=BibleVerse.objects.filter(chapter__book__translation__is_active=True)
    )
    reference = serializers.SerializerMethodField()
    text = serializers.CharField(source="verse.text", read_only=True)

    class Meta:
        model = BibleBookmark
        fields = ("id", "verse_id", "reference", "text", "created_at")
        read_only_fields = ("id", "created_at")

    def get_reference(self, obj):
        return f"{obj.verse.chapter.book.name} {obj.verse.chapter.number}:{obj.verse.number}"

    def create(self, data):
        return BibleBookmark.objects.get_or_create(user=self.context["request"].user, verse=data["verse"])[0]

    def validate_verse_id(self, verse):
        return verse


class BibleNoteSerializer(serializers.ModelSerializer):
    verse_id = serializers.PrimaryKeyRelatedField(
        source="verse", queryset=BibleVerse.objects.filter(chapter__book__translation__is_active=True)
    )
    reference = serializers.SerializerMethodField()

    class Meta:
        model = BibleNote
        fields = ("id", "verse_id", "reference", "body", "updated_at")
        read_only_fields = ("id", "updated_at")

    def get_reference(self, obj):
        return f"{obj.verse.chapter.book.name} {obj.verse.chapter.number}:{obj.verse.number}"

    def create(self, data):
        return BibleNote.objects.update_or_create(user=self.context["request"].user, verse=data["verse"], defaults={"body": data["body"]})[0]

    def validate_verse_id(self, verse):
        return verse


class BibleProgressSerializer(serializers.ModelSerializer):
    assignment = serializers.PrimaryKeyRelatedField(
        queryset=BibleReadingAssignment.objects.filter(plan__is_published=True)
    )

    class Meta:
        model = BibleReadingProgress
        fields = ("id", "assignment", "completed_at")
        read_only_fields = ("id", "completed_at")

    def create(self, data):
        from django.utils import timezone
        return BibleReadingProgress.objects.update_or_create(user=self.context["request"].user, assignment=data["assignment"], defaults={"completed_at": timezone.now()})[0]


class MediaCollectionSerializer(ContentStampedSerializerMixin, LocalizedModelSerializer):
    """One shelf of recordings in the Learn tab.

    `item_count` is what the app dares to promise: the list only returns shelves
    with a published recording on them, so a row never opens on an empty list.
    Whether each of those recordings plays is decided per recording — a shelf is
    not the place to promise it.
    """

    localized_fields = MediaCollection.localized_fields
    item_count = serializers.IntegerField(read_only=True)
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = MediaCollection
        fields = (
            "id",
            "title",
            "description",
            "order",
            "publish_at",
            "image_url",
            "item_count",
            "content_version",
        )
        read_only_fields = fields

    def get_image_url(self, collection):
        return media_file_url(collection.image, self.context.get("request"))


class MediaCollectionDetailSerializer(MediaCollectionSerializer):
    """The shelf opened: the same row fields plus the recordings on it."""

    items = serializers.SerializerMethodField()

    class Meta(MediaCollectionSerializer.Meta):
        fields = MediaCollectionSerializer.Meta.fields + ("items",)
        read_only_fields = fields

    def get_items(self, collection):
        return MediaItemRowSerializer(collection.items_live(), many=True, context=self.context).data


class MediaItemRowSerializer(LocalizedModelSerializer):
    """A recording in a list: enough to choose one, none of the description."""

    localized_fields = MediaItem.localized_fields
    image_url = serializers.SerializerMethodField()
    youtube_video_id = serializers.SerializerMethodField()
    watched = serializers.SerializerMethodField()

    class Meta:
        model = MediaItem
        fields = (
            "id",
            "title",
            "author",
            "excerpt",
            "order",
            "publish_at",
            "duration_seconds",
            "image_url",
            "youtube_video_id",
            "watched",
        )
        read_only_fields = fields

    def get_image_url(self, item):
        # Ministry artwork first; otherwise the frame YouTube already publishes
        # for the video, so a shelf of recordings is never a wall of text.
        return (
            media_file_url(item.image, self.context.get("request"))
            or youtube_thumbnail(item.youtube_url)
        )

    def get_youtube_video_id(self, item):
        return item.youtube_video_id

    def get_watched(self, item):
        user = self.context["request"].user
        if not user.is_authenticated:
            return False
        return MediaWatch.objects.filter(user=user, item=item, completed_at__isnull=False).exists()


class MediaItemDetailSerializer(ContentStampedSerializerMixin, MediaItemRowSerializer):
    """The watch page: the recording, the shelf it sits on, and this student's own state.

    The note and the resume position travel with the recording rather than
    behind a second request, because opening a video is one action and the
    student's own state belongs to the same screen.
    """

    collection = serializers.SerializerMethodField()
    note = serializers.SerializerMethodField()
    watch = serializers.SerializerMethodField()

    class Meta(MediaItemRowSerializer.Meta):
        fields = MediaItemRowSerializer.Meta.fields + (
            "body",
            "youtube_url",
            "download_url",
            "collection",
            "note",
            "watch",
            "content_version",
        )
        read_only_fields = fields

    def get_collection(self, item):
        return {
            "id": str(item.collection_id),
            "title": item.collection.title,
            "item_count": item.collection.items_live().count(),
        }

    def get_note(self, item):
        user = self.context["request"].user
        if not user.is_authenticated:
            return None
        note = MediaNote.objects.filter(user=user, item=item).first()
        if note is None:
            return None
        return {"text": note.body, "updated_at": note.updated_at}

    def get_watch(self, item):
        user = self.context["request"].user
        if not user.is_authenticated:
            return None
        watch = MediaWatch.objects.filter(user=user, item=item).first()
        if watch is None:
            return None
        return {
            "position_seconds": watch.position_seconds,
            "completed": watch.completed_at is not None,
            "updated_at": watch.updated_at,
        }


class MediaNoteWriteSerializer(serializers.Serializer):
    """One field, because a note is either what the student wrote or nothing.

    Blank text deletes rather than storing an empty note: an empty note is not a
    record of anything, and leaving it behind would show the student a note they
    already removed.
    """

    text = serializers.CharField(allow_blank=True, max_length=4000)

    def save_for(self, item):
        user = self.context["request"].user
        text = self.validated_data["text"].strip()
        if not text:
            MediaNote.objects.filter(user=user, item=item).delete()
            return None
        return MediaNote.objects.update_or_create(user=user, item=item, defaults={"body": text})[0]


class MediaWatchWriteSerializer(serializers.Serializer):
    """Where the student stopped, and whether they finished.

    `position_seconds` is accepted even past the end: the player is the only
    thing that knows the real duration, and a resume point the player clamps is
    harmless, while a refused write loses the student's place.
    """

    position_seconds = serializers.IntegerField(min_value=0, required=False, default=0)
    completed = serializers.BooleanField(default=True)

    def save_for(self, item):
        user = self.context["request"].user
        completed = self.validated_data["completed"]
        defaults = {"position_seconds": self.validated_data["position_seconds"]}
        # Un-marking a recording clears the completion rather than keeping a
        # stale timestamp, which is the only reason the app would send false.
        defaults["completed_at"] = timezone.now() if completed else None
        return MediaWatch.objects.update_or_create(user=user, item=item, defaults=defaults)[0]


class MemoryVerseSerializer(LocalizedModelSerializer):
    """The same row the home screen features and the Learn tab drills.

    Text is either a synced verse — whose own translation edition governs it,
    including in French — or a reviewed copy stored on this row, where a French
    override may exist.
    """

    verse_id = serializers.SerializerMethodField()
    reference = serializers.SerializerMethodField()
    text = serializers.SerializerMethodField()
    translation = serializers.SerializerMethodField()
    attribution = serializers.SerializerMethodField()
    completed = serializers.SerializerMethodField()
    localized_fields = ("prompt",)

    class Meta:
        model = MemoryVerse
        fields = ("id", "verse_id", "reference", "text", "translation", "attribution", "prompt", "completed")

    def _stored_or_linked(self, item, field, linked_value):
        return linked_value if item.verse_id is not None else localized_value(item, field, self.context)

    def get_verse_id(self, item):
        return str(item.verse_id) if item.verse_id is not None else ""

    def get_reference(self, item):
        return self._stored_or_linked(item, "reference", item.display_reference)

    def get_text(self, item):
        return self._stored_or_linked(item, "text", item.display_text)

    def get_translation(self, item):
        return item.display_translation_code

    def get_attribution(self, item):
        return self._stored_or_linked(item, "attribution", item.display_attribution)

    def get_completed(self, item):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if user is None or not user.is_authenticated:
            return False
        return UserMemoryVerseProgress.objects.filter(
            user=user, memory_verse=item, completed_at__isnull=False
        ).exists()


class MemoryVerseProgressSerializer(serializers.ModelSerializer):
    memory_verse = serializers.PrimaryKeyRelatedField(
        queryset=MemoryVerse.objects.filter(is_published=True).filter(
            # The null branch has to be explicit: `exclude` across a nullable
            # relation would drop every stored-copy row with it.
            Q(verse__isnull=True) | Q(verse__chapter__book__translation__is_active=True)
        )
    )

    class Meta:
        model = UserMemoryVerseProgress
        fields = ("id", "memory_verse", "completed_at", "review_count")
        read_only_fields = ("id", "completed_at", "review_count")

    def create(self, validated_data):
        from django.utils import timezone
        row, _ = UserMemoryVerseProgress.objects.get_or_create(user=self.context["request"].user, memory_verse=validated_data["memory_verse"])
        row.completed_at = timezone.now()
        row.review_count += 1
        row.save(update_fields=["completed_at", "review_count", "updated_at"])
        return row


class UniversitySerializer(LocalizedModelSerializer):
    localized_fields = University.localized_fields
    class Meta:
        model = University
        fields = ("id", "name", "country", "city", "website")
        read_only_fields = fields


class CampusSerializer(LocalizedModelSerializer):
    university = serializers.SerializerMethodField()
    localized_fields = Campus.localized_fields

    class Meta:
        model = Campus
        fields = ("id", "university", "name", "location")
        read_only_fields = fields

    def get_university(self, campus):
        return localized_value(campus.university, "name", self.context)


class FellowshipSerializer(LocalizedModelSerializer):
    campus = serializers.SerializerMethodField()
    university = serializers.SerializerMethodField()
    localized_fields = Fellowship.localized_fields

    class Meta:
        model = Fellowship
        fields = ("id", "campus", "university", "name", "description", "meeting_schedule")
        read_only_fields = fields

    def get_campus(self, fellowship):
        return localized_value(fellowship.campus, "name", self.context)

    def get_university(self, fellowship):
        return localized_value(fellowship.campus.university, "name", self.context)


class GroupSerializer(LocalizedModelSerializer):
    campus = serializers.SerializerMethodField()
    membership_status = serializers.SerializerMethodField()
    member_count = serializers.SerializerMethodField()
    is_leader = serializers.SerializerMethodField()
    localized_fields = DiscipleshipGroup.localized_fields

    class Meta:
        model = DiscipleshipGroup
        fields = ("id", "campus", "name", "description", "group_type", "capacity", "membership_status", "member_count", "is_leader")
        read_only_fields = fields

    def get_membership_status(self, group):
        user = self.context["request"].user
        if not user.is_authenticated:
            return None
        return GroupMembership.objects.filter(user=user, group=group).values_list("status", flat=True).first()

    def get_campus(self, group):
        return localized_value(group.campus, "name", self.context) if group.campus else None

    def get_member_count(self, group):
        return GroupMembership.objects.filter(group=group, status=GroupMembership.Status.APPROVED).count()

    def get_is_leader(self, group):
        user = self.context["request"].user
        return user.is_authenticated and group.leader_id == user.id


class GroupMembershipSerializer(serializers.ModelSerializer):
    group = serializers.SerializerMethodField()
    member_name = serializers.CharField(source="user.display_name", read_only=True)

    class Meta:
        model = GroupMembership
        fields = ("id", "group", "member_name", "status", "requested_at", "approved_at")
        read_only_fields = fields

    def get_group(self, membership):
        return localized_value(membership.group, "name", self.context)


class EventSerializer(LocalizedModelSerializer):
    campus = serializers.SerializerMethodField()
    registered = serializers.SerializerMethodField()
    registration_count = serializers.SerializerMethodField()
    online_url = serializers.SerializerMethodField()
    localized_fields = Event.localized_fields

    class Meta:
        model = Event
        fields = ("id", "campus", "title", "description", "starts_at", "ends_at", "timezone", "location", "online_url", "capacity", "registered", "registration_count")
        read_only_fields = fields

    def get_registered(self, event):
        user = self.context["request"].user
        return EventRegistration.objects.filter(user=user, event=event, status="registered").exists() if user.is_authenticated else False

    def get_campus(self, event):
        return localized_value(event.campus, "name", self.context) if event.campus else None

    def get_registration_count(self, event):
        return EventRegistration.objects.filter(event=event, status="registered").count()

    def get_online_url(self, event):
        user = self.context["request"].user
        if not user.is_authenticated:
            return ""
        registered = EventRegistration.objects.filter(user=user, event=event, status="registered").exists()
        return event.online_url if registered else ""


class PrayerRequestSerializer(serializers.ModelSerializer):
    is_owner = serializers.SerializerMethodField()

    class Meta:
        model = PrayerRequest
        fields = ("id", "body", "visibility", "group", "share_consent", "moderation_state", "created_at", "is_owner")
        read_only_fields = ("id", "moderation_state", "created_at")

    def get_is_owner(self, prayer):
        return self.context["request"].user.is_authenticated and prayer.owner_id == self.context["request"].user.id

    def validate(self, attrs):
        visibility = attrs.get("visibility", getattr(self.instance, "visibility", PrayerRequest.Visibility.PRIVATE))
        group = attrs.get("group", getattr(self.instance, "group", None))
        consent = attrs.get("share_consent", getattr(self.instance, "share_consent", False))
        if visibility != PrayerRequest.Visibility.PRIVATE and not consent:
            raise serializers.ValidationError({"share_consent": "Give explicit consent before sharing this request."})
        if visibility == PrayerRequest.Visibility.GROUP:
            if group is None:
                raise serializers.ValidationError({"group": "Choose a group for this prayer request."})
            if not GroupMembership.objects.filter(user=self.context["request"].user, group=group, status=GroupMembership.Status.APPROVED).exists():
                raise serializers.ValidationError({"group": "Join the group before sharing a request with it."})
        elif group is not None:
            raise serializers.ValidationError({"group": "Choose a group only for group sharing."})
        return attrs

    def create(self, validated_data):
        visibility = validated_data.get("visibility", PrayerRequest.Visibility.PRIVATE)
        state = PrayerRequest.ModerationState.APPROVED if visibility == PrayerRequest.Visibility.PRIVATE else PrayerRequest.ModerationState.PENDING
        return PrayerRequest.objects.create(owner=self.context["request"].user, moderation_state=state, **validated_data)

    def update(self, instance, validated_data):
        for key, value in validated_data.items():
            setattr(instance, key, value)
        if instance.visibility != PrayerRequest.Visibility.PRIVATE:
            instance.moderation_state = PrayerRequest.ModerationState.PENDING
        instance.save()
        return instance


class PrayerModerationSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrayerRequest
        fields = ("id", "body", "visibility", "moderation_state", "created_at")
        read_only_fields = ("id", "body", "visibility", "created_at")

    def validate_moderation_state(self, value):
        if value not in (PrayerRequest.ModerationState.APPROVED, PrayerRequest.ModerationState.REJECTED):
            raise serializers.ValidationError("Moderation must approve or reject the shared request.")
        return value


class DevotionalSerializer(LocalizedModelSerializer):
    localized_fields = Devotional.localized_fields
    series_title = serializers.CharField(source="series.title", read_only=True, default="")
    class Meta:
        model = Devotional
        fields = (
            "id",
            "title",
            "author",
            "scripture_reference",
            "excerpt",
            "body",
            "reflection_questions",
            "application",
            "prayer",
            "memory_scripture_reference",
            "reading_minutes",
            "publish_at",
            "series",
            "series_title",
            "day",
        )
        read_only_fields = fields


class DevotionalSeriesSerializer(ContentStampedSerializerMixin, LocalizedModelSerializer):
    """One card in the Devotions grid, with how many days a student can read."""

    localized_fields = DevotionalSeries.localized_fields
    day_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = DevotionalSeries
        fields = (
            "id",
            "title",
            "description",
            "cover_image_url",
            "order",
            "publish_at",
            "day_count",
            "content_version",
        )
        read_only_fields = fields


class DevotionalDaySerializer(LocalizedModelSerializer):
    """A row in a series: enough to choose, none of the body."""

    localized_fields = Devotional.localized_fields

    class Meta:
        model = Devotional
        fields = (
            "id",
            "title",
            "day",
            "scripture_reference",
            "excerpt",
            "reading_minutes",
        )
        read_only_fields = fields


class DevotionalSeriesDetailSerializer(DevotionalSeriesSerializer):
    days = serializers.SerializerMethodField()

    class Meta(DevotionalSeriesSerializer.Meta):
        fields = DevotionalSeriesSerializer.Meta.fields + ("days",)
        read_only_fields = fields

    def get_days(self, item):
        return DevotionalDaySerializer(
            item.days_live(), many=True, context=self.context
        ).data


class ArticleSerializer(LocalizedModelSerializer):
    localized_fields = Article.localized_fields
    class Meta:
        model = Article
        fields = (
            "id",
            "title",
            "author",
            "category",
            "excerpt",
            "body",
            "reading_minutes",
            "publish_at",
        )
        read_only_fields = fields


class ResourceTopicSerializer(ContentStampedSerializerMixin, LocalizedModelSerializer):
    """One row of the home 'Find resources on' list.

    `step_count` is what the app dares to promise: the list view only returns
    topics with a readable step, so a row that renders always opens on content.
    """

    localized_fields = ResourceTopic.localized_fields
    step_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = ResourceTopic
        fields = (
            "id",
            "title",
            "summary",
            "order",
            "publish_at",
            "step_count",
            "content_version",
        )
        read_only_fields = fields


class ResourceStepRowSerializer(LocalizedModelSerializer):
    """A step inside a guide: enough to choose, none of the body."""

    localized_fields = ResourceStep.localized_fields

    class Meta:
        model = ResourceStep
        fields = (
            "id",
            "title",
            "order",
            "scripture_reference",
            "excerpt",
            "reading_minutes",
            "video_url",
        )
        read_only_fields = fields


class ResourceTopicDetailSerializer(ResourceTopicSerializer):
    steps = serializers.SerializerMethodField()

    class Meta(ResourceTopicSerializer.Meta):
        fields = ResourceTopicSerializer.Meta.fields + ("steps",)
        read_only_fields = fields

    def get_steps(self, item):
        return ResourceStepRowSerializer(item.steps_live(), many=True, context=self.context).data


class ResourceStepSerializer(LocalizedModelSerializer):
    """The reader's copy of one step, plus where it sits in its guide."""

    localized_fields = ResourceStep.localized_fields
    topic = serializers.SerializerMethodField()

    class Meta:
        model = ResourceStep
        fields = (
            "id",
            "title",
            "author",
            "scripture_reference",
            "excerpt",
            "body",
            "reading_minutes",
            "publish_at",
            "order",
            "video_url",
            "topic",
        )
        read_only_fields = fields

    def get_topic(self, step):
        return {
            "id": str(step.topic_id),
            "title": step.topic.title,
            "step_count": step.topic.steps_live().count(),
        }


class HomeSerializer(ContentStampedSerializerMixin, serializers.Serializer):
    """Dashboard payload; every section is server-curated so no app release is needed."""

    greeting = serializers.CharField()
    memory_verse = MemoryVerseSerializer(allow_null=True)
    devotion = DevotionalSerializer(allow_null=True)
    articles = ArticleSerializer(many=True)
    resources = serializers.SerializerMethodField()
    server_time = serializers.DateTimeField()

    def get_resources(self, payload):
        return ResourceTopicSerializer(
            payload["resources"], many=True, context=self.context
        ).data


class ContentVersionSerializer(serializers.Serializer):
    version = serializers.IntegerField()


class ProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserContentProgress
        fields = ("id", "kind", "content_id", "completed_at", "note")
        read_only_fields = ("id", "completed_at")

    def validate(self, attrs):
        kind = attrs.get("kind") or getattr(self.instance, "kind", None)
        content_id = attrs.get("content_id") or getattr(self.instance, "content_id", None)
        model = {
            UserContentProgress.Kind.DEVOTIONAL: Devotional,
            UserContentProgress.Kind.ARTICLE: Article,
            UserContentProgress.Kind.RESOURCE_STEP: ResourceStep,
        }.get(kind)
        if model is None:
            raise serializers.ValidationError({"kind": "Unsupported content kind."})
        if not model.objects.filter(pk=content_id).exists():
            raise serializers.ValidationError({"content_id": f"No {kind} exists with this id."})
        attrs["kind"], attrs["content_id"] = kind, content_id
        return attrs

    def create(self, validated_data):
        # Re-recording the same content refreshes the note without duplicating history.
        return UserContentProgress.objects.update_or_create(
            user=self.context["request"].user,
            kind=validated_data["kind"],
            content_id=validated_data["content_id"],
            defaults={"note": validated_data.get("note", "")},
        )[0]
