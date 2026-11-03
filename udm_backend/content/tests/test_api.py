from datetime import timedelta

from django.core.exceptions import ValidationError
from django.urls import reverse
from django.utils import timezone
from core.testing import UdmAPITestCase

from accounts.models import User, UserProfile
from content.models import Article, Devotional, FeaturedVerse, UserContentProgress


def make_devotional(title="Daily bread", **overrides):
    fields = dict(
        title=title,
        scripture_reference="Matthew 6:11",
        body="A short study on daily dependence.",
        is_published=True,
    )
    fields.update(overrides)
    return Devotional.objects.create(**fields)


class PublishedVisibilityTests(UdmAPITestCase):
    def setUp(self):
        self.live = make_devotional("Live today")
        self.draft = make_devotional("Not ready", is_published=False)
        self.scheduled = make_devotional("Tomorrow", publish_at=timezone.now() + timedelta(hours=6))
        self.undated = Devotional.objects.create(
            title="Published without a date",
            scripture_reference="Psalm 119:105",
            body="Text",
            is_published=True,
        )

    def test_published_excludes_drafts_and_future_rows(self):
        titles = set(Devotional.objects.published().values_list("title", flat=True))
        self.assertEqual(titles, {"Live today", "Published without a date"})

    def test_published_includes_row_once_its_time_passes(self):
        self.assertIn(self.scheduled, Devotional.objects.published(timezone.now() + timedelta(hours=7)))

    def test_anonymous_listing_only_returns_live_content(self):
        response = self.client.get("/api/v1/devotions/")
        self.assertEqual(response.status_code, 200)
        titles = {row["title"] for row in response.json()["results"]}
        self.assertEqual(titles, {"Live today", "Published without a date"})

    def test_anonymous_detail_of_draft_is_not_found(self):
        response = self.client.get(f"/api/v1/devotions/{self.draft.id}/")
        self.assertEqual(response.status_code, 404)
        body = response.json()
        self.assertEqual(body["code"], "not_found")
        self.assertEqual(body["status"], 404)
        # A hidden record reads as missing, never as "not valid".
        self.assertNotIn("submitted data", body["detail"].lower())

    def test_authenticated_default_denies_unmarked_endpoints(self):
        # The API is fail-closed: only explicitly public endpoints answer.
        self.assertEqual(self.client.get("/api/v1/progress/").status_code, 401)

    def test_article_listing_hides_drafts(self):
        Article.objects.create(title="Live article", body="study", category="Bible study", is_published=True)
        Article.objects.create(title="Draft article", body="study", is_published=False)
        titles = {row["title"] for row in self.client.get("/api/v1/articles/").json()["results"]}
        self.assertEqual(titles, {"Live article"})

    def test_search_filters_published_rows(self):
        response = self.client.get("/api/v1/devotions/", {"search": "Tomorrow"})
        self.assertEqual(response.json()["results"], [])
        response = self.client.get("/api/v1/devotions/", {"search": "Live"})
        self.assertEqual(len(response.json()["results"]), 1)


class FeaturedVerseTests(UdmAPITestCase):
    def test_rotation_is_stable_for_a_day_and_skips_inactive_rows(self):
        first = FeaturedVerse.objects.create(reference="Romans 12:2", text="Be transformed...", translation_code="kjv")
        second = FeaturedVerse.objects.create(reference="Joshua 1:9", text="Be strong...", translation_code="kjv")
        day = timezone.localdate()
        self.assertEqual(FeaturedVerse.for_date(day), FeaturedVerse.for_date(day))
        self.assertIn(FeaturedVerse.for_date(day), (first, second))

        second.is_active = False
        second.save()
        self.assertEqual(FeaturedVerse.for_date(day), first)

    def test_window_limits_when_a_verse_is_shown(self):
        today = timezone.localdate()
        FeaturedVerse.objects.create(
            reference="John 15:5",
            text="I am the vine",
            translation_code="kjv",
            start_date=today - timedelta(days=3),
            end_date=today - timedelta(days=1),
        )
        self.assertIsNone(FeaturedVerse.for_date(today))

    def test_disallowed_translation_is_rejected_by_full_clean(self):
        with self.assertRaises(ValidationError):
            FeaturedVerse(reference="1 Corinthians 13:4", text="Love is patient", translation_code="niv").full_clean()

    def test_home_uses_stored_scripture_rather_than_hardcoded_text(self):
        FeaturedVerse.objects.create(
            reference="Psalm 119:105",
            text="Thy word is a lamp unto my feet",
            translation_code="kjv",
        )
        payload = self.client.get("/api/v1/home/").json()
        self.assertEqual(payload["verse"]["reference"], "Psalm 119:105")
        self.assertNotIn("Romans 12:2", payload["verse"]["text"])

    def test_home_tolerates_missing_content(self):
        payload = self.client.get("/api/v1/home/").json()
        self.assertIsNone(payload["verse"])
        self.assertIsNone(payload["devotion"])
        self.assertEqual(payload["articles"], [])


