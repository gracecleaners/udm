from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers

from .media_refs import youtube_thumbnail
from .services import artwork_url, media_file_url
from .models import (Article, BibleBookmark, BibleBook, BibleChapter, BibleNote, BibleReadingAssignment,
                     BibleReadingPlan, BibleReadingProgress, BibleTranslation, BibleVerse, ContentVersion,
                     MediaCollection, MediaItem, MediaNote, MediaWatch,
                     MemoryVerse, UserMemoryVerseProgress,
                     Campus, DiscipleshipGroup, Event, EventRegistration, Fellowship, GroupMembership,
                     PrayerAffirmation, PrayerComment, PrayerRequest, University, Devotional, DevotionalSeries, ResourceStep, ResourceTopic,
                     UserContentProgress, UserNotification, NotificationDevice)


def wall_name(user):
    """The name a shared item is printed under.

    Not `display_name`, which falls back to the address a student signed up
    with: a wall the whole campus reads never prints that.
    """
    profile = getattr(user, "profile", None)
    return profile.full_name if profile and profile.full_name else "A student"


def wall_photo(user, request):
    """The picture a shared item is printed under, or None.

    This is `wall_name`'s other half. A student who has not published a name
    appears on the wall as "A student", and putting their face beside that
    label would undo the choice that kept them anonymous, so a photo follows the
    name out rather than being served on its own. Without a name nothing is
    served at all; the app draws the initials tile it already draws.
    """
    profile = getattr(user, "profile", None)
    if not profile or not profile.full_name:
        return None
    return media_file_url(profile.photo, request)


def _count_or_query(row, annotated, related):
    """An annotated list row answers from the page's own query; a single row counts."""
    value = getattr(row, annotated, None)
    return value if value is not None else getattr(row, related).count()


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


class UserNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserNotification
        fields = ("id", "title", "body", "kind", "destination", "created_at", "read_at")


class NotificationDeviceSerializer(serializers.ModelSerializer):
    """One installation's token.

    The model's unique token is enforced by the view's `update_or_create`, not by
    a field validator: a phone that signs out of one account and into the next
    re-presents the token it already has, and refusing that would leave the old
    account holding a device nobody uses.
    """

    class Meta:
        model = NotificationDevice
        fields = ("token", "platform")
        extra_kwargs = {"token": {"validators": []}}


class NotificationBroadcastSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=160, trim_whitespace=True)
    body = serializers.CharField(max_length=600, trim_whitespace=True)
    kind = serializers.CharField(max_length=40, default="announcement")
    destination = serializers.CharField(max_length=240, required=False, allow_blank=True)

    def validate_destination(self, value):
        if value and (not value.startswith("/") or value.startswith("//")):
            raise serializers.ValidationError("Use an internal app route beginning with a single slash.")
        return value


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


class BibleAssignmentSerializer(serializers.ModelSerializer):
    completed = serializers.SerializerMethodField()

    class Meta:
        model = BibleReadingAssignment
        fields = (
            "id",
            "day",
            "title",
            "reference",
            "verse_reference",
            "verse_text",
            "what_it_says",
            "what_to_learn",
            "completed",
        )

    def get_completed(self, assignment):
        user = self.context["request"].user
        return BibleReadingProgress.objects.filter(user=user, assignment=assignment, completed_at__isnull=False).exists() if user.is_authenticated else False


class BiblePlanSerializer(serializers.ModelSerializer):
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


class MediaCollectionSerializer(ContentStampedSerializerMixin, serializers.ModelSerializer):
    """One shelf of recordings in the Learn tab.

    `item_count` is what the app dares to promise: the list only returns shelves
    with a published recording on them, so a row never opens on an empty list.
    Whether each of those recordings plays is decided per recording — a shelf is
    not the place to promise it.
    """

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
        return artwork_url(collection, self.context.get("request"))


class MediaCollectionDetailSerializer(MediaCollectionSerializer):
    """The shelf opened: the same row fields plus the recordings on it."""

    items = serializers.SerializerMethodField()

    class Meta(MediaCollectionSerializer.Meta):
        fields = MediaCollectionSerializer.Meta.fields + ("items",)
        read_only_fields = fields

    def get_items(self, collection):
        return MediaItemRowSerializer(collection.items_live(), many=True, context=self.context).data


class MediaItemRowSerializer(serializers.ModelSerializer):
    """A recording in a list: enough to choose one, none of the description."""

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
        # Ministry artwork first, whether staff uploaded it or linked it;
        # otherwise the frame YouTube already publishes for the video, so a
        # shelf of recordings is never a wall of text.
        return artwork_url(item, self.context.get("request")) or youtube_thumbnail(item.youtube_url)

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


