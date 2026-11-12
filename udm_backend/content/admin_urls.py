"""Staff curation routing, mounted at `/api/v1/admin/`.

Names are prefixed with `admin-` because the student routes in
`content/urls.py` already own the bare names.
"""

from django.urls import path

from .admin_views import (
    ArticleAdminDetailView,
    ArticleAdminListView,
    BibleReadingAssignmentAdminDetailView,
    BibleReadingAssignmentAdminListView,
    BibleReadingPlanAdminDetailView,
    BibleReadingPlanAdminListView,
    BibleTranslationAdminDetailView,
    BibleTranslationAdminListView,
    BibleVerseAdminListView,
    CampusAdminDetailView,
    CampusAdminListView,
    DevotionalAdminDetailView,
    DevotionalAdminListView,
    DevotionalSeriesAdminDetailView,
    DevotionalSeriesAdminListView,
    EventAdminDetailView,
    EventAdminListView,
    FellowshipAdminDetailView,
    FellowshipAdminListView,
    GroupAdminDetailView,
    GroupAdminListView,
    MediaCollectionAdminDetailView,
    MediaCollectionAdminListView,
    MediaItemAdminDetailView,
    MediaItemAdminListView,
    MemoryVerseAdminDetailView,
    MemoryVerseAdminListView,
    ResourceStepAdminDetailView,
    ResourceStepAdminListView,
    ResourceTopicAdminDetailView,
    ResourceTopicAdminListView,
    UniversityAdminDetailView,
    UniversityAdminListView,
)

admin_urlpatterns = [
    path("devotions/", DevotionalAdminListView.as_view(), name="admin-devotions"),
    path("devotions/<uuid:pk>/", DevotionalAdminDetailView.as_view(), name="admin-devotion-detail"),
    path("devotion-series/", DevotionalSeriesAdminListView.as_view(), name="admin-devotion-series"),
    path("devotion-series/<uuid:pk>/", DevotionalSeriesAdminDetailView.as_view(), name="admin-devotion-series-detail"),
    path("resource-topics/", ResourceTopicAdminListView.as_view(), name="admin-resource-topics"),
    path("resource-topics/<uuid:pk>/", ResourceTopicAdminDetailView.as_view(), name="admin-resource-topic-detail"),
    # `?topic=<id>` lists one guide's steps in reading order.
    path("resource-steps/", ResourceStepAdminListView.as_view(), name="admin-resource-steps"),
    path("resource-steps/<uuid:pk>/", ResourceStepAdminDetailView.as_view(), name="admin-resource-step-detail"),
    path("articles/", ArticleAdminListView.as_view(), name="admin-articles"),
    path("articles/<uuid:pk>/", ArticleAdminDetailView.as_view(), name="admin-article-detail"),
    path("reading-plans/", BibleReadingPlanAdminListView.as_view(), name="admin-reading-plans"),
    path("reading-plans/<uuid:pk>/", BibleReadingPlanAdminDetailView.as_view(), name="admin-reading-plan-detail"),
    path("reading-plans/<uuid:plan_id>/assignments/",
         BibleReadingAssignmentAdminListView.as_view(), name="admin-reading-plan-assignments"),
    path("reading-plans/<uuid:plan_id>/assignments/<uuid:pk>/",
         BibleReadingAssignmentAdminDetailView.as_view(), name="admin-reading-plan-assignment-detail"),
    path("media-collections/", MediaCollectionAdminListView.as_view(), name="admin-media-collections"),
    path("media-collections/<uuid:pk>/", MediaCollectionAdminDetailView.as_view(), name="admin-media-collection-detail"),
    # `?collection=<id>` lists one shelf's recordings in the order the app shows them.
    path("media-items/", MediaItemAdminListView.as_view(), name="admin-media-items"),
    path("media-items/<uuid:pk>/", MediaItemAdminDetailView.as_view(), name="admin-media-item-detail"),
    path("memory-verses/", MemoryVerseAdminListView.as_view(), name="admin-memory-verses"),
    path("memory-verses/<uuid:pk>/", MemoryVerseAdminDetailView.as_view(), name="admin-memory-verse-detail"),
    # Read plus the `is_active` toggle: verse text comes from the YouVersion sync.
    path("translations/", BibleTranslationAdminListView.as_view(), name="admin-translations"),
    path("translations/<uuid:pk>/", BibleTranslationAdminDetailView.as_view(), name="admin-translation-detail"),
    # Verse lookup for the memory-verse picker; scripture itself is synced, not authored.
    path("verses/", BibleVerseAdminListView.as_view(), name="admin-verses"),
    path("universities/", UniversityAdminListView.as_view(), name="admin-universities"),
    path("universities/<uuid:pk>/", UniversityAdminDetailView.as_view(), name="admin-university-detail"),
    path("campuses/", CampusAdminListView.as_view(), name="admin-campuses"),
    path("campuses/<uuid:pk>/", CampusAdminDetailView.as_view(), name="admin-campus-detail"),
    path("fellowships/", FellowshipAdminListView.as_view(), name="admin-fellowships"),
    path("fellowships/<uuid:pk>/", FellowshipAdminDetailView.as_view(), name="admin-fellowship-detail"),
    path("groups/", GroupAdminListView.as_view(), name="admin-groups"),
    path("groups/<uuid:pk>/", GroupAdminDetailView.as_view(), name="admin-group-detail"),
    path("events/", EventAdminListView.as_view(), name="admin-events"),
    path("events/<uuid:pk>/", EventAdminDetailView.as_view(), name="admin-event-detail"),
]
