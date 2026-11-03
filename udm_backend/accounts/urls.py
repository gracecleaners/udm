from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView, TokenVerifyView

from .views import CurrentUserView, LogoutView, RegistrationView, UdmTokenObtainPairView

auth_urlpatterns = [
    path("token/", UdmTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("token/verify/", TokenVerifyView.as_view(), name="token_verify"),
    path("token/logout/", LogoutView.as_view(), name="token_logout"),
    path("register/", RegistrationView.as_view(), name="register"),
]

user_urlpatterns = [
    path("me/", CurrentUserView.as_view(), name="me"),
]
