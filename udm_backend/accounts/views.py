from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenBlacklistView, TokenObtainPairView

from .models import UserProfile
from .serializers import (
    CurrentUserSerializer,
    RegistrationSerializer,
    UserSummarySerializer,
    UdmTokenObtainPairSerializer,
)


class UdmTokenObtainPairView(TokenObtainPairView):
    serializer_class = UdmTokenObtainPairSerializer
    permission_classes = [permissions.AllowAny]
    throttle_scope = "auth"


class RegistrationView(generics.CreateAPIView):
    """Register a student and hand back a session immediately."""

    serializer_class = RegistrationSerializer
    permission_classes = [permissions.AllowAny]
    throttle_scope = "auth"

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSummarySerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )


class LogoutView(TokenBlacklistView):
    """Secure logout: the refresh token is revoked, not merely forgotten."""

    # SimpleJWT's token endpoints are anonymous by default, which leaves the
    # base view with no authenticators at all; revocation is not anonymous.
    authentication_classes = [JWTAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    throttle_scope = "auth"


class CurrentUserView(generics.RetrieveUpdateAPIView):
    """The signed-in student's own profile. There is no lookup by id: another
    account can neither read nor edit it."""

    serializer_class = CurrentUserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return UserProfile.for_user(self.request.user)
