from datetime import timedelta

from django.contrib import admin
from django import forms
from django.db import models
from django.utils import timezone

from .models import (Article, BibleBook, BibleChapter, BibleReadingAssignment, BibleReadingPlan,
                     BibleTranslation, BibleVerse,
                     Devotional, DevotionalSeries, MemoryVerse,
                     MediaCollection, MediaItem,
                     ResourceStep, ResourceTopic)
from .models import Campus, DiscipleshipGroup, Event, Fellowship, University


class LocalizedContentAdminForm(forms.ModelForm):
    """Adds ordinary French fields while keeping translations in a JSON map."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        french = (self.instance.translations or {}).get("fr", {}) if self.instance.pk else {}
        for name in self._meta.model.localized_fields:
            key = f"french_{name}"
            if key in self.initial:
                continue
            self.initial[key] = french.get(name, "") if isinstance(french, dict) else ""

    def save(self, commit=True):
        instance = super().save(commit=False)
        translations = dict(instance.translations or {})
        french = dict(translations.get("fr") or {})
        for name in self._meta.model.localized_fields:
            value = self.cleaned_data.get(f"french_{name}")
            if value in (None, ""):
                french.pop(name, None)
            else:
                french[name] = value
        if french:
            translations["fr"] = french
        else:
            translations.pop("fr", None)
        instance.translations = translations
        if commit:
            instance.save()
            self.save_m2m()
        return instance


class LocalizedAdminMixin:
    form = LocalizedContentAdminForm

    def get_exclude(self, request, obj=None):
        excluded = list(super().get_exclude(request, obj) or ())
        excluded.append("translations")
        return tuple(dict.fromkeys(excluded))

    def get_form(self, request, obj=None, change=False, **kwargs):
        extra_fields = {}
        for name in self.model.localized_fields:
            model_field = self.model._meta.get_field(name)
            french_name = f"french_{name}"
            if isinstance(model_field, models.JSONField):
                extra_fields[french_name] = forms.JSONField(
                    required=False,
                    label=f"French — {model_field.verbose_name}",
                    help_text="Enter a French list or object as JSON.",
                    widget=forms.Textarea(attrs={"rows": 3}),
                )
            else:
                widget = forms.Textarea(attrs={"rows": 5}) if isinstance(model_field, models.TextField) else forms.TextInput()
                extra_fields[french_name] = forms.CharField(
                    required=False,
                    max_length=model_field.max_length,
                    label=f"French — {model_field.verbose_name}",
                    widget=widget,
                )
        form_class = type(
            f"{self.model.__name__}FrenchAdminForm",
            (self.form,),
            extra_fields,
        )
        return super().get_form(request, obj, change, form=form_class, **kwargs)

    def get_fieldsets(self, request, obj=None):
        fieldsets = []
        french_fields = {f"french_{name}" for name in self.model.localized_fields}
        for title, options in super().get_fieldsets(request, obj):
            options = dict(options)
            configured = options.get("fields")
            if configured:
                options["fields"] = tuple(name for name in configured if name not in french_fields)
            fieldsets.append((title, options))
        if french_fields:
            fields = tuple(f"french_{name}" for name in self.model.localized_fields)
            fieldsets.append(("French translation", {"fields": fields}))
        return fieldsets


class LocalizedModelAdmin(LocalizedAdminMixin, admin.ModelAdmin):
    pass


class LocalizedInlineAdmin(LocalizedAdminMixin, admin.TabularInline):
    pass


class LocalizedStackedInline(LocalizedAdminMixin, admin.StackedInline):
    pass


class PublishedContentAdmin(LocalizedAdminMixin, admin.ModelAdmin):
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


class DevotionalInline(admin.StackedInline):
    """Author a day from its series page; the day number only has to be unique
    inside that series, which the model constraint enforces."""

    model = Devotional
    extra = 1
    fields = ("day", "title", "scripture_reference", "excerpt", "body", "is_published", "publish_at")
    ordering = ("-day",)


@admin.register(DevotionalSeries)
class DevotionalSeriesAdmin(PublishedContentAdmin):
    """The grid the Devotions tab shows: one row per series, its days inline."""

    list_display = ("title", "order", "day_count", "publish_state", "publish_at", "updated_at")
    search_fields = ("title", "description")
    readonly_fields = ("created_at", "updated_at")
    ordering = ("order",)
    inlines = (DevotionalInline,)

    @admin.display(description="Days")
    def day_count(self, obj):
        return obj.devotions.count()


@admin.register(Devotional)
class DevotionalAdmin(PublishedContentAdmin):
    list_display = ("title", "series", "day", "scripture_reference", "publish_state", "publish_at")
    list_filter = ("is_published", "series")
    search_fields = ("title", "scripture_reference", "body")
    fieldsets = (
        ("Series", {"fields": ("series", "day")}),
        ("Lesson", {"fields": ("title", "author", "scripture_reference", "excerpt", "body")}),
        ("Response", {"fields": ("reflection_questions", "application", "prayer", "memory_scripture_reference")}),
        ("Publishing", {"fields": ("reading_minutes", "is_published", "publish_at", "created_at", "updated_at")}),
    )


@admin.register(Article)
class ArticleAdmin(PublishedContentAdmin):
    list_display = ("title", "category", "author", "publish_state", "publish_at")
    list_filter = ("category", "is_published")
    search_fields = ("title", "category", "author", "body")


class ResourceStepInline(admin.StackedInline):
    """Author a step from its guide page; the step number only has to be unique
    inside that guide, which the model constraint enforces."""

    model = ResourceStep
    extra = 1
    fields = ("order", "title", "scripture_reference", "excerpt", "body", "video_url", "is_published", "publish_at")
    ordering = ("-order",)


@admin.register(ResourceTopic)
class ResourceTopicAdmin(PublishedContentAdmin):
    """The home 'Find resources on' list: one row per guide, its steps inline."""

    list_display = ("title", "order", "step_count", "publish_state", "publish_at", "updated_at")
    search_fields = ("title", "summary")
    readonly_fields = ("created_at", "updated_at")
    ordering = ("order",)
    inlines = (ResourceStepInline,)

    @admin.display(description="Steps")
    def step_count(self, obj):
        return obj.steps.count()


@admin.register(ResourceStep)
class ResourceStepAdmin(PublishedContentAdmin):
    list_display = ("title", "topic", "order", "scripture_reference", "publish_state", "publish_at")
    list_filter = ("is_published", "topic")
    search_fields = ("title", "scripture_reference", "body")
    fieldsets = (
        ("Guide", {"fields": ("topic", "order")}),
        ("Lesson", {"fields": ("title", "author", "scripture_reference", "excerpt", "body")}),
        ("Media", {"fields": ("video_url",)}),
        ("Publishing", {"fields": ("reading_minutes", "is_published", "publish_at", "created_at", "updated_at")}),
    )


class BibleVerseInline(admin.TabularInline):
    model = BibleVerse
    extra = 0


@admin.register(BibleVerse)
class BibleVerseAdmin(admin.ModelAdmin):
    """Verse lookup, so a memory verse can be picked by reference.

    Scripture rows arrive from the YouVersion sync or `import_bible`; nothing
    here is editable, because typing a verse into a text box is how a
    translation ends up misquoted.
    """

    list_display = ("label", "chapter", "number")
    search_fields = ("text", "chapter__book__name", "chapter__number", "number")
    list_filter = ("chapter__book__translation",)

    @admin.display(description="Verse")
    def label(self, obj):
        return f"{obj.chapter.book.name} {obj.chapter.number}:{obj.number}"

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(BibleTranslation)
class BibleTranslationAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "source_provider", "license_name", "offline_allowed", "is_active")
    list_filter = ("source_provider", "is_active", "offline_allowed")
    search_fields = ("name", "code", "license_name")


@admin.register(BibleBook)
class BibleBookAdmin(admin.ModelAdmin):
    list_display = ("name", "translation", "order", "testament")
    list_filter = ("translation", "testament")
    ordering = ("translation", "order")


@admin.register(BibleChapter)
class BibleChapterAdmin(admin.ModelAdmin):
    list_display = ("book", "number")
    list_filter = ("book__translation", "book")
    inlines = (BibleVerseInline,)


class BibleReadingAssignmentInline(LocalizedInlineAdmin):
    model = BibleReadingAssignment
    extra = 0


@admin.register(BibleReadingPlan)
class BibleReadingPlanAdmin(LocalizedModelAdmin):
    list_display = ("title", "is_published", "updated_at")
    list_filter = ("is_published",)
    inlines = (BibleReadingAssignmentInline,)


class MediaItemInline(admin.StackedInline):
    """Author a recording from its shelf; the position only has to be unique
    inside that shelf, which the model constraint enforces."""

    model = MediaItem
    extra = 1
    fields = (
        "order", "title", "author", "excerpt", "body",
        "youtube_url", "download_url", "duration_seconds", "image",
        "is_published", "publish_at",
    )
    ordering = ("-order",)


@admin.register(MediaCollection)
class MediaCollectionAdmin(PublishedContentAdmin):
    """The Learn tab: one row per shelf, its recordings inline."""

    list_display = ("title", "order", "item_count", "publish_state", "publish_at", "updated_at")
    search_fields = ("title", "description")
    readonly_fields = ("created_at", "updated_at")
    ordering = ("order",)
    inlines = (MediaItemInline,)

    @admin.display(description="Recordings")
    def item_count(self, obj):
        return obj.items.count()


@admin.register(MediaItem)
class MediaItemAdmin(PublishedContentAdmin):
    list_display = ("title", "collection", "order", "author", "publish_state", "publish_at")
    list_filter = ("is_published", "collection")
    search_fields = ("title", "author", "body")
    fieldsets = (
        ("Shelf", {"fields": ("collection", "order")}),
        ("Recording", {"fields": ("title", "author", "excerpt", "body")}),
        ("Media", {"fields": ("youtube_url", "download_url", "duration_seconds", "image")}),
        ("Publishing", {"fields": ("is_published", "publish_at", "created_at", "updated_at")}),
    )


@admin.register(MemoryVerse)
class MemoryVerseAdmin(LocalizedModelAdmin):
    """One table for both jobs: the home memory verse and the memorization drill."""

    list_display = ("display_reference", "source", "translation_code", "window", "is_published", "updated_at")
    list_filter = ("is_published", "translation_code", "verse__chapter__book__translation")
    search_fields = ("reference", "text", "prompt", "verse__text")
    readonly_fields = ("created_at", "updated_at")
    fieldsets = (
        ("From the synced Scripture", {"fields": ("verse",)}),
        ("Or written here", {"fields": ("reference", "text", "translation_code", "attribution")}),
        ("Use", {"fields": ("prompt", "start_date", "end_date", "is_published", "created_at", "updated_at")}),
    )
    autocomplete_fields = ("verse",)

    @admin.display(description="Text comes from")
    def source(self, obj):
        return "synced verse" if obj.verse_id is not None else "stored copy"

    @admin.display(description="Shown between")
    def window(self, obj):
        return f"{obj.start_date or 'any'} → {obj.end_date or 'any'}"


@admin.register(University)
class UniversityAdmin(LocalizedModelAdmin):
    list_display = ("name", "country", "city", "is_active")
    list_filter = ("country", "is_active")
    search_fields = ("name", "city")


@admin.register(Campus)
class CampusAdmin(LocalizedModelAdmin):
    list_display = ("name", "university", "location", "is_active")
    list_filter = ("university", "is_active")
    search_fields = ("name", "university__name", "location")


@admin.register(Fellowship)
class FellowshipAdmin(LocalizedModelAdmin):
    list_display = ("name", "campus", "is_public", "is_active")
    list_filter = ("is_public", "is_active", "campus__university")
    search_fields = ("name", "description")


@admin.register(DiscipleshipGroup)
class DiscipleshipGroupAdmin(LocalizedModelAdmin):
    list_display = ("name", "campus", "leader", "visibility", "is_active")
    list_filter = ("visibility", "is_active", "campus__university")
    search_fields = ("name", "description")


@admin.register(Event)
class EventAdmin(LocalizedModelAdmin):
    list_display = ("title", "starts_at", "campus", "status")
    list_filter = ("status", "campus__university")
    search_fields = ("title", "description", "location")
    date_hierarchy = "starts_at"