class MediaResumeSerializer(serializers.ModelSerializer):
    """One recording the student stopped partway through, with where they stopped.

    The app asks for this directly instead of walking every shelf for the one
    place somebody left off, so the row carries the title, the artwork and the
    shelf it belongs to — everything a "Continue" card needs to be tappable.
    """

    id = serializers.UUIDField(source="item_id", read_only=True)
    title = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()
    duration_seconds = serializers.IntegerField(source="item.duration_seconds", read_only=True)
    collection = serializers.SerializerMethodField()

    class Meta:
        model = MediaWatch
        fields = ("id", "title", "image_url", "duration_seconds", "position_seconds", "collection")

    def get_title(self, watch):
        return watch.item.title

    def get_image_url(self, watch):
        return artwork_url(watch.item, self.context.get("request")) or youtube_thumbnail(
            watch.item.youtube_url
        )

    def get_collection(self, watch):
        collection = watch.item.collection
        if collection is None:
            return None
        return {
            "id": str(collection.pk),
            "title": collection.title,
        }


class MemoryVerseSerializer(serializers.ModelSerializer):
    """The same row the home screen features and the Learn tab drills.

    Two authored copies answer the same fields: a synced `BibleVerse` row,
    whose own translation edition governs the text and the attribution, or the
    copy stored on this memory verse for scripture whose translation was never
    imported. Whichever the console left filled is what the app prints.
    """

    verse_id = serializers.SerializerMethodField()
    reference = serializers.SerializerMethodField()
    text = serializers.SerializerMethodField()
    translation = serializers.SerializerMethodField()
    attribution = serializers.SerializerMethodField()
    completed = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = MemoryVerse
        fields = ("id", "verse_id", "reference", "text", "translation", "attribution", "prompt", "completed", "image_url")

    def get_image_url(self, item):
        return artwork_url(item, self.context.get("request"))

    def _stored_or_linked(self, item, field, linked_value):
        return linked_value if item.verse_id is not None else getattr(item, field)

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


class UniversitySerializer(serializers.ModelSerializer):
    class Meta:
        model = University
        fields = ("id", "name", "country", "city", "website")
        read_only_fields = fields


class CampusSerializer(serializers.ModelSerializer):
    university = serializers.SerializerMethodField()

    class Meta:
        model = Campus
        fields = ("id", "university", "name", "location")
        read_only_fields = fields

    def get_university(self, campus):
        return campus.university.name


class FellowshipSerializer(serializers.ModelSerializer):
    campus = serializers.SerializerMethodField()
    university = serializers.SerializerMethodField()

    class Meta:
        model = Fellowship
        fields = ("id", "campus", "university", "name", "description", "meeting_schedule")
        read_only_fields = fields

    def get_campus(self, fellowship):
        return fellowship.campus.name

    def get_university(self, fellowship):
        return fellowship.campus.university.name


class GroupSerializer(serializers.ModelSerializer):
    campus = serializers.SerializerMethodField()
    membership_status = serializers.SerializerMethodField()
    member_count = serializers.SerializerMethodField()
    is_leader = serializers.SerializerMethodField()

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
        return group.campus.name if group.campus else None

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
        return membership.group.name


class EventSerializer(serializers.ModelSerializer):
    campus = serializers.SerializerMethodField()
    registered = serializers.SerializerMethodField()
    registration_count = serializers.SerializerMethodField()
    online_url = serializers.SerializerMethodField()

    class Meta:
        model = Event
        fields = ("id", "campus", "title", "description", "starts_at", "ends_at", "timezone", "location", "online_url", "capacity", "registered", "registration_count")
        read_only_fields = fields

    def get_registered(self, event):
        user = self.context["request"].user
        return EventRegistration.objects.filter(user=user, event=event, status="registered").exists() if user.is_authenticated else False

    def get_campus(self, event):
        return event.campus.name if event.campus else None

    def get_registration_count(self, event):
        return EventRegistration.objects.filter(event=event, status="registered").count()

    def get_online_url(self, event):
        user = self.context["request"].user
        if not user.is_authenticated:
            return ""
        registered = EventRegistration.objects.filter(user=user, event=event, status="registered").exists()
        return event.online_url if registered else ""


