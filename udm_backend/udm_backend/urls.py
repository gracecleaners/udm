"""Project API routing. Everything machine-facing lives under `/api/v1/`."""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from accounts.admin_views import StudentDirectoryView
from accounts.urls import auth_urlpatterns, user_urlpatterns
from content.views import HealthView

admin.site.site_header = "UDM Ministry Console"
admin.site.site_title = "UDM"
admin.site.index_title = "Content and ministry operations"

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/health/", HealthView.as_view(), name="health"),
    path("api/v1/auth/", include(auth_urlpatterns)),
    path("api/v1/users/", include(user_urlpatterns)),
    # The roster belongs to `accounts`, so it is mounted here rather than in
    # the content app's curation routes.
    path("api/v1/admin/students/", StudentDirectoryView.as_view(), name="admin_students"),
    path("api/v1/", include("content.urls")),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/v1/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
]

# Uploaded covers are served by the dev server only. A deployment puts
# `UDM_MEDIA_ROOT` behind its own web server or object store, which is why the
# API hands back an absolute URL rather than a path the client has to guess.
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
