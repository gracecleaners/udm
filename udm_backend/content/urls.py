from django.urls import path

from .views import ArticleListView, DevotionalListView, HealthView, HomeView, ProgressView

urlpatterns = [
    path("health/", HealthView.as_view(), name="health"),
    path("home/", HomeView.as_view(), name="home"),
    path("devotions/", DevotionalListView.as_view(), name="devotions"),
    path("articles/", ArticleListView.as_view(), name="articles"),
    path("progress/", ProgressView.as_view(), name="progress"),
]