class PrayerRequestSerializer(serializers.ModelSerializer):
    """One card on the community wall.

    The three counts are annotations when the list view supplies them and a
    query when a detail response does not, so the feed stays one round trip per
    page rather than one per card.
    """

    is_owner = serializers.SerializerMethodField()
    owner_name = serializers.SerializerMethodField()
    owner_photo = serializers.SerializerMethodField()
    category = serializers.ChoiceField(
        choices=PrayerRequest.Category.choices, default=PrayerRequest.Category.PRAYER
    )
    affirmed = serializers.SerializerMethodField()
    affirmation_count = serializers.SerializerMethodField()
    comment_count = serializers.SerializerMethodField()

    class Meta:
        model = PrayerRequest
        fields = (
            "id", "body", "category", "visibility", "group", "share_consent",
            "moderation_state", "created_at", "is_owner", "owner_name", "owner_photo",
            "affirmed", "affirmation_count", "comment_count",
        )
        read_only_fields = ("id", "moderation_state", "created_at")

    def get_is_owner(self, prayer):
        return self.context["request"].user.is_authenticated and prayer.owner_id == self.context["request"].user.id

    def get_owner_name(self, prayer):
        return wall_name(prayer.owner)

    def get_owner_photo(self, prayer):
        return wall_photo(prayer.owner, self.context.get("request"))

    def get_affirmed(self, prayer):
        annotated = getattr(prayer, "viewer_affirmed", None)
        if annotated is not None:
            return bool(annotated)
        user = self.context["request"].user
        return bool(
            user.is_authenticated and PrayerAffirmation.objects.filter(prayer=prayer, user=user).exists()
        )

    def get_affirmation_count(self, prayer):
        return _count_or_query(prayer, "affirmation_count", "affirmations")

    def get_comment_count(self, prayer):
        return _count_or_query(prayer, "comment_count", "comments")

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


class PrayerCommentSerializer(serializers.ModelSerializer):
    """One word of encouragement under a request the writer can already see."""

    author_name = serializers.SerializerMethodField()
    author_photo = serializers.SerializerMethodField()

    # The write endpoint below refuses anybody but the writer, so the app needs
    # the same answer in order to hide a control that would only fail.
    is_owner = serializers.SerializerMethodField()
    body = serializers.CharField(
        trim_whitespace=True,
        max_length=2000,
        error_messages={
            "blank": "Write a word before posting it.",
            "max_length": "Keep this under 2000 characters.",
        },
    )

    class Meta:
        model = PrayerComment
        fields = ("id", "body", "author_name", "author_photo", "created_at", "is_owner")
        read_only_fields = ("id", "created_at")

    def get_author_name(self, comment):
        return wall_name(comment.user)

    def get_author_photo(self, comment):
        return wall_photo(comment.user, self.context.get("request"))

    def get_is_owner(self, comment):
        return self.context["request"].user.is_authenticated and comment.user_id == self.context["request"].user.id


class PrayerModerationSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrayerRequest
        fields = ("id", "body", "category", "visibility", "moderation_state", "created_at")
        read_only_fields = ("id", "body", "visibility", "created_at")

    def validate_category(self, value):
        if value not in PrayerRequest.Category.values:
            raise serializers.ValidationError("Choose the wall this request belongs on.")
        return value

    def validate_moderation_state(self, value):
        if value not in (PrayerRequest.ModerationState.APPROVED, PrayerRequest.ModerationState.REJECTED):
            raise serializers.ValidationError("Moderation must approve or reject the shared request.")
        return value


class DevotionalSerializer(serializers.ModelSerializer):
    series_title = serializers.CharField(source="series.title", read_only=True, default="")
    image_url = serializers.SerializerMethodField()
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
            "image_url",
        )
        read_only_fields = fields

    def get_image_url(self, devotional):
        return artwork_url(devotional, self.context.get("request"))


class DevotionalSeriesSerializer(ContentStampedSerializerMixin, serializers.ModelSerializer):
    """One card in the Devotions grid, with how many days a student can read."""

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


class DevotionalDaySerializer(serializers.ModelSerializer):
    """A row in a series: enough to choose, none of the body."""

    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Devotional
        fields = (
            "id",
            "title",
            "day",
            "scripture_reference",
            "excerpt",
            "reading_minutes",
            "image_url",
        )
        read_only_fields = fields

    def get_image_url(self, devotional):
        return artwork_url(devotional, self.context.get("request"))


class DevotionalSeriesDetailSerializer(DevotionalSeriesSerializer):
    days = serializers.SerializerMethodField()

    class Meta(DevotionalSeriesSerializer.Meta):
        fields = DevotionalSeriesSerializer.Meta.fields + ("days",)
        read_only_fields = fields

    def get_days(self, item):
        return DevotionalDaySerializer(
            item.days_live(), many=True, context=self.context
        ).data


class ArticleSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
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
            "image_url",
        )
        read_only_fields = fields

    def get_image_url(self, article):
        return artwork_url(article, self.context.get("request"))


