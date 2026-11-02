from datetime import timedelta

from django.contrib import admin
from django.utils import timezone

from .models import Article, Devotional, FeaturedVerse


class PublishedContentAdmin(admin.ModelAdmin):
    list_display = ("title", "author", "reading_minutes", "publish_state", "publish_at", "updated_at")
    list_filter = ("is_published",)
    search_fields = ("title", "author", "body")
    date_hierarchy = "publish_at"
    readonly_fields = ("created_at", "updated_at")
    actions = ("publish_now", "schedule_tomorrow")
    ordering = ("-publish_at",)

    @admin.display(ordering="is_published", description="State")
    def publish_state(self, obj):
        if not obj.is_published:
            return "draft"
        if obj.publish_at and obj.publish_at > timezone.now():
            return "scheduled"
        return "live"

    @admin.action(description="Publish immediately")
    def publish_now(self, request, queryset):
        changed = queryset.update(is_published=True, publish_at=timezone.now())
        self.message_user(request, f"{changed} item(s) published.")

    @admin.action(description="Schedule for tomorrow at 05:00")
    def schedule_tomorrow(self, request, queryset):
        tomorrow = timezone.localtime(timezone.now()).replace(hour=5, minute=0, second=0, microsecond=0) + timedelta(days=1)
        changed = queryset.update(is_published=True, publish_at=tomorrow)
        self.message_user(request, f"{changed} item(s) scheduled for {tomorrow:%Y-%m-%d %H:%M %Z}.")


@admin.register(Devotional)
class DevotionalAdmin(PublishedContentAdmin):
    list_display = ("title", "scripture_reference", "author", "publish_state", "publish_at")
    search_fields = ("title", "scripture_reference", "body")
    fieldsets = (
        ("Lesson", {"fields": ("title", "author", "scripture_reference", "excerpt", "body")}),
        ("Response", {"fields": ("reflection_questions", "application", "prayer", "memory_scripture_reference")}),
        ("Publishing", {"fields": ("reading_minutes", "is_published", "publish_at", "created_at", "updated_at")}),
    )


@admin.register(Article)
class ArticleAdmin(PublishedContentAdmin):
    list_display = ("title", "category", "author", "publish_state", "publish_at")
    list_filter = ("category", "is_published")
    search_fields = ("title", "category", "author", "body")


@admin.register(FeaturedVerse)
class FeaturedVerseAdmin(admin.ModelAdmin):
    list_display = ("reference", "translation_code", "window", "is_active")
    list_filter = ("is_active", "translation_code")
    search_fields = ("reference", "text")
    readonly_fields = ("created_at", "updated_at")

    @admin.display(description="Shown between")
    def window(self, obj):
        return f"{obj.start_date or 'any'} → {obj.end_date or 'any'}"
