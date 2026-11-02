from django.contrib import admin

from .models import Article, Devotional, UserContentProgress


@admin.register(Devotional)
class DevotionalAdmin(admin.ModelAdmin):
    list_display = ("title", "scripture_reference", "is_published", "publish_at")
    list_filter = ("is_published",)
    search_fields = ("title", "scripture_reference", "body")


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ("title", "category", "is_published", "publish_at")
    list_filter = ("category", "is_published")
    search_fields = ("title", "body")


admin.site.register(UserContentProgress)