class ResourceTopicSerializer(ContentStampedSerializerMixin, serializers.ModelSerializer):
    """One row of the home 'Find resources on' list.

    `step_count` is what the app dares to promise: the list view only returns
    topics with a readable step, so a row that renders always opens on content.
    `steps_completed` is this student's own progress against that count, which
    is what turns a plain list of guides into a reading plan — the app draws the
    bar from the two numbers and never has to ask about the other guides.
    """

    step_count = serializers.IntegerField(read_only=True)
    steps_completed = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = ResourceTopic
        fields = (
            "id",
            "title",
            "summary",
            "image_url",
            "order",
            "publish_at",
            "step_count",
            "steps_completed",
            "content_version",
        )
        read_only_fields = fields

    def get_steps_completed(self, topic):
        progress = self.context.get("guide_progress")
        if progress is None:
            return 0
        counts = progress.per_topic.get(topic.pk)
        return counts[1] if counts else 0

    def get_image_url(self, topic):
        return artwork_url(topic, self.context.get("request"))


class ResourceStepRowSerializer(serializers.ModelSerializer):
    """A step inside a guide: enough to choose, none of the body.

    `completed` comes from the same pass that counted the guide, so the reader's
    checklist agrees with the progress bar above it.
    """

    completed = serializers.SerializerMethodField()

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
            "completed",
        )
        read_only_fields = fields

    def get_completed(self, step):
        progress = self.context.get("guide_progress")
        return progress is not None and step.pk in progress.finished_steps


class ResourceTopicDetailSerializer(ResourceTopicSerializer):
    steps = serializers.SerializerMethodField()

    class Meta(ResourceTopicSerializer.Meta):
        fields = ResourceTopicSerializer.Meta.fields + ("steps",)
        read_only_fields = fields

    def get_steps(self, item):
        return ResourceStepRowSerializer(item.steps_live(), many=True, context=self.context).data


class ResourceStepSerializer(serializers.ModelSerializer):
    """The reader's copy of one step, plus where it sits in its guide."""

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
    reading = serializers.SerializerMethodField()
    articles = ArticleSerializer(many=True)
    resources = serializers.SerializerMethodField()
    server_time = serializers.DateTimeField()

    def get_resources(self, payload):
        return ResourceTopicSerializer(
            payload["resources"], many=True, context=self.context
        ).data

    def get_reading(self, payload):
        """The day the student is on, with the plan's length beside it.

        The counts are in the payload rather than left to the app because the
        progress line is the plan's own size, which only the server has read.
        """
        reading = payload.get("reading")
        if reading is None:
            return None
        return {
            "plan_title": reading["plan_title"],
            "total": reading["total"],
            "completed": reading["completed"],
            "assignment": BibleAssignmentSerializer(
                reading["assignment"], context=self.context
            ).data,
        }


class ContentVersionSerializer(serializers.Serializer):
    version = serializers.IntegerField()


class ProgressSerializer(serializers.ModelSerializer):
    """One finished item, named.

    A history row is a foreign key plus a date, which tells a student nothing
    they can act on, so the title travels with it. Titles are read a kind at a
    time from the student's own rows, which keeps a page of history to one
    query per kind rather than one per row.
    """

    title = serializers.SerializerMethodField()
    kind_label = serializers.SerializerMethodField()

    class Meta:
        model = UserContentProgress
        fields = ("id", "kind", "kind_label", "content_id", "title", "completed_at", "note")
        read_only_fields = ("id", "completed_at")

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._titles_by_kind = {}

    def get_kind_label(self, row):
        return dict(UserContentProgress.Kind.choices).get(row.kind, row.kind)

    def get_title(self, row):
        titles = self._titles_by_kind.get(row.kind)
        if titles is None:
            titles = _progress_titles(row.kind, self.context["request"].user, self.context)
            self._titles_by_kind[row.kind] = titles
        return titles.get(str(row.content_id), "")

    def validate(self, attrs):
        kind = attrs.get("kind") or getattr(self.instance, "kind", None)
        content_id = attrs.get("content_id") or getattr(self.instance, "content_id", None)
        model = _PROGRESS_MODELS.get(kind)
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


_PROGRESS_MODELS = {
    UserContentProgress.Kind.DEVOTIONAL: Devotional,
    UserContentProgress.Kind.ARTICLE: Article,
    UserContentProgress.Kind.RESOURCE_STEP: ResourceStep,
}


def _progress_titles(kind, user, context):
    """Every title this student has finished under one kind, keyed by id."""
    model = _PROGRESS_MODELS.get(kind)
    if model is None:
        return {}
    finished = UserContentProgress.objects.filter(user=user, kind=kind).values_list(
        "content_id", flat=True
    )
    return {
        str(item.pk): item.title
        for item in model.objects.filter(pk__in=finished)
    }
