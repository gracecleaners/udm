"""Session endpoints and the roster for the ministry console.

The console is a browser app, so it cannot keep credentials in a keystore the
way the mobile app does. These views split the token pair deliberately: the
short-lived access token is handed to the client and held in memory only, while
the long-lived refresh token goes into an HttpOnly cookie scoped to this path.
A cross-site page cannot read that cookie or send it on a POST (SameSite=Lax),
and no script on this origin can exfiltrate it.
"""

from django.conf import settings
from django.db.models import Count
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from .models import User
from .permissions import IsMinistryStaff
from .serializers import AdminIdentitySerializer, StaffTokenObtainPairSerializer, StudentDirectorySerializer

REFRESH_COOKIE = "udm_admin_refresh"
# Only the session endpoints need the credential, so only they ever receive it.
REFRESH_PATH = "/api/v1/auth/admin/"


def _lifetime():
    return settings.SIMPLE_JWT["REFRESH_TOKEN_LIFETIME"].total_seconds()


def _set_refresh_cookie(response, request, refresh):
    response.set_cookie(
        REFRESH_COOKIE,
        refresh,
        max_age=_lifetime(),
        path=REFRESH_PATH,
        # Read the flag off the request, not the response: DRF only attaches
        # the request during `finalize_response`, after the view has returned,
        # so asking the response here would raise instead of deciding anything.
        # Behind TLS `request.is_secure()` is true, so production gets a Secure
        # cookie without a separate setting that could drift from reality.
        secure=request.is_secure(),
        httponly=True,
        samesite="Lax",
    )
    return response


def _issued_refresh(data):
    """Pop the refresh token out of a response body before it reaches the page."""
    refresh = data.pop("refresh", None)
    return refresh


class AdminTokenObtainPairView(TokenObtainPairView):
    serializer_class = StaffTokenObtainPairSerializer
    permission_classes = [permissions.AllowAny]
    throttle_scope = "auth"

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        refresh = _issued_refresh(data)
        response = Response(data, status=status.HTTP_200_OK)
        return _set_refresh_cookie(response, request, refresh)


class _CookieSessionView(APIView):
    """Anonymous by design: the cookie *is* the credential, and Django's
    session auth must not be consulted for CSRF on an API-only route."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]
    throttle_scope = "auth"

    def get_refresh(self, request):
        return request.COOKIES.get(REFRESH_COOKIE) or ""


class AdminTokenRefreshView(_CookieSessionView):
    def post(self, request, *args, **kwargs):
        refresh = self.get_refresh(request)
        if not refresh:
            return Response(
                {"detail": "Your session has ended. Sign in again.", "code": "not_authenticated", "status": 401},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        try:
            data = TokenRefreshSerializer().run_validation({"refresh": refresh})
        except TokenError:
            response = Response(
                {"detail": "Your session has ended. Sign in again.", "code": "not_authenticated", "status": 401},
                status=status.HTTP_401_UNAUTHORIZED,
            )
            response.delete_cookie(REFRESH_COOKIE, path=REFRESH_PATH)
            return response

        new_refresh = data.pop("refresh", None) or refresh
        response = Response({"access": data["access"]})
        return _set_refresh_cookie(response, request, new_refresh)


class AdminLogoutView(_CookieSessionView):
    def post(self, request, *args, **kwargs):
        refresh = self.get_refresh(request)
        revoked = False
        if refresh:
            try:
                RefreshToken(refresh).blacklist()
                revoked = True
            except TokenError:
                revoked = False
        response = Response(
            {"revoked": revoked},
            status=status.HTTP_200_OK if revoked else status.HTTP_204_NO_CONTENT,
        )
        response.delete_cookie(REFRESH_COOKIE, path=REFRESH_PATH)
        return response


class AdminIdentityView(APIView):
    """Who is signed in, and what the console may show them.

    The student profile endpoint stays untouched; a console needs the staff
    flags, and those belong to an endpoint only staff can reach.
    """

    permission_classes = [IsMinistryStaff]

    def get(self, request, *args, **kwargs):
        return Response(AdminIdentitySerializer(request.user).data)


class StudentDirectoryView(generics.ListAPIView):
    """Read-only roster: identity, staff flag and two public ministry counts.

    There is no create, update or delete route here, and no route that reaches
    a student's private records. The counts cover groups a student leads and
    events they organise, both of which the app already shows publicly;
    enrolments, progress, bookmarks, notes, attempts and prayer requests stay
    out of reach, exactly as `UserContentProgress` stays out of Django Admin.
    """

    permission_classes = [IsMinistryStaff]
    serializer_class = StudentDirectorySerializer
    queryset = User.objects.select_related("profile").annotate(
        groups_led=Count("led_discipleship_groups", distinct=True),
        events_organized=Count("organized_events", distinct=True),
    ).order_by("-created_at")
    search_fields = ["email", "profile__full_name"]
    ordering_fields = ["email", "created_at", "is_staff", "groups_led", "events_organized"]
