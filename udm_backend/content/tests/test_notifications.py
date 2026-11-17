"""The notice inbox, the device tokens push is sent to, and the staff broadcast.

A real phone cannot be tested from here, so what these hold is the part the
server owns: whose rows an inbox answers with, what one token does when two
accounts claim it, and that a push which cannot go out never takes the written
message down with it.
"""

from unittest import mock

from datetime import timedelta

from django.utils import timezone
from core.testing import UdmAPITestCase

from accounts.models import User
from content.models import NotificationDevice, UserNotification

INBOX = "/api/v1/notifications/"
DEVICES = "/api/v1/notifications/devices/"
BROADCAST = "/api/v1/admin/notifications/"


class InboxTests(UdmAPITestCase):
    def setUp(self):
        self.student = User.objects.create_user(email="learner@udm.ac.ug", password="long-enough-pass")
        self.neighbour = User.objects.create_user(email="neighbour@udm.ac.ug", password="long-enough-pass")
        self.client.force_authenticate(user=self.student)

    def notice(self, user, **overrides):
        fields = {"title": "A verse to keep", "body": "The steady ones are not moved.", "kind": "announcement"}
        fields.update(overrides)
        return UserNotification.objects.create(user=user, **fields)

    def test_an_inbox_answers_with_this_account_only(self):
        older = self.notice(self.student, title="Older")
        self.notice(self.student, title="Newer")
        self.notice(self.neighbour)
        # Two rows written in the same test run can share a microsecond, and the
        # inbox is ordered by that stamp alone, so the older one is dated by hand.
        UserNotification.objects.filter(pk=older.pk).update(created_at=timezone.now() - timedelta(days=1))

        response = self.client.get(INBOX)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["unread_count"], 2)
        self.assertEqual([item["title"] for item in response.json()["results"]], ["Newer", "Older"])
        self.assertEqual(len(response.json()["results"]), 2)

    def test_anonymous_is_answered_with_a_refusal_not_an_empty_inbox(self):
        self.client.force_authenticate(user=None)

        self.assertEqual(self.client.get(INBOX).status_code, 401)
        self.assertEqual(self.client.post(INBOX + "read-all/").status_code, 401)
        self.assertEqual(self.client.post(DEVICES, {"token": "t", "platform": "android"}).status_code, 401)

    def test_reading_a_row_once_leaves_the_second_answer_unchanged(self):
        item = self.notice(self.student)

        first = self.client.post(f"{INBOX}{item.id}/read/")
        second = self.client.post(f"{INBOX}{item.id}/read/")

        self.assertEqual(first.status_code, 200)
        self.assertIsNotNone(first.json()["read_at"])
        self.assertEqual(second.json()["read_at"], first.json()["read_at"])
        item.refresh_from_db()
        self.assertIsNotNone(item.read_at)

    def test_a_row_that_is_not_this_students_is_simply_not_here(self):
        foreign = self.notice(self.neighbour)

        response = self.client.post(f"{INBOX}{foreign.id}/read/")

        self.assertEqual(response.status_code, 404)
        foreign.refresh_from_db()
        self.assertIsNone(foreign.read_at)

    def test_marking_all_read_counts_only_what_was_unread(self):
        self.notice(self.student)
        self.notice(self.student, title="Second")

        first = self.client.post(INBOX + "read-all/")
        second = self.client.post(INBOX + "read-all/")

        self.assertEqual(first.status_code, 200)
        self.assertEqual(first.json()["marked_read"], 2)
        self.assertEqual(second.json()["marked_read"], 0)
        self.assertEqual(self.client.get(INBOX).json()["unread_count"], 0)


