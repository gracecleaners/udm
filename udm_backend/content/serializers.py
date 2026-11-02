from rest_framework import serializers

from .models import Article, Devotional, FeaturedVerse, UserContentProgress


class DevotionalSerializer(serializers.ModelSerializer):
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
        )
        read_only_fields = fields


class ArticleSerializer(serializers.ModelSerializer):
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


class FeaturedVerseSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeaturedVerse
        fields = ("id", "reference", "text", "translation_code", "attribution")
        read_only_fields = fields


class HomeSerializer(serializers.Serializer):
    """Dashboard payload; every section is server-curated so no app release is needed."""

    greeting = serializers.CharField()
    verse = FeaturedVerseSerializer(allow_null=True)
    devotion = DevotionalSerializer(allow_null=True)
    articles = ArticleSerializer(many=True)
    server_time = serializers.DateTimeField()


class ProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserContentProgress
        fields = ("id", "kind", "content_id", "completed_at", "note")
        read_only_fields = ("id", "completed_at")

    def validate(self, attrs):
        kind = attrs.get("kind") or getattr(self.instance, "kind", None)
        content_id = attrs.get("content_id") or getattr(self.instance, "content_id", None)
        model = {UserContentProgress.Kind.DEVOTIONAL: Devotional, UserContentProgress.Kind.ARTICLE: Article}.get(kind)
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
