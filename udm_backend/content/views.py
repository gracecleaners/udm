from django.db import InterfaceError, OperationalError, connection, transaction
from django.db.models import Count
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import APIException, NotFound, ValidationError

from .models import (Article, BibleBookmark, BibleBook, BibleChapter, BibleNote, BibleReadingPlan,
                     BibleReadingProgress, BibleTranslation, BibleVerse, ContentVersion,
                     Devotional, DevotionalSeries, DiscipleshipGroup, Event, EventRegistration, Fellowship, GroupMembership,
                     MediaCollection, MediaItem, MediaNote, MediaWatch,
                     MemoryVerse, PrayerRequest, University, Campus, UserContentProgress,
                     UserMemoryVerseProgress, ResourceStep, ResourceTopic)
from .serializers import (ArticleSerializer, BibleBookSerializer, BibleBookmarkSerializer,
                          BibleChapterSerializer, BibleNoteSerializer, BiblePlanSerializer,
                          BibleProgressSerializer, BibleTranslationSerializer, DevotionalSerializer,
                          DevotionalSeriesDetailSerializer, DevotionalSeriesSerializer,
                          HomeSerializer, ProgressSerializer,
                          MediaCollectionDetailSerializer, MediaCollectionSerializer,
                          MediaItemDetailSerializer, MediaNoteWriteSerializer, MediaWatchWriteSerializer,
                          MemoryVerseSerializer,
                          MemoryVerseProgressSerializer, UniversitySerializer, CampusSerializer,
                          FellowshipSerializer, GroupSerializer, GroupMembershipSerializer,
                          EventSerializer, PrayerRequestSerializer, PrayerModerationSerializer,
                          ResourceStepSerializer, ResourceTopicDetailSerializer, ResourceTopicSerializer)
from .services import home_payload, live_media_collections, live_resource_topics
from .bible_passages import (
    MissingCredential,
    PassageNotFound,
    PassageTooLong,
    RateLimited,
    UnknownTranslation,
    UpstreamUnavailable,
    get_passage,
    routing_table,
    route_is_configured,
)
from .bible_refs import InvalidReference, parse_reference
from .youversion import YouVersionError, available_translations, translation_books, translation_chapter


def _youversion_translation_defaults(metadata):
    return {
        "name": metadata["name"],
        "license_name": metadata["license_name"],
        "attribution": metadata["attribution"],
        "source_url": metadata["source_url"],
        "offline_allowed": metadata["offline_allowed"],
        "is_active": True,
        "source_provider": "youversion",
    }


@transaction.atomic
def _sync_youversion_books(metadata, books):
    translation, _ = BibleTranslation.objects.update_or_create(
        code=metadata["code"], defaults=_youversion_translation_defaults(metadata)
    )
    for row in books:
        book, _ = BibleBook.objects.update_or_create(
            translation=translation,
            name=row["name"],
            defaults={
                "provider_id": row["id"],
                "order": row["order"],
                "testament": row["testament"],
            },
        )
        for chapter_number in row["chapters"]:
            BibleChapter.objects.get_or_create(book=book, number=chapter_number)
    return translation


@transaction.atomic
def _sync_youversion_chapter(chapter, payload):
    for row in payload["verses"]:
        BibleVerse.objects.update_or_create(
            chapter=chapter,
            number=row["number"],
            defaults={"text": row["text"]},
        )


class BibleProviderError(APIException):
    status_code = status.HTTP_502_BAD_GATEWAY
    default_detail = "The Bible provider is temporarily unavailable."
    default_code = "bible_provider_unavailable"


class HealthView(APIView):
    """Load-balancer and smoke-test probe; reports database reachability."""

    permission_classes = [permissions.AllowAny]

    def get(self, request):
        try:
            connection.ensure_connection()
            database = "up"
            code = status.HTTP_200_OK
        except (OperationalError, InterfaceError):
            database = "unreachable"
            code = status.HTTP_503_SERVICE_UNAVAILABLE
        return Response(
            {
                "status": "ok" if database == "up" else "degraded",
                "database": database,
                "service": "udm-api",
                "api_version": "v1",
            },
            status=code,
        )


