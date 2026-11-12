from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView, TokenVerifyView

from .admin_views import (
    AdminIdentityView,
    AdminLogoutView,
    AdminTokenObtainPairView,
    AdminTokenRefreshView,
)
from .views import CurrentUserView, LogoutView, RegistrationView, UdmTokenObtainPairView

auth_urlpatterns = [
    path("token/", UdmTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("token/verify/", TokenVerifyView.as_view(), name="token_verify"),
    path("token/logout/", LogoutView.as_view(), name="token_logout"),
    path("register/", RegistrationView.as_view(), name="register"),
    # The ministry console. Separate from the student pair above because it
    # carries the refresh token in a cookie instead of a response body.
    path("admin/token/", AdminTokenObtainPairView.as_view(), name="admin_token_obtain_pair"),
    path("admin/token/refresh/", AdminTokenRefreshView.as_view(), name="admin_token_refresh"),
    path("admin/token/logout/", AdminLogoutView.as_view(), name="admin_token_logout"),
    path("admin/me/", AdminIdentityView.as_view(), name="admin_identity"),
]

user_urlpatterns = [
    path("me/", CurrentUserView.as_view(), name="me"),
]
