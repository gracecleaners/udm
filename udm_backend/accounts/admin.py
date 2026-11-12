from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.translation import gettext_lazy as _

from .models import User, UserProfile


class PlatformOwnerDeletesOnly(admin.ModelAdmin):
    """Ministry staff monitor accounts; they do not erase them.

    Django Admin is where a user deletion would otherwise sit one click away
    from any `is_staff` account, and a student's bookmarks, notes, progress and
    prayer history go with the row. The console has no delete route at all, so
    this is the whole of the rule: superusers delete, staff read.
    """

    def has_delete_permission(self, request, obj=None):
        return super().has_delete_permission(request, obj) and request.user.is_superuser


@admin.register(User)
class UserAdmin(PlatformOwnerDeletesOnly, BaseUserAdmin):
    ordering = ("-created_at",)
    list_display = ("email", "display_name", "is_active", "is_email_verified", "is_staff", "created_at")
    list_filter = ("is_active", "is_email_verified", "is_staff", "groups")
    search_fields = ("email", "profile__full_name")
    readonly_fields = ("created_at", "updated_at", "last_login")
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        (_("Personal info"), {"fields": ("is_active", "is_email_verified")}),
        (_("Permissions"), {"fields": ("is_staff", "is_superuser", "groups", "user_permissions")}),
        (_("Important dates"), {"fields": ("last_login", "created_at", "updated_at")}),
    )
    add_fieldsets = (
        (None, {"classes": ("wide",), "fields": ("email", "password1", "password2")}),
    )


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "full_name", "university", "campus", "country", "preferred_translation_code")
    search_fields = ("full_name", "user__email", "university", "campus")
    list_filter = ("country", "gender")
    autocomplete_fields = ("user",)
