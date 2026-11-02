from django.db import InterfaceError, OperationalError, connection
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Article, Devotional, UserContentProgress
from .serializers import ArticleSerializer, DevotionalSerializer, HomeSerializer, ProgressSerializer
from .services import home_payload


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
        return Response(HomeSerializer(home_payload(request.user)).data)


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


class ArticleListView(PublishedContentMixin, generics.ListAPIView):
    serializer_class = ArticleSerializer
    queryset = Article.objects.published()
    search_fields = ["title", "category", "author", "body"]
    ordering_fields = ["publish_at", "title", "reading_minutes"]


class ArticleDetailView(PublishedContentMixin, generics.RetrieveAPIView):
    serializer_class = ArticleSerializer
    queryset = Article.objects.published()


class ProgressView(generics.ListCreateAPIView):
    """Completion records are private to their owner."""

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ProgressSerializer

    def get_queryset(self):
        return UserContentProgress.objects.filter(user=self.request.user)
