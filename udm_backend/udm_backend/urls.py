"""Project API routing. Everything machine-facing lives under `/api/v1/`."""

from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

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
    path("api/v1/", include("content.urls")),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/v1/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
]
