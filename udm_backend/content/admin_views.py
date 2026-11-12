"""HTTP endpoints the ministry console uses to author content.

Everything here needs a console account: `permission_classes =
[IsMinistryStaff]` is repeated on every class rather than hidden in a shared
mixin on purpose — this is the security boundary for the whole curation
surface, so it should be readable line by line without following an
inheritance chain. Ministry staff author content; the two surfaces where a
change cannot be undone by editing it again — Bible licensing metadata — are
wrapped in `StaffReadAndAdminWrite` instead, so staff read them and only a
platform admin changes them.

Three rules shape the set:

* Curation lists drafts and unpublished rows. The student views narrow through
  `published()` / `is_active`; here the plain manager is used, with an optional
  `?published=true` that calls the model's own manager method instead of
  repeating its conditions.
* Nothing reads or writes private student data: no bookmarks, notes, progress
  rows, watch positions or private prayer requests appear in this file, and the
  roster in `accounts.admin_views` is aggregate-only.
* `BibleTranslation` has no DELETE. Removing one cascades into the verse rows
  that bookmarks and notes point at. That deletion stays in Django Admin, which
  lists the collateral before it happens.
"""

from django.db.models import Count, F, Q
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions

from accounts.permissions import IsMinistryStaff, StaffReadAndAdminWrite

from .admin_serializers import (
    ArticleAdminSerializer,
    BibleReadingAssignmentAdminSerializer,
    BibleReadingPlanAdminSerializer,
    BibleTranslationAdminSerializer,
    BibleVerseAdminSerializer,
    CampusAdminSerializer,
    DevotionalAdminSerializer,
    DevotionalSeriesAdminSerializer,
    EventAdminSerializer,
    FellowshipAdminSerializer,
    GroupAdminSerializer,
    MediaCollectionAdminSerializer,
    MediaItemAdminSerializer,
    MemoryVerseAdminSerializer,
    ResourceStepAdminSerializer,
    ResourceTopicAdminSerializer,
    UniversityAdminSerializer,
)
from .models import (
    Article,
    BibleReadingAssignment,
    BibleReadingPlan,
    BibleTranslation,
    BibleVerse,
    Campus,
    Devotional,
    DevotionalSeries,
    DiscipleshipGroup,
    Event,
    Fellowship,
    GroupMembership,
    MediaCollection,
    MediaItem,
    MemoryVerse,
    ResourceStep,
    ResourceTopic,
    University,
)

# Each list and its detail route share one queryset, so the numbers a console
# page shows are the numbers its edit form shows.
#
# Each aggregated queryset also names its own ordering: `annotate()` leaves the
# model's `Meta.ordering` out of the final SQL, and DRF warns that a paginated
# unordered queryset can hand back the same row on two different pages.
PLAN_QUERYSET = BibleReadingPlan.objects.annotate(
    assignment_count=Count("assignments", distinct=True),
).order_by("title")
MEMORY_VERSE_QUERYSET = MemoryVerse.objects.select_related("verse__chapter__book__translation")
TRANSLATION_QUERYSET = BibleTranslation.objects.annotate(
    book_count=Count("books", distinct=True),
    chapter_count=Count("books__chapters", distinct=True),
).order_by("name")
UNIVERSITY_QUERYSET = University.objects.annotate(
    campus_count=Count("campuses", distinct=True),
).order_by("name")
CAMPUS_QUERYSET = Campus.objects.select_related("university").annotate(
    fellowship_count=Count("fellowships", distinct=True),
    group_count=Count("groups", distinct=True),
    event_count=Count("events", distinct=True),
).order_by("university__name", "name")
FELLOWSHIP_QUERYSET = Fellowship.objects.select_related("campus__university")
GROUP_QUERYSET = DiscipleshipGroup.objects.select_related("campus", "leader").annotate(
    member_count=Count(
        "memberships", filter=Q(memberships__status=GroupMembership.Status.APPROVED), distinct=True
    ),
).order_by("name")
# `EventRegistration.status` has no choices class; "registered" is the value the
# model defaults to and the value the student views count.
EVENT_QUERYSET = Event.objects.select_related("campus", "organizer").annotate(
    registration_count=Count(
        "registrations", filter=Q(registrations__status="registered"), distinct=True
    ),
).order_by("starts_at")


