"""Optional Firebase Cloud Messaging delivery for persisted inbox notices."""

import logging

from django.conf import settings

logger = logging.getLogger(__name__)


def broadcast_notification(*, title, body, kind="announcement", destination="", users=None):
    """Persist notices for active users and send best-effort pushes in batches."""
    from django.contrib.auth import get_user_model
    from .models import NotificationDevice, UserNotification

    recipients = users if users is not None else get_user_model().objects.filter(is_active=True)
    notices = []
    for user in recipients.iterator(chunk_size=500):
        notices.append(UserNotification(user=user, title=title, body=body, kind=kind, destination=destination))
    created = UserNotification.objects.bulk_create(notices, batch_size=500)
    recipient_ids = [item.user_id for item in created]
    device_tokens = list(NotificationDevice.objects.filter(user_id__in=recipient_ids).values_list("token", flat=True))
    if created:
        # One inbox row per recipient; one push copy carries the same stable ID
        # per recipient only when targeting a single-user send. Broadcast pushes
        # use the shared title/body and deep link, while the inbox remains per-user.
        _send_broadcast(title, body, kind, destination, device_tokens)
    return len(created)


def _send_broadcast(title, body, kind, destination, tokens):
    if not tokens:
        return
    # FCM's multicast limit is 500. Use the same lazy app initialization as
    # send_push, keeping this module importable without Firebase credentials.
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging

        try:
            app = firebase_admin.get_app()
        except ValueError:
            credential_path = getattr(settings, "UDM_FIREBASE_SERVICE_ACCOUNT", "")
            credential = credentials.Certificate(credential_path) if credential_path else credentials.ApplicationDefault()
            app = firebase_admin.initialize_app(credential)
        for offset in range(0, len(tokens), 500):
            messaging.send_each_for_multicast(
                messaging.MulticastMessage(
                    notification=messaging.Notification(title=title, body=body),
                    data={"kind": kind, "destination": destination},
                    tokens=tokens[offset : offset + 500],
                ),
                app=app,
            )
    except Exception:
        logger.exception("FCM broadcast delivery failed")
