"""Ministry staff versus platform admin, and the two things only an admin may do.

The rule the console is built on is irreversibility: staff add and edit content
and watch the system, because any of that can be undone by editing it again.
Deleting a student account and asserting the right to publish a Bible
translation cannot be, so those two belong to the platform owner alone.
"""

from django.contrib import admin as django_admin
from django.contrib.auth.models import Permission
from django.contrib.contenttypes.models import ContentType
from django.test import RequestFactory
from core.testing import UdmAPITestCase

from accounts.models import User, UserProfile
from content.models import BibleTranslation, Devotional, DevotionalSeries, MemoryVerse


class ConsolePermissionTests(UdmAPITestCase):
    def setUp(self):
        self.staff = User.objects.create_user(
            email="worker@udm.ac.ke", password="long-enough-pass", is_staff=True
        )
        self.owner = User.objects.create_superuser(
            email="owner@udm.ac.ke", password="long-enough-pass"
        )
        self.student = User.objects.create_user(email="learner@udm.ac.ke", password="long-enough-pass")
        self.translation = BibleTranslation.objects.create(
            code="kjv", name="King James Version", license_name="Public domain",
            attribution="KJV", is_active=True,
        )

    def test_anonymous_and_students_are_kept_out_of_the_console(self):
        for path in ("/api/v1/admin/devotions/", "/api/v1/admin/devotion-series/", "/api/v1/admin/students/"):
            self.assertEqual(self.client.get(path).status_code, 401, path)
            self.client.force_authenticate(user=self.student)
            response = self.client.get(path)
            self.assertEqual(response.status_code, 403, path)
            self.assertIn("staff", response.json()["detail"].lower())
            self.client.force_authenticate(user=None)

    def test_staff_curate_content(self):
        self.client.force_authenticate(user=self.staff)
        created = self.client.post(
            "/api/v1/admin/devotion-series/",
            {"title": "The Book of James", "description": "Seven days.", "order": 1, "is_published": True},
            format="json",
        )
        self.assertEqual(created.status_code, 201, created.json())
        series = DevotionalSeries.objects.get(pk=created.json()["id"])
        self.assertTrue(series.is_published)

        edited = self.client.patch(
            f"/api/v1/admin/devotion-series/{series.id}/", {"title": "James: Faith at Work"}, format="json"
        )
        self.assertEqual(edited.status_code, 200)
        self.assertEqual(DevotionalSeries.objects.get(pk=series.id).title, "James: Faith at Work")

    def test_a_console_write_moves_the_stamp_the_app_polls(self):
        # The dashboard and the app are kept in step by one number: an edit saved
        # here has to raise it in the same request, or a student's cached screen
        # stays stale until they reopen the app.
        self.client.force_authenticate(user=self.staff)
        before = self.client.get("/api/v1/content-version/").json()["version"]
        created = self.client.post(
            "/api/v1/admin/devotions/",
            {"title": "Saved from the console", "scripture_reference": "James 1:5", "body": "Ask for wisdom."},
            format="json",
        )
        self.assertEqual(created.status_code, 201, created.json())
        self.assertGreater(self.client.get("/api/v1/content-version/").json()["version"], before)

    def test_the_devotions_table_names_the_series_each_day_belongs_to(self):
        # The console lists every series' days in one table, so a bare key is
        # not enough for staff to tell where a reading sits.
        self.client.force_authenticate(user=self.staff)
        series = self.client.post(
            "/api/v1/admin/devotion-series/", {"title": "The Book of James"}, format="json"
        ).json()
        created = self.client.post(
            "/api/v1/admin/devotions/",
            {
                "title": "Salutation and patience",
                "scripture_reference": "James 1:1-8",
                "body": "Count it all joy.",
                "series": series["id"],
                "day": 1,
            },
            format="json",
        )
        self.assertEqual(created.status_code, 201, created.json())
        self.assertEqual(created.json()["series_title"], "The Book of James")
        self.assertEqual(created.json()["day"], 1)

        listed = self.client.get("/api/v1/admin/devotions/", {"series": series["id"]}).json()["results"]
        self.assertEqual([row["series_title"] for row in listed], ["The Book of James"])

        unfiled = self.client.post(
            "/api/v1/admin/devotions/",
            {"title": "A Tuesday reading", "scripture_reference": "Psalm 23", "body": "The Lord is my shepherd."},
            format="json",
        )
        self.assertEqual(unfiled.status_code, 201, unfiled.json())
        self.assertIsNone(unfiled.json()["series_title"])

        duplicate = self.client.post(
            "/api/v1/admin/devotions/",
            {
                "title": "The same day twice",
                "scripture_reference": "James 1:1",
                "body": "A second attempt at day one.",
                "series": series["id"],
                "day": 1,
            },
            format="json",
        )
        self.assertEqual(duplicate.status_code, 400, duplicate.json())
        self.assertEqual(Devotional.objects.filter(series_id=series["id"], day=1).count(), 1)

    def test_staff_can_undo_their_own_edit_by_deleting_the_row(self):
        self.client.force_authenticate(user=self.staff)
        created = self.client.post(
            "/api/v1/admin/devotion-series/", {"title": "Typed by mistake"}, format="json"
        )
        self.assertEqual(
            self.client.delete(f"/api/v1/admin/devotion-series/{created.json()['id']}/").status_code, 204
        )
        self.assertFalse(DevotionalSeries.objects.exists())

    def test_staff_monitor_the_roster_but_cannot_change_licensing(self):
        UserProfile.objects.create(user=self.student, full_name="Grace")
        self.client.force_authenticate(user=self.staff)
        students = self.client.get("/api/v1/admin/students/", {"search": "learner@udm"})
        self.assertEqual(students.status_code, 200)
        self.assertEqual(students.json()["results"][0]["display_name"], "Grace")

        self.assertEqual(self.client.get(f"/api/v1/admin/translations/{self.translation.id}/").status_code, 200)
        blocked = self.client.patch(
            f"/api/v1/admin/translations/{self.translation.id}/",
            {"license_name": "Closed"}, format="json",
        )
        self.assertEqual(blocked.status_code, 403)
        self.assertIn("admin", blocked.json()["detail"].lower())
        self.assertEqual(BibleTranslation.objects.get(pk=self.translation.id).license_name, "Public domain")

    def test_only_the_platform_admin_changes_licensing(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.patch(
            f"/api/v1/admin/translations/{self.translation.id}/", {"is_active": False}, format="json"
        )
        self.assertEqual(response.status_code, 200, response.json())
        self.assertFalse(BibleTranslation.objects.get(pk=self.translation.id).is_active)

    def test_a_stored_memory_verse_needs_a_reference_and_a_licensed_version(self):
        self.client.force_authenticate(user=self.staff)
        refused = self.client.post(
            "/api/v1/admin/memory-verses/",
            {"reference": "1 Corinthians 13:4", "text": "Love is patient.", "translation_code": "niv"},
            format="json",
        )
        self.assertEqual(refused.status_code, 400, refused.json())
        self.assertFalse(MemoryVerse.objects.exists())

        accepted = self.client.post(
            "/api/v1/admin/memory-verses/",
            {"reference": "1 Corinthians 13:4", "text": "Love is patient.", "translation_code": "kjv"},
            format="json",
        )
        self.assertEqual(accepted.status_code, 201, accepted.json())
        self.assertEqual(accepted.json()["display_text"], "Love is patient.")


class DjangoAdminDeletionGateTests(UdmAPITestCase):
    """The console's own delete control, which is where a staff account lands."""

    def setUp(self):
        self.factory = RequestFactory()
        self.owner = User.objects.create_superuser(email="owner@udm.ac.ke", password="long-enough-pass")
        self.staff = User.objects.create_user(
            email="worker@udm.ac.ke", password="long-enough-pass", is_staff=True
        )
        # Grant the staff account Django's own permissions outright. Without
        # the platform-owner gate the base ModelAdmin would then allow both
        # editing and deleting, which is the hole this gate exists to close.
        user_type = ContentType.objects.get_for_model(User)
        self.staff.user_permissions.add(
            *Permission.objects.filter(content_type=user_type, codename__in=["change_user", "delete_user"])
        )

    def _request(self, user):
        request = self.factory.get("/admin/accounts/user/delete")
        request.user = user
        return request

    def test_staff_cannot_delete_a_student_account(self):
        target = User.objects.create_user(email="learner@udm.ac.ke", password="long-enough-pass")
        model_admin = django_admin.site._registry[User]
        self.assertTrue(model_admin.has_change_permission(self._request(self.staff), target))
        self.assertFalse(model_admin.has_delete_permission(self._request(self.staff), target))

    def test_the_platform_admin_can(self):
        target = User.objects.create_user(email="learner@udm.ac.ke", password="long-enough-pass")
        model_admin = django_admin.site._registry[User]
        self.assertTrue(model_admin.has_delete_permission(self._request(self.owner), target))