class HomeView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_scope = "content"

    def get(self, request):
        language = request.query_params.get("language", "en")
        return Response(HomeSerializer(home_payload(request.user, language=language), context={"request": request}).data)


class PublishedContentMixin:
    permission_classes = [permissions.AllowAny]
    throttle_scope = "content"


class DevotionalListView(PublishedContentMixin, generics.ListAPIView):
    serializer_class = DevotionalSerializer
    queryset = Devotional.objects.published()
    search_fields = ["title", "scripture_reference", "body"]
    ordering_fields = ["publish_at", "title", "reading_minutes"]


class DevotionalDetailView(PublishedContentMixin, generics.RetrieveAPIView):
    serializer_class = DevotionalSerializer
    queryset = Devotional.objects.published()


def _series_with_live_days(queryset):
    """Every series annotated with how many days a student can actually read.

    The count is the same rule `DevotionalSeries.days_live` uses, so a card
    never promises a day the detail screen then hides.

    The order is restated rather than left to `Meta`: an aggregate query drops
    the model's default ordering, and the grid position is authored work.
    """
    now = timezone.now()
    return queryset.annotate(
        day_count=Count(
            "devotions",
            filter=(
                Q(devotions__is_published=True)
                & (Q(devotions__publish_at__isnull=True) | Q(devotions__publish_at__lte=now))
            ),
        )
    ).order_by("order", "created_at")


class DevotionalSeriesListView(PublishedContentMixin, generics.ListAPIView):
    serializer_class = DevotionalSeriesSerializer

    def get_queryset(self):
        # A series with no readable day is not rendered rather than shown as an
        # empty folder, so the grid only ever holds something to open.
        return _series_with_live_days(DevotionalSeries.objects.published()).filter(day_count__gt=0)


class DevotionalSeriesDetailView(PublishedContentMixin, generics.RetrieveAPIView):
    serializer_class = DevotionalSeriesDetailSerializer

    def get_queryset(self):
        return _series_with_live_days(DevotionalSeries.objects.published())


class ContentVersionView(APIView):
    """One small number, so a returning app knows whether to refetch anything."""

    permission_classes = [permissions.AllowAny]
    throttle_scope = "content"

    def get(self, request):
        return Response({"version": ContentVersion.current()})


class ArticleListView(PublishedContentMixin, generics.ListAPIView):
    serializer_class = ArticleSerializer
    queryset = Article.objects.published()
    search_fields = ["title", "category", "author", "body"]
    ordering_fields = ["publish_at", "title", "reading_minutes"]


class ArticleDetailView(PublishedContentMixin, generics.RetrieveAPIView):
    serializer_class = ArticleSerializer
    queryset = Article.objects.published()


class ResourceTopicListView(PublishedContentMixin, generics.ListAPIView):
    serializer_class = ResourceTopicSerializer

    def get_queryset(self):
        # A guide with nothing to read is not rendered rather than shown as an
        # empty folder, so the home list only ever holds something to open.
        return live_resource_topics()


class ResourceTopicDetailView(PublishedContentMixin, generics.RetrieveAPIView):
    serializer_class = ResourceTopicDetailSerializer

    def get_queryset(self):
        return live_resource_topics()


class ResourceStepDetailView(PublishedContentMixin, generics.RetrieveAPIView):
    serializer_class = ResourceStepSerializer
    queryset = ResourceStep.objects.published().select_related("topic")


class ProgressView(generics.ListCreateAPIView):
    """Completion records are private to their owner."""

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ProgressSerializer

    def get_queryset(self):
        return UserContentProgress.objects.filter(user=self.request.user)


