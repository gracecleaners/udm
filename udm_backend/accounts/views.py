from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView

from .serializers import UdmTokenObtainPairSerializer


class UdmTokenObtainPairView(TokenObtainPairView):
    serializer_class = UdmTokenObtainPairSerializer
    permission_classes = [AllowAny]
    throttle_scope = "auth"
