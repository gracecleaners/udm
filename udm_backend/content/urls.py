from django.urls import path

from .views import (
    ArticleDetailView,
    ArticleListView,
    DevotionalDetailView,
    DevotionalListView,
    HomeView,
    ProgressView,
)

urlpatterns = [
    path("home/", HomeView.as_view(), name="home"),
    path("devotions/", DevotionalListView.as_view(), name="devotions"),
    path("devotions/<uuid:pk>/", DevotionalDetailView.as_view(), name="devotion-detail"),
    path("articles/", ArticleListView.as_view(), name="articles"),
    path("articles/<uuid:pk>/", ArticleDetailView.as_view(), name="article-detail"),
    path("progress/", ProgressView.as_view(), name="progress"),
]
