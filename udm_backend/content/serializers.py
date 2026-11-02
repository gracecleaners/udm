from rest_framework import serializers

from .models import Article, Devotional, UserContentProgress


class DevotionalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Devotional
        fields = ("id", "title", "scripture_reference", "excerpt", "body", "reflection_questions", "application", "prayer", "reading_minutes", "publish_at")


class ArticleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Article
        fields = ("id", "title", "category", "author", "excerpt", "body", "reading_minutes", "publish_at")


class ProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserContentProgress
        fields = ("id", "kind", "content_id", "completed_at", "note")
        read_only_fields = ("id", "completed_at")

    def create(self, validated_data):
        return UserContentProgress.objects.update_or_create(
            user=self.context["request"].user,
            kind=validated_data["kind"],
            content_id=validated_data["content_id"],
            defaults={"note": validated_data.get("note", "")},
        )[0]