class DeviceTokenTests(UdmAPITestCase):
    def setUp(self):
        self.student = User.objects.create_user(email="learner@udm.ac.ug", password="long-enough-pass")
        self.neighbour = User.objects.create_user(email="neighbour@udm.ac.ug", password="long-enough-pass")

    def register(self, user, token, platform="android"):
        self.client.force_authenticate(user=user)
        return self.client.post(DEVICES, {"token": token, "platform": platform})

    def test_a_registered_phone_is_owned_by_the_account_that_registered_it(self):
        response = self.register(self.student, "device-token-one")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"registered": True, "platform": "android"})
        device = NotificationDevice.objects.get(token="device-token-one")
        self.assertEqual(device.user, self.student)

    def test_a_token_moves_to_the_account_holding_the_phone_now(self):
        # The same installation is signed out of one account and into the next.
        # `token` is unique, so the row follows rather than refusing to be written.
        self.register(self.student, "shared-token")
        self.register(self.neighbour, "shared-token")

        self.assertEqual(NotificationDevice.objects.count(), 1)
        self.assertEqual(NotificationDevice.objects.get(token="shared-token").user, self.neighbour)

    def test_a_platform_the_server_does_not_know_is_refused(self):
        response = self.register(self.student, "web-token", platform="web")

        self.assertEqual(response.status_code, 400)
        self.assertIn("platform", response.json()["errors"])
        self.assertFalse(NotificationDevice.objects.exists())

    def test_signing_out_forgets_this_token_and_no_other(self):
        self.register(self.student, "first-token")
        self.register(self.neighbour, "second-token")
        self.client.force_authenticate(user=self.student)

        response = self.client.delete(DEVICES, {"token": "second-token"}, format="json")
        self.assertEqual(response.status_code, 204)
        self.assertTrue(NotificationDevice.objects.filter(token="second-token").exists())

        response = self.client.delete(DEVICES, {"token": "first-token"}, format="json")
        self.assertEqual(response.status_code, 204)
        self.assertFalse(NotificationDevice.objects.filter(token="first-token").exists())

    def test_a_forgetting_without_a_token_is_a_refusal_not_a_clear(self):
        self.register(self.student, "device-token-one")
        self.client.force_authenticate(user=self.student)

        response = self.client.delete(DEVICES, {"token": ""}, format="json")

        self.assertEqual(response.status_code, 400)
        self.assertTrue(NotificationDevice.objects.filter(token="device-token-one").exists())


class BroadcastTests(UdmAPITestCase):
    def setUp(self):
        self.staff = User.objects.create_user(
            email="worker@udm.ac.ug", password="long-enough-pass", is_staff=True
        )
        self.student = User.objects.create_user(email="learner@udm.ac.ug", password="long-enough-pass")
        self.quiet = User.objects.create_user(email="quiet@udm.ac.ug", password="long-enough-pass")
        self.quiet.is_active = False
        self.quiet.save()

    def test_a_message_written_by_staff_reaches_every_active_account(self):
        self.client.force_authenticate(user=self.staff)

        response = self.client.post(
            BROADCAST,
            {"title": "Friday prayer night", "body": "It moves to 6pm.", "kind": "event", "destination": "/events"},
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["created_for"], 2)
        for user in (self.student, self.staff):
            notice = UserNotification.objects.get(user=user)
            self.assertEqual(notice.title, "Friday prayer night")
            self.assertEqual(notice.destination, "/events")
        self.assertFalse(UserNotification.objects.filter(user=self.quiet).exists())

    def test_a_student_cannot_write_into_another_account(self):
        self.client.force_authenticate(user=self.student)

        response = self.client.post(BROADCAST, {"title": "Anything", "body": "Anything at all."})

        self.assertEqual(response.status_code, 403)
        self.assertFalse(UserNotification.objects.exists())

    def test_a_destination_is_an_app_route_or_nothing(self):
        self.client.force_authenticate(user=self.staff)

        refused = self.client.post(
            BROADCAST, {"title": "Outward", "body": "Points off the app.", "destination": "https://example.org/feed"}
        )
        self.assertEqual(refused.status_code, 400)
        self.assertIn("destination", refused.json()["errors"])

        allowed = self.client.post(BROADCAST, {"title": "Inbox only", "body": "No link at all."})
        self.assertEqual(allowed.status_code, 201)
        self.assertEqual(UserNotification.objects.filter(title="Inbox only", destination="").count(), 2)

    def test_a_broadcast_hands_the_tokens_over_and_never_waits_for_them(self):
        self.client.force_authenticate(user=self.staff)
        NotificationDevice.objects.create(user=self.student, token="device-token-one", platform="android")

        with mock.patch("content.notifications._send_broadcast") as sending:
            response = self.client.post(BROADCAST, {"title": "Still here", "body": "Written regardless."})

        self.assertEqual(response.status_code, 201)
        sending.assert_called_once_with("Still here", "Written regardless.", "announcement", "", ["device-token-one"])

    def test_push_without_credentials_still_leaves_the_inbox_written(self):
        # The development server has no Firebase service account, so this is the
        # path every local broadcast takes: the push fails, the message stands.
        self.client.force_authenticate(user=self.staff)
        NotificationDevice.objects.create(user=self.student, token="device-token-one", platform="android")

        with self.assertLogs("content.notifications", level="ERROR"):
            response = self.client.post(BROADCAST, {"title": "Plain", "body": "Inbox only here."})

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["created_for"], 2)
        self.assertEqual(UserNotification.objects.filter(title="Plain").count(), 2)