def only_published_if_asked(view, queryset):
    """`?published=true` narrows to the reader-visible window using the model's
    own manager method; without it, staff see every row including drafts."""
    if view.request.query_params.get("published") in ("1", "true", "yes"):
        return queryset.published()
    return queryset


def filter_by_parent(queryset, view, param):
    parent = view.request.query_params.get(param)
    return queryset.filter(**{f"{param}_id": parent}) if parent else queryset


# Devotions ------------------------------------------------------------------


class DevotionalAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = DevotionalAdminSerializer
    search_fields = ["title", "scripture_reference", "author", "body"]
    ordering_fields = [
        "publish_at", "title", "author", "reading_minutes", "is_published", "created_at",
        "series", "day",
    ]

    def get_queryset(self):
        queryset = only_published_if_asked(self, Devotional.objects.select_related("series"))
        series = self.request.query_params.get("series")
        if series:
            # `?series=<id>` is how the console lists one series' days in order.
            return queryset.filter(series_id=series).order_by(F("day").asc(nulls_first=True), "-publish_at")
        return queryset


class DevotionalAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = DevotionalAdminSerializer
    queryset = Devotional.objects.all()


# Articles -------------------------------------------------------------------


class ArticleAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = ArticleAdminSerializer
    search_fields = ["title", "category", "author", "body"]
    ordering_fields = ["publish_at", "title", "author", "category", "reading_minutes", "is_published", "created_at"]

    def get_queryset(self):
        return only_published_if_asked(self, Article.objects.all())


class ArticleAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = ArticleAdminSerializer
    queryset = Article.objects.all()


# Devotion series ------------------------------------------------------------


SERIES_QUERYSET = DevotionalSeries.objects.annotate(
    day_count=Count("devotions", distinct=True),
).order_by("order", "title")


class DevotionalSeriesAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = DevotionalSeriesAdminSerializer
    queryset = SERIES_QUERYSET
    search_fields = ["title", "description"]
    ordering_fields = ["order", "title", "is_published", "updated_at", "day_count"]

    def get_queryset(self):
        return only_published_if_asked(self, SERIES_QUERYSET)


class DevotionalSeriesAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = DevotionalSeriesAdminSerializer
    queryset = SERIES_QUERYSET


# Resource guides ------------------------------------------------------------


TOPIC_QUERYSET = ResourceTopic.objects.annotate(
    step_count=Count("steps", distinct=True),
).order_by("order", "title")

STEP_QUERYSET = ResourceStep.objects.select_related("topic")


class ResourceTopicAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = ResourceTopicAdminSerializer
    search_fields = ["title", "summary"]
    ordering_fields = ["order", "title", "is_published", "updated_at", "step_count"]

    def get_queryset(self):
        return only_published_if_asked(self, TOPIC_QUERYSET)


class ResourceTopicAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = ResourceTopicAdminSerializer
    queryset = TOPIC_QUERYSET


class ResourceStepAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = ResourceStepAdminSerializer
    search_fields = ["title", "scripture_reference", "author", "body"]
    ordering_fields = [
        "order", "title", "author", "reading_minutes", "is_published", "created_at",
        "topic",
    ]

    def get_queryset(self):
        queryset = only_published_if_asked(self, STEP_QUERYSET)
        topic = self.request.query_params.get("topic")
        if topic:
            # `?topic=<id>` is how the console works through one guide in order,
            # and an unnumbered starting point is read before Step 1.
            return queryset.filter(topic_id=topic).order_by(
                F("order").asc(nulls_first=True), "-publish_at"
            )
        return queryset.order_by("topic__order", F("order").asc(nulls_first=True), "-publish_at")


class ResourceStepAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = ResourceStepAdminSerializer
    queryset = STEP_QUERYSET


