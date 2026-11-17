"""Ministry staff versus platform admin, and what only an admin may do.

The rule the console is built on is irreversibility: staff add and edit content
and watch the system, because any of that can be undone by editing it again.
Deleting a student account, asserting the right to publish a Bible translation
and opening or closing the staff accounts below them cannot be, so those belong
to the platform owner alone.
"""

from django.contrib import admin as django_admin
from django.contrib.auth.models import Permission
from django.contrib.contenttypes.models import ContentType
from django.test import RequestFactory
from core.testing import UdmAPITestCase

from accounts.models import User, UserProfile
from content.models import BibleTranslation, Devotional, DevotionalSeries, DiscipleshipGroup, MemoryVerse


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


class StaffAccountOpeningTests(UdmAPITestCase):
    """The owner's other exclusive act: deciding who else signs in here.

    A staff account is the one row a platform owner creates that hands out
    rights, so these tests follow the whole path — the owner opens it, the new
    account actually signs in, and what it can then reach is only what staff
    are allowed. Nothing on these routes can raise a second owner or lock the
    first one out.
    """

    PASSWORD = "Ministry-Team-2026"

    def setUp(self):
        self.owner = User.objects.create_superuser(email="owner@udm.ac.ke", password="long-enough-pass")
        self.staff = User.objects.create_user(
            email="worker@udm.ac.ke", password="long-enough-pass", is_staff=True
        )
        self.student = User.objects.create_user(email="learner@udm.ac.ke", password="long-enough-pass")

    def test_only_the_owner_sees_who_holds_a_console_account(self):
        self.assertEqual(self.client.get("/api/v1/admin/accounts/").status_code, 401)
        for user in (self.student, self.staff):
            self.client.force_authenticate(user=user)
            refused = self.client.get("/api/v1/admin/accounts/")
            self.assertEqual(refused.status_code, 403, user.email)
            self.assertIn("admin", refused.json()["detail"].lower())
            self.assertEqual(refused.json()["detail"].count("staff"), 0)

    def test_the_list_offers_only_console_accounts_and_not_the_owner(self):
        self.client.force_authenticate(user=self.owner)
        rows = self.client.get("/api/v1/admin/accounts/").json()["results"]
        self.assertEqual([row["email"] for row in rows], ["worker@udm.ac.ke"])

    def test_the_owner_opens_a_staff_account_that_signs_in(self):
        self.client.force_authenticate(user=self.owner)
        created = self.client.post(
            "/api/v1/admin/accounts/",
            {"email": " NEWCURATOR@udm.ac.ke ", "display_name": "Ruth Businge", "password": self.PASSWORD},
            format="json",
        )
        self.assertEqual(created.status_code, 201, created.json())
        body = created.json()
        account = User.objects.get(pk=body["id"])
        self.assertEqual(account.email, "newcurator@udm.ac.ke")
        self.assertEqual(body["display_name"], "Ruth Businge")
        self.assertEqual((account.is_staff, account.is_superuser, account.is_active), (True, False, True))
        self.assertTrue(account.check_password(self.PASSWORD))
        self.assertNotIn("password", body)

        # The whole point of the row: it signs in through the console's own
        # session endpoint, without the owner handing over a token.
        signed_in = self.client.post(
            "/api/v1/auth/admin/token/",
            {"email": "newcurator@udm.ac.ke", "password": self.PASSWORD},
            format="json",
        )
        self.assertEqual(signed_in.status_code, 200, signed_in.json())
        # `force_authenticate` outranks an Authorization header, so the owner's
        # stamp has to come off before this token decides who the request is.
        self.client.force_authenticate(user=None)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {signed_in.json()['access']}")
        self.assertEqual(self.client.get("/api/v1/admin/devotions/").status_code, 200)
        self.assertEqual(self.client.get("/api/v1/admin/accounts/").status_code, 403)
        self.client.credentials()

    def test_a_new_account_needs_a_password_that_is_not_common(self):
        self.client.force_authenticate(user=self.owner)
        missing = self.client.post(
            "/api/v1/admin/accounts/", {"email": "nobody@udm.ac.ke"}, format="json"
        )
        self.assertEqual(missing.status_code, 400, missing.json())
        self.assertIn("password", missing.json()["errors"])
        self.assertFalse(User.objects.filter(email="nobody@udm.ac.ke").exists())

        weak = self.client.post(
            "/api/v1/admin/accounts/",
            {"email": "weak@udm.ac.ke", "password": "password"},
            format="json",
        )
        self.assertEqual(weak.status_code, 400, weak.json())
        self.assertIn("password", weak.json()["errors"])
        self.assertFalse(User.objects.filter(email="weak@udm.ac.ke").exists())

    def test_the_address_of_an_existing_account_is_taken(self):
        self.client.force_authenticate(user=self.owner)
        clash = self.client.post(
            "/api/v1/admin/accounts/",
            {"email": "worker@udm.ac.ke", "password": self.PASSWORD},
            format="json",
        )
        self.assertEqual(clash.status_code, 400, clash.json())
        self.assertEqual(User.objects.filter(email="worker@udm.ac.ke").count(), 1)

    def test_no_request_on_this_page_can_create_a_second_owner(self):
        self.client.force_authenticate(user=self.owner)
        created = self.client.post(
            "/api/v1/admin/accounts/",
            {
                "email": "hopeful@udm.ac.ke",
                "password": self.PASSWORD,
                "is_superuser": True,
                "is_staff": False,
            },
            format="json",
        )
        self.assertEqual(created.status_code, 201, created.json())
        account = User.objects.get(pk=created.json()["id"])
        self.assertFalse(account.is_superuser)
        # `is_staff` is set by the route, never read from the body.
        self.assertTrue(account.is_staff)

        demoted = self.client.patch(
            f"/api/v1/admin/accounts/{account.pk}/", {"is_staff": False, "is_superuser": True}, format="json"
        )
        self.assertEqual(demoted.status_code, 200, demoted.json())
        account.refresh_from_db()
        self.assertTrue(account.is_staff)
        self.assertFalse(account.is_superuser)

    def test_the_owner_can_suspend_a_staff_account_but_not_themself(self):
        self.client.force_authenticate(user=self.owner)
        suspended = self.client.patch(
            f"/api/v1/admin/accounts/{self.staff.pk}/", {"is_active": False}, format="json"
        )
        self.assertEqual(suspended.status_code, 200, suspended.json())
        self.staff.refresh_from_db()
        self.assertFalse(self.staff.is_active)
        # Suspending is not a reset: the same password still belongs to them,
        # which is what makes it different from closing the account.
        self.assertTrue(self.staff.check_password("long-enough-pass"))
        blocked = self.client.post(
            "/api/v1/auth/admin/token/",
            {"email": "worker@udm.ac.ke", "password": "long-enough-pass"},
            format="json",
        )
        self.assertEqual(blocked.status_code, 401, blocked.json())

        # The owner's own row is not in this page's queryset at all, so there is
        # no route left that could hide or close the last admin account.
        self.assertEqual(
            self.client.patch(f"/api/v1/admin/accounts/{self.owner.pk}/", {"is_active": False}, format="json").status_code,
            404,
        )
        self.assertEqual(self.client.delete(f"/api/v1/admin/accounts/{self.owner.pk}/").status_code, 404)
        self.owner.refresh_from_db()
        self.assertTrue(self.owner.is_active)

    def test_closing_an_account_leaves_the_ministry_rows_it_led(self):
        group = DiscipleshipGroup.objects.create(name="Kampla Wednesday fellowship", leader=self.staff)
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(
            self.client.delete(f"/api/v1/admin/accounts/{self.staff.pk}/").status_code, 204
        )
        self.assertFalse(User.objects.filter(pk=self.staff.pk).exists())
        group.refresh_from_db()
        self.assertIsNone(group.leader)

    def test_the_identity_endpoint_names_what_each_role_may_reach(self):
        staff_caps = ["curation", "directory", "moderation"]
        self.client.force_authenticate(user=self.staff)
        identity = self.client.get("/api/v1/auth/admin/me/").json()
        self.assertEqual(identity["role"], "staff")
        self.assertEqual(identity["capabilities"], staff_caps)

        self.client.force_authenticate(user=self.owner)
        owner = self.client.get("/api/v1/auth/admin/me/").json()
        self.assertEqual(owner["role"], "superuser")
        self.assertEqual(owner["capabilities"], staff_caps + ["translations", "accounts"])


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