class BibleTranslationsView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = BibleTranslationSerializer
    pagination_class = None

    def get(self, request, *args, **kwargs):
        # Provider records from older integrations or other languages may
        # remain in the database because bookmarks and notes reference their
        # verse rows. The live YouVersion catalog below follows the requested
        # app language, so retain only manual entries from local rows.
        local = list(
            BibleTranslation.objects.filter(is_active=True)
            .filter(source_provider="")
            .order_by("name")
        )
        local_data = BibleTranslationSerializer(local, many=True).data
        local_by_code = {item["code"]: item for item in local_data}
        language = request.query_params.get("language", "en").strip().lower()
        if language not in ("en", "fr"):
            language = "en"
        try:
            provider_rows = available_translations(language)
        except YouVersionError as exc:
            provider_rows = []
            if not local:
                raise BibleProviderError(str(exc)) from exc
        for row in provider_rows:
            if not row or not row.get("code"):
                continue
            existing = local_by_code.get(row["code"])
            if existing and not existing.get("source_provider"):
                continue
            local_by_code[row["code"]] = row
        results = list(local_by_code.values())
        query = request.query_params.get("search", "").strip().casefold()
        if query:
            results = [row for row in results if query in " ".join(str(row.get(field, "")) for field in ("name", "code", "language")).casefold()]
        results = [
            row for row in results
            if row.get("source_provider") != "youversion"
            or not row.get("language_code")
            or language == str(row.get("language_code", "")).casefold().split("-")[0]
        ]
        results.sort(key=lambda row: (
            not str(row.get("language_code", "")).casefold().startswith("en"),
            not row.get("offline_allowed", False),
            str(row.get("language", "")).casefold(),
            str(row.get("name", "")).casefold(),
        ))
        return Response({"count": len(results), "next": None, "previous": None, "results": results})


class BibleBooksView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = BibleBookSerializer

    def get_queryset(self):
        translation = BibleTranslation.objects.filter(code=self.kwargs["code"], is_active=True).first()
        if not translation or translation.source_provider == "youversion":
            return BibleBook.objects.none()
        return BibleBook.objects.filter(
            translation__code=self.kwargs["code"], translation__is_active=True
        ).annotate(chapter_count=Count("chapters")).order_by("order")

    def list(self, request, *args, **kwargs):
        translation = BibleTranslation.objects.filter(code=self.kwargs["code"], is_active=True).first()
        if not translation or translation.source_provider == "youversion":
            try:
                metadata, books = translation_books(translation.code if translation else self.kwargs["code"])
                translation_record = _sync_youversion_books(metadata, books)
            except YouVersionError as exc:
                raise BibleProviderError(str(exc)) from exc
            synced = BibleBook.objects.filter(translation=translation_record).annotate(
                chapter_count=Count("chapters")
            ).order_by("order")
            return Response(self.get_serializer(synced, many=True).data)
        return super().list(request, *args, **kwargs)


class BibleBookChaptersView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, code, book):
        translation = BibleTranslation.objects.filter(code=code, is_active=True).first()
        if not translation or translation.source_provider != "youversion":
            local_book = get_object_or_404(
                BibleBook.objects.filter(translation__code=code, translation__is_active=True),
                Q(name__iexact=book) | Q(provider_id=book),
            )
            return Response(list(local_book.chapters.values_list("number", flat=True)))
        local_book = get_object_or_404(
            BibleBook.objects.filter(translation=translation), provider_id=book
        )
        numbers = list(local_book.chapters.values_list("number", flat=True))
        return Response(numbers)