# Bible reading plans --------------------------------------------------------


class BibleReadingPlanAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = BibleReadingPlanAdminSerializer
    queryset = PLAN_QUERYSET
    search_fields = ["title", "description"]
    ordering_fields = ["title", "is_published", "updated_at", "assignment_count"]


class BibleReadingPlanAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = BibleReadingPlanAdminSerializer
    queryset = PLAN_QUERYSET


class BibleReadingAssignmentAdminListView(generics.ListCreateAPIView):
    """A plan's day-by-day readings, addressed under the plan that owns them."""

    permission_classes = [IsMinistryStaff]
    serializer_class = BibleReadingAssignmentAdminSerializer
    search_fields = ["reference"]
    ordering_fields = ["day", "reference", "created_at"]

    def get_queryset(self):
        return BibleReadingAssignment.objects.filter(plan_id=self.kwargs["plan_id"])

    def perform_create(self, serializer):
        serializer.save(plan=get_object_or_404(BibleReadingPlan, pk=self.kwargs["plan_id"]))


class BibleReadingAssignmentAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = BibleReadingAssignmentAdminSerializer

    def get_queryset(self):
        return BibleReadingAssignment.objects.filter(plan_id=self.kwargs["plan_id"])


# Media shelves and recordings ------------------------------------------------


MEDIA_SHELF_QUERYSET = MediaCollection.objects.annotate(
    item_count=Count("items", distinct=True),
).order_by("order", "created_at")
MEDIA_ITEM_QUERYSET = MediaItem.objects.select_related("collection")


class MediaCollectionAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = MediaCollectionAdminSerializer
    search_fields = ["title", "description"]
    ordering_fields = ["order", "title", "is_published", "updated_at", "item_count"]

    def get_queryset(self):
        return only_published_if_asked(self, MEDIA_SHELF_QUERYSET)


class MediaCollectionAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    """DELETE cascades into the shelf's recordings, and through them into the
    notes and resume points their owners wrote. The console states that before
    it confirms, which is why the route exists here rather than only in Django
    Admin."""

    permission_classes = [IsMinistryStaff]
    serializer_class = MediaCollectionAdminSerializer
    queryset = MEDIA_SHELF_QUERYSET


class MediaItemAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = MediaItemAdminSerializer
    search_fields = ["title", "author", "body"]
    ordering_fields = [
        "order", "title", "author", "duration_seconds", "is_published", "created_at",
        "collection",
    ]

    def get_queryset(self):
        queryset = only_published_if_asked(self, MEDIA_ITEM_QUERYSET)
        collection = self.request.query_params.get("collection")
        if collection:
            # `?collection=<id>` is how the console works through one shelf, and
            # an unnumbered recording keeps the newest-first order the shelf
            # itself uses.
            return queryset.filter(collection_id=collection).order_by(
                F("order").asc(nulls_last=True), "-publish_at"
            )
        return queryset.order_by("collection__order", F("order").asc(nulls_last=True), "-publish_at")


class MediaItemAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = MediaItemAdminSerializer
    queryset = MEDIA_ITEM_QUERYSET


# Memory verses --------------------------------------------------------------


class MemoryVerseAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = MemoryVerseAdminSerializer
    queryset = MEMORY_VERSE_QUERYSET
    search_fields = ["prompt", "verse__text"]
    ordering_fields = ["created_at", "updated_at", "is_published", "prompt"]


class MemoryVerseAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = MemoryVerseAdminSerializer
    queryset = MEMORY_VERSE_QUERYSET


