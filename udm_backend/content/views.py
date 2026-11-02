from django.utils import timezone
from rest_framework import generics, permissions
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Article, Devotional
from .serializers import ArticleSerializer, DevotionalSerializer, ProgressSerializer


class HealthView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return Response({"status": "ok", "service": "udm-api", "api_version": "v1"})


class HomeView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        today = timezone.localdate()
        devotional = Devotional.objects.filter(is_published=True, publish_at__date__lte=today).first()
        articles = Article.objects.filter(is_published=True, publish_at__date__lte=today)[:5]
        return Response({
            "greeting": "Grow in His Word.",
            "verse": {"reference": "Romans 12:2", "text": "Be transformed by the renewing of your mind."},
            "devotion": DevotionalSerializer(devotional).data if devotional else None,
            "articles": ArticleSerializer(articles, many=True).data,
        })


class DevotionalListView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = DevotionalSerializer
    queryset = Devotional.objects.filter(is_published=True)
    search_fields = ["title", "scripture_reference", "body"]


class ArticleListView(generics.ListAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = ArticleSerializer
    queryset = Article.objects.filter(is_published=True)
    search_fields = ["title", "category", "body"]


class ProgressView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ProgressSerializer

    def get_queryset(self):
        return self.request.user.content_progress.all()