class BibleChapterView(generics.RetrieveAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = BibleChapterSerializer
    lookup_url_kwarg = "number"

    def get_queryset(self):
        return BibleChapter.objects.select_related("book", "book__translation").prefetch_related("verses").filter(
            book__translation__code=self.kwargs["code"], book__translation__is_active=True
        )

    def get_object(self):
        from django.shortcuts import get_object_or_404
        from django.db.models import Q
        chapter = get_object_or_404(
            self.get_queryset().filter(Q(book__name=self.kwargs["book"]) | Q(book__provider_id=self.kwargs["book"])),
            number=self.kwargs["number"],
        )
        if chapter.book.translation.source_provider == "youversion" and not chapter.verses.exists():
            try:
                payload = translation_chapter(chapter.book.translation.code, chapter.book.provider_id, chapter.number)
                _sync_youversion_chapter(chapter, payload)
                chapter = self.get_queryset().get(pk=chapter.pk)
            except YouVersionError as exc:
                raise BibleProviderError(str(exc)) from exc
        return chapter


def _with_local_verse_ids(passage: dict) -> dict:
    """Tag verses this deployment already stores with their database id.

    A routed passage comes from a provider, so no row stands behind it, yet a
    student searching "John 3:16" has to be able to bookmark the same verse the
    reader shows. `id` is filled only where a matching verse exists, which lets
    the app offer private saves where they work and an authorized deep link
    where they do not.
    """
    verses = passage.get("verses") or []
    if not verses:
        return passage
    ref = parse_reference(passage["reference"])
    stored = dict(
        BibleVerse.objects.filter(
            chapter__book__translation__code=passage["translation"],
            chapter__book__translation__is_active=True,
            chapter__number=ref.chapter,
            number__in=[row["verse"] for row in verses],
        )
        .filter(Q(chapter__book__name__iexact=ref.book) | Q(chapter__book__provider_id=ref.book_code))
        .values_list("number", "id")
    )
    passage["verses"] = [
        {**row, "id": str(stored[row["verse"]]) if row["verse"] in stored else ""}
        for row in verses
    ]
    return passage


class BiblePassageView(APIView):
    """One passage by reference, served by whichever licensed source answers.

    `?reference=` accepts any reasonable spelling ("1Jn 3:16", "i cor 15:3-4",
    "John 3") and `?translation=` any code `/bible/sources/` lists. A source
    that is missing its key, rate limited, down or unlicensed does not fail the
    request: the response carries the public-domain text plus `deep_link_url`
    for the translation that was asked for, and `fallback` says why.
    """

    permission_classes = [permissions.AllowAny]
    throttle_scope = "content"

    def get(self, request):
        try:
            passage = get_passage(
                request.query_params.get("reference", ""),
                request.query_params.get("translation", ""),
            )
        except UnknownTranslation as exc:
            raise ValidationError({"translation": [str(exc)]}) from exc
        except (InvalidReference, PassageTooLong) as exc:
            raise ValidationError({"reference": [str(exc)]}) from exc
        except PassageNotFound as exc:
            raise NotFound(str(exc)) from exc
        except (MissingCredential, RateLimited, TranslationRefused, UpstreamUnavailable) as exc:
            raise BibleProviderError(str(exc)) from exc
        return Response(_with_local_verse_ids(passage))


class BiblePassageSourcesView(APIView):
    """The routing matrix, so a client only ever offers what this deployment serves.

    `text_available=false` means the translation is licensed to a publisher that
    has not granted this app text rights: the app should deep-link instead.
    """

    permission_classes = [permissions.AllowAny]
    throttle_scope = "content"

    def get(self, request):
        routes = routing_table()
        results = [{
            "code": route.code,
            "name": route.name,
            "source": route.provider,
            "text_available": route.text_source_available,
            "offline_allowed": route.offline_allowed,
            "attribution": route.attribution,
            "configured": route_is_configured(route),
        } for route in routes.values()]
        results.sort(key=lambda row: (not row["text_available"], row["code"]))
        return Response({"count": len(results), "results": results})


class BiblePlansView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = BiblePlanSerializer
    queryset = BibleReadingPlan.objects.filter(is_published=True).prefetch_related("assignments")


class BibleBookmarksView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = BibleBookmarkSerializer

    def get_queryset(self):
        return BibleBookmark.objects.filter(user=self.request.user).select_related("verse__chapter__book")


class BibleBookmarkDetailView(generics.DestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = BibleBookmarkSerializer

    def get_queryset(self):
        return BibleBookmark.objects.filter(user=self.request.user)


class BibleNotesView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = BibleNoteSerializer

    def get_queryset(self):
        return BibleNote.objects.filter(user=self.request.user).select_related("verse__chapter__book")


class BibleNoteDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = BibleNoteSerializer

    def get_queryset(self):
        return BibleNote.objects.filter(user=self.request.user).select_related("verse__chapter__book")


class BibleReadingProgressView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = BibleProgressSerializer

    def get_queryset(self):
        return BibleReadingProgress.objects.filter(user=self.request.user)


class MediaCollectionListView(PublishedContentMixin, generics.ListAPIView):
    serializer_class = MediaCollectionSerializer

    def get_queryset(self):
        # A shelf with nothing playable on it is not rendered rather than shown
        # as an empty folder, so the Learn tab only ever holds something to open.
        return live_media_collections()


class MediaCollectionDetailView(PublishedContentMixin, generics.RetrieveAPIView):
    serializer_class = MediaCollectionDetailSerializer

    def get_queryset(self):
        return live_media_collections()


class MediaItemDetailView(PublishedContentMixin, generics.RetrieveAPIView):
    serializer_class = MediaItemDetailSerializer
    queryset = MediaItem.objects.published().select_related("collection")


class MediaItemOwnedMixin:
    """Both student-owned records on a recording are reached through it.

    The item has to be published for either write to count: a note on a draft
    would be a note about something the ministry has not released, and the
    404 says so without describing the draft to anyone.
    """

    permission_classes = [permissions.IsAuthenticated]

    def _item(self, request, pk):
        return get_object_or_404(MediaItem.objects.published(), pk=pk)


class MediaNoteView(MediaItemOwnedMixin, APIView):
    """One student's private note about one recording.

    It is a single row per pair, so the screen writes the whole note rather than
    creating a thread the student then has to manage. Clearing the text deletes
    the row: an empty note records nothing.
    """

    def get(self, request, pk):
        item = self._item(request, pk)
        note = MediaNote.objects.filter(user=request.user, item=item).first()
        return Response({"text": note.body if note else "", "updated_at": note.updated_at if note else None})

    def put(self, request, pk):
        item = self._item(request, pk)
        serializer = MediaNoteWriteSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        note = serializer.save_for(item)
        return Response({"text": note.body if note else "", "updated_at": note.updated_at if note else None})

    def delete(self, request, pk):
        MediaNote.objects.filter(user=request.user, item=self._item(request, pk)).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MediaWatchView(MediaItemOwnedMixin, APIView):
    """Where the student stopped, so a long recording resumes rather than restarts.

    The player writes this on its own schedule; it is a position, not a
    completion, and the app never treats an unauthenticated write as one.
    """

    def get(self, request, pk):
        item = self._item(request, pk)
        watch = MediaWatch.objects.filter(user=request.user, item=item).first()
        if watch is None:
            return Response({"position_seconds": 0, "completed": False, "updated_at": None})
        return Response({
            "position_seconds": watch.position_seconds,
            "completed": watch.completed_at is not None,
            "updated_at": watch.updated_at,
        })

    def put(self, request, pk):
        item = self._item(request, pk)
        serializer = MediaWatchWriteSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        watch = serializer.save_for(item)
        return Response({
            "position_seconds": watch.position_seconds,
            "completed": watch.completed_at is not None,
            "updated_at": watch.updated_at,
        })


class MemoryVerseListView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = MemoryVerseSerializer
    queryset = MemoryVerse.objects.filter(is_published=True).filter(
        # A stored copy carries its own reviewed text; a linked verse is only
        # servable while its translation stays active. Written as an explicit
        # OR because `exclude` across a nullable relation drops the null rows.
        Q(verse__isnull=True) | Q(verse__chapter__book__translation__is_active=True)
    ).select_related("verse__chapter__book__translation")


class MemoryVerseProgressView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MemoryVerseProgressSerializer

    def get_queryset(self):
        return UserMemoryVerseProgress.objects.filter(user=self.request.user)


class UniversityListView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = UniversitySerializer
    queryset = University.objects.filter(is_active=True)


class CampusListView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = CampusSerializer

    def get_queryset(self):
        queryset = Campus.objects.filter(is_active=True, university__is_active=True).select_related("university")
        university_id = self.request.query_params.get("university")
        return queryset.filter(university_id=university_id) if university_id else queryset


class FellowshipListView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = FellowshipSerializer
    queryset = Fellowship.objects.filter(
        is_active=True,
        is_public=True,
        campus__is_active=True,
        campus__university__is_active=True,
    ).select_related("campus__university")


class GroupListView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = GroupSerializer

    def get_queryset(self):
        queryset = DiscipleshipGroup.objects.filter(is_active=True).filter(
            Q(campus__isnull=True)
            | Q(campus__is_active=True, campus__university__is_active=True)
        ).select_related("campus")
        if self.request.user.is_authenticated:
            queryset = queryset.filter(
                Q(visibility=DiscipleshipGroup.Visibility.PUBLIC)
            | Q(leader=self.request.user)
                | Q(memberships__user=self.request.user)
            )
        else:
            queryset = queryset.filter(visibility=DiscipleshipGroup.Visibility.PUBLIC)
        return queryset.distinct()


class GroupJoinView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        group = get_object_or_404(DiscipleshipGroup, pk=pk, is_active=True)
        membership, created = GroupMembership.objects.get_or_create(
            user=request.user,
            group=group,
            defaults={"status": GroupMembership.Status.REQUESTED},
        )
        if not created and membership.status == GroupMembership.Status.REJECTED:
            membership.status = GroupMembership.Status.REQUESTED
            membership.save(update_fields=["status", "updated_at"])
        return Response(GroupMembershipSerializer(membership).data, status=status.HTTP_201_CREATED)


class GroupMembershipListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = GroupMembershipSerializer

    def get_queryset(self):
        return GroupMembership.objects.filter(user=self.request.user).select_related("group", "user")


class GroupJoinRequestsView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = GroupMembershipSerializer

    def get_queryset(self):
        group = get_object_or_404(DiscipleshipGroup, pk=self.kwargs["pk"])
        if group.leader_id != self.request.user.id and not self.request.user.is_staff:
            return GroupMembership.objects.none()
        return GroupMembership.objects.filter(group=group, status=GroupMembership.Status.REQUESTED).select_related("group", "user")


class GroupMembershipDecisionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, group_id, membership_id):
        group = get_object_or_404(DiscipleshipGroup, pk=group_id)
        if group.leader_id != request.user.id:
            return Response({"detail": "Only the group leader can review join requests."}, status=status.HTTP_403_FORBIDDEN)
        membership = get_object_or_404(GroupMembership, pk=membership_id, group=group, status=GroupMembership.Status.REQUESTED)
        decision = request.data.get("status")
        if decision not in (GroupMembership.Status.APPROVED, GroupMembership.Status.REJECTED):
            return Response({"status": ["Choose approved or rejected."]}, status=status.HTTP_400_BAD_REQUEST)
        with transaction.atomic():
            group = DiscipleshipGroup.objects.select_for_update().get(pk=group_id)
            if decision == GroupMembership.Status.APPROVED and group.capacity is not None:
                current = GroupMembership.objects.filter(group=group, status=GroupMembership.Status.APPROVED).count()
                if current >= group.capacity:
                    return Response({"detail": "This group is full."}, status=status.HTTP_409_CONFLICT)
            membership.status = decision
            if decision == GroupMembership.Status.APPROVED:
                membership.approved_at = timezone.now()
            membership.save(update_fields=["status", "approved_at", "updated_at"])
        return Response(GroupMembershipSerializer(membership).data)


class EventListView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = EventSerializer

    def get_queryset(self):
        return Event.objects.filter(status=Event.Status.PUBLISHED, starts_at__gte=timezone.now()).filter(
            Q(campus__isnull=True) | Q(campus__is_active=True, campus__university__is_active=True)
        ).select_related("campus")


class EventRegistrationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        with transaction.atomic():
            event = get_object_or_404(
                Event.objects.select_for_update(),
                pk=pk,
                status=Event.Status.PUBLISHED,
                starts_at__gte=timezone.now(),
            )
            existing = EventRegistration.objects.filter(user=request.user, event=event).first()
            if existing:
                return Response({"id": existing.id, "event": event.id, "status": existing.status})
            if event.capacity is not None and EventRegistration.objects.filter(event=event, status="registered").count() >= event.capacity:
                return Response({"detail": "This event is full."}, status=status.HTTP_409_CONFLICT)
            registration = EventRegistration.objects.create(user=request.user, event=event)
        return Response({"id": registration.id, "event": event.id, "status": registration.status}, status=status.HTTP_201_CREATED)


class EventRegistrationListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EventSerializer

    def get_queryset(self):
        return Event.objects.filter(registrations__user=self.request.user).select_related("campus").distinct()


class PrayerRequestListCreateView(generics.ListCreateAPIView):
    serializer_class = PrayerRequestSerializer

    def get_permissions(self):
        if self.request.method == "GET":
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        shared = Q(visibility=PrayerRequest.Visibility.PUBLIC, moderation_state=PrayerRequest.ModerationState.APPROVED, share_consent=True)
        if self.request.user.is_authenticated:
            shared |= Q(
                visibility=PrayerRequest.Visibility.GROUP,
                moderation_state=PrayerRequest.ModerationState.APPROVED,
                share_consent=True,
                group__memberships__user=self.request.user,
                group__memberships__status=GroupMembership.Status.APPROVED,
            )
            shared |= Q(owner=self.request.user)
        return PrayerRequest.objects.filter(shared).select_related("group").distinct()


class PrayerRequestDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = PrayerRequestSerializer

    def get_queryset(self):
        return PrayerRequest.objects.filter(owner=self.request.user)


class PrayerModerationView(APIView):
    permission_classes = [permissions.IsAdminUser]

    def get(self, request):
        pending = PrayerRequest.objects.filter(
            visibility=PrayerRequest.Visibility.PUBLIC,
            share_consent=True,
            moderation_state=PrayerRequest.ModerationState.PENDING,
        )
        return Response(PrayerModerationSerializer(pending, many=True).data)

    def patch(self, request, pk):
        prayer = get_object_or_404(
            PrayerRequest,
            pk=pk,
            visibility=PrayerRequest.Visibility.PUBLIC,
            share_consent=True,
            moderation_state=PrayerRequest.ModerationState.PENDING,
        )
        serializer = PrayerModerationSerializer(prayer, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class GroupPrayerModerationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, group_id):
        group = self._leader_group(request, group_id)
        pending = PrayerRequest.objects.filter(
            group=group,
            visibility=PrayerRequest.Visibility.GROUP,
            share_consent=True,
            moderation_state=PrayerRequest.ModerationState.PENDING,
        )
        return Response(PrayerModerationSerializer(pending, many=True).data)

    def patch(self, request, group_id, pk):
        group = self._leader_group(request, group_id)
        prayer = get_object_or_404(
            PrayerRequest,
            pk=pk,
            group=group,
            visibility=PrayerRequest.Visibility.GROUP,
            share_consent=True,
            moderation_state=PrayerRequest.ModerationState.PENDING,
        )
        serializer = PrayerModerationSerializer(prayer, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    @staticmethod
    def _leader_group(request, group_id):
        group = get_object_or_404(DiscipleshipGroup, pk=group_id)
        if group.leader_id != request.user.id:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Only the selected group leader may review its prayer requests.")
        return group