class BibleVerseAdminListView(generics.ListAPIView):
    """Verse lookup for the memory-verse picker.

    Memory verses store a `BibleVerse` primary key, so the console needs a way
    to find one. This only ever reads synced verse rows: narrowing happens on
    translation, book and chapter so a lookup returns one chapter's verses
    rather than scanning scripture.
    """

    permission_classes = [IsMinistryStaff]
    serializer_class = BibleVerseAdminSerializer
    search_fields = ["text", "chapter__book__name"]
    ordering_fields = ["chapter__book__order", "chapter__number", "number"]
    ordering = ["chapter__book__order", "chapter__number", "number"]

    def get_queryset(self):
        queryset = BibleVerse.objects.select_related("chapter__book__translation").filter(
            chapter__book__translation__is_active=True
        )
        params = self.request.query_params
        if params.get("translation"):
            queryset = queryset.filter(chapter__book__translation__code=params["translation"])
        if params.get("book"):
            queryset = queryset.filter(chapter__book__name__iexact=params["book"])
        if params.get("chapter"):
            queryset = queryset.filter(chapter__number=params["chapter"])
        return queryset


# Bible translations ---------------------------------------------------------


class BibleTranslationAdminListView(generics.ListAPIView):
    """Catalogue read plus an `is_active` toggle: books, chapters and verse text
    arrive from the YouVersion sync, so they are never hand-authored here."""

    permission_classes = [StaffReadAndAdminWrite]
    serializer_class = BibleTranslationAdminSerializer
    queryset = TRANSLATION_QUERYSET
    search_fields = ["name", "code", "license_name"]
    ordering_fields = ["name", "code", "is_active", "book_count", "chapter_count"]


class BibleTranslationAdminDetailView(generics.RetrieveUpdateAPIView):
    # `license_name`, `attribution` and `offline_allowed` are the ministry's
    # legal assertion about someone else's text. Staff read it; only the people
    # who own the platform make it.
    permission_classes = [StaffReadAndAdminWrite]
    serializer_class = BibleTranslationAdminSerializer
    queryset = TRANSLATION_QUERYSET


# Campus ministry ------------------------------------------------------------


class UniversityAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = UniversityAdminSerializer
    queryset = UNIVERSITY_QUERYSET
    search_fields = ["name", "country", "city"]
    ordering_fields = ["name", "country", "city", "is_active", "campus_count"]


class UniversityAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = UniversityAdminSerializer
    queryset = UNIVERSITY_QUERYSET


class CampusAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = CampusAdminSerializer
    search_fields = ["name", "university__name", "location"]
    ordering_fields = ["name", "university__name", "is_active", "fellowship_count", "group_count", "event_count"]

    def get_queryset(self):
        # Same `?university=` narrowing the student campuses list already uses.
        return filter_by_parent(CAMPUS_QUERYSET, self, "university")


class CampusAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = CampusAdminSerializer
    queryset = CAMPUS_QUERYSET


class FellowshipAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = FellowshipAdminSerializer
    search_fields = ["name", "description", "campus__name"]
    ordering_fields = ["name", "campus__name", "is_public", "is_active", "created_at"]

    def get_queryset(self):
        return filter_by_parent(FELLOWSHIP_QUERYSET, self, "campus")


class FellowshipAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = FellowshipAdminSerializer
    queryset = FELLOWSHIP_QUERYSET


class GroupAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = GroupAdminSerializer
    search_fields = ["name", "description", "group_type", "campus__name"]
    ordering_fields = ["name", "visibility", "capacity", "is_active", "member_count", "created_at"]

    def get_queryset(self):
        return filter_by_parent(GROUP_QUERYSET, self, "campus")


class GroupAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    """`member_count` is the same approved-membership aggregate the student
    group card already shows; a group's prayer requests detach rather than
    disappear (`on_delete=SET_NULL`)."""

    permission_classes = [IsMinistryStaff]
    serializer_class = GroupAdminSerializer
    queryset = GROUP_QUERYSET


class EventAdminListView(generics.ListCreateAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = EventAdminSerializer
    search_fields = ["title", "description", "location", "campus__name"]
    ordering_fields = ["starts_at", "ends_at", "title", "status", "capacity", "registration_count"]

    def get_queryset(self):
        return filter_by_parent(EVENT_QUERYSET, self, "campus")


class EventAdminDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsMinistryStaff]
    serializer_class = EventAdminSerializer
    queryset = EVENT_QUERYSET