class HomeGreetingTests(UdmAPITestCase):
    def test_greeting_addresses_a_signed_in_student(self):
        user = User.objects.create_user(email="student@udm.ac.ke", password="long-enough-pass")
        UserProfile.objects.create(user=user, full_name="Grace")
        self.client.force_authenticate(user=user)
        self.assertIn("Grace", self.client.get("/api/v1/home/").json()["greeting"])

    def test_anonymous_greeting_has_no_name(self):
        self.assertNotIn(",", self.client.get("/api/v1/home/").json()["greeting"])


class ProgressApiTests(UdmAPITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="learner@udm.ac.ke", password="long-enough-pass")
        self.other = User.objects.create_user(email="friend@udm.ac.ke", password="long-enough-pass")
        self.devotional = make_devotional()
        self.client.force_authenticate(user=self.user)

    def test_create_records_completion(self):
        response = self.client.post(
            "/api/v1/progress/",
            {"kind": "devotional", "content_id": str(self.devotional.id), "note": "Convicted by verse 3."},
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(UserContentProgress.objects.filter(user=self.user).count(), 1)

    def test_repeating_the_same_completion_does_not_duplicate(self):
        payload = {"kind": "devotional", "content_id": str(self.devotional.id), "note": "first"}
        self.client.post("/api/v1/progress/", payload, format="json")
        payload["note"] = "second"
        self.client.post("/api/v1/progress/", payload, format="json")
        rows = UserContentProgress.objects.filter(user=self.user, content_id=self.devotional.id)
        self.assertEqual(rows.count(), 1)
        self.assertEqual(rows[0].note, "second")

    def test_unknown_content_id_is_rejected_with_the_error_envelope(self):
        response = self.client.post(
            "/api/v1/progress/",
            {"kind": "article", "content_id": "3f1b6c1a-0000-4000-8000-000000000000"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        body = response.json()
        self.assertIn("content_id", body["errors"])
        self.assertIn("detail", body)
        self.assertIn("code", body)

    def test_private_note_is_not_visible_to_another_user(self):
        UserContentProgress.objects.create(
            user=self.user, kind="devotional", content_id=self.devotional.id, note="very private"
        )
        self.client.force_authenticate(user=self.other)
        self.assertEqual(self.client.get("/api/v1/progress/").json()["results"], [])


class AuthenticationTests(UdmAPITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="runner@udm.ac.ke", password="sup3r-long-secret")

    def obtain(self, email="runner@udm.ac.ke", password="sup3r-long-secret"):
        return self.client.post(reverse("token_obtain_pair"), {"email": email, "password": password}, format="json")

    def test_token_returns_identity_summary(self):
        body = self.obtain().json()
        self.assertIn("access", body)
        self.assertIn("refresh", body)
        self.assertEqual(body["user"]["email"], "runner@udm.ac.ke")

    def test_bad_password_is_rejected(self):
        self.assertEqual(self.obtain(password="wrong-password").status_code, 401)

    def test_refresh_rotates_and_blocks_reuse(self):
        refresh = self.obtain().json()["refresh"]
        rotated = self.client.post(reverse("token_refresh"), {"refresh": refresh}, format="json").json()
        self.assertIn("access", rotated)
        self.assertEqual(
            self.client.post(reverse("token_refresh"), {"refresh": refresh}, format="json").status_code, 401
        )

    def test_verify_accepts_a_live_access_token(self):
        access = self.obtain().json()["access"]
        self.assertEqual(self.client.post(reverse("token_verify"), {"token": access}, format="json").status_code, 200)

    def test_authenticated_request_reaches_a_scoped_endpoint(self):
        access = self.obtain().json()["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        self.assertEqual(self.client.get("/api/v1/progress/").status_code, 200)


class HealthTests(UdmAPITestCase):
    def test_health_reports_database_reachability(self):
        body = self.client.get("/api/v1/health/").json()
        self.assertEqual(body["status"], "ok")
        self.assertEqual(body["database"], "up")
