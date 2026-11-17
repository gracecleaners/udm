from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsMinistryStaff

from .models import NotificationDevice, UserNotification
from .notifications import broadcast_notification
from .serializers import NotificationBroadcastSerializer, NotificationDeviceSerializer, UserNotificationSerializer


class NotificationListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        items = UserNotification.objects.filter(user=request.user)[:100]
        unread_count = UserNotification.objects.filter(user=request.user, read_at__isnull=True).count()
        return Response({
            "unread_count": unread_count,
            "results": UserNotificationSerializer(items, many=True).data,
        })


class NotificationReadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        item = UserNotification.objects.filter(user=request.user, pk=pk).first()
        if item is None:
            return Response({"detail": "Notification not found."}, status=status.HTTP_404_NOT_FOUND)
        if item.read_at is None:
            item.read_at = timezone.now()
            item.save(update_fields=["read_at", "updated_at"])
        return Response(UserNotificationSerializer(item).data)


class NotificationReadAllView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        updated = UserNotification.objects.filter(user=request.user, read_at__isnull=True).update(
            read_at=timezone.now(), updated_at=timezone.now()
        )
        return Response({"marked_read": updated})


class NotificationDeviceView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = NotificationDeviceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        device, _ = NotificationDevice.objects.update_or_create(
            token=serializer.validated_data["token"],
            defaults={"user": request.user, "platform": serializer.validated_data["platform"]},
        )
        return Response({"registered": True, "platform": device.platform}, status=status.HTTP_200_OK)

    def delete(self, request):
        token = request.data.get("token", "")
        if not isinstance(token, str) or not token:
            return Response({"detail": "A device token is required."}, status=status.HTTP_400_BAD_REQUEST)
        NotificationDevice.objects.filter(user=request.user, token=token).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class NotificationBroadcastView(APIView):
    """Staff-only all-student broadcast, also persisted in every inbox."""

    permission_classes = [IsMinistryStaff]

    def post(self, request):
        serializer = NotificationBroadcastSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        count = broadcast_notification(**serializer.validated_data)
        return Response({"created_for": count}, status=status.HTTP_201_CREATED)
