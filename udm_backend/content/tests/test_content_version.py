"""The content version stamp: one number that says whether the app's copies are stale.

The mobile app refetches the screens it cached only when this number moved, so
the tests here are about coverage — does every change the student can see move
the number — rather than about the arithmetic.
"""

from core.testing import UdmAPITestCase

from accounts.models import User, UserProfile
from content.models import Article, ContentVersion, Devotional, DevotionalSeries, MemoryVerse


class ContentVersionModelTests(UdmAPITestCase):
    def test_no_row_reads_as_zero(self):
        self.assertEqual(ContentVersion.current(), 0)

    def test_bump_creates_the_row_and_counts(self):
        self.assertEqual(ContentVersion.bump(), 1)
        self.assertEqual(ContentVersion.bump(), 2)
        self.assertEqual(ContentVersion.current(), 2)

    def test_saving_a_tracked_model_bumps_once(self):
        before = ContentVersion.current()
        Devotional.objects.create(title="Fresh", scripture_reference="James 1:1", body="Text.")
        self.assertEqual(ContentVersion.current(), before + 1)

    def test_deleting_bumps_too(self):
        article = Article.objects.create(title="To remove", body="Text.", is_published=True)
        before = ContentVersion.current()
        article.delete()
        self.assertEqual(ContentVersion.current(), before + 1)

    def test_an_import_that_bulk_creates_moves_the_stamp(self):
        # `bulk_create` fires no post_save, which is why import_bible calls
        # mark_content_changed() itself. Without it a freshly imported Bible
        # would leave every device serving its old cached chapter.
        from json import dumps
        from pathlib import Path
        from unittest.mock import patch

        from django.core.management import call_command

        payload = {
            "translation": {
                "code": "sample",
                "name": "Sample Translation",
                "license_name": "Public domain sample",
                "attribution": "Sample attribution",
                "offline_allowed": True,
            },
            "books": [{
                "name": "Genesis", "order": 1, "testament": "old",
                "chapters": [{"number": 1, "verses": [{"number": 1, "text": "Sample verse text."}]}],
            }],
        }
        before = ContentVersion.current()
        with patch.object(Path, "read_text", side_effect=lambda **_: dumps(payload)):
            call_command("import_bible", Path("sample.json"), verbosity=0)
        self.assertGreater(ContentVersion.current(), before)

    def test_the_bump_helper_counts_a_signal_free_write(self):
        from content.signals import mark_content_changed

        before = ContentVersion.current()
        Article.objects.create(title="Row", body="Text.")
        mark_content_changed()
        self.assertEqual(ContentVersion.current(), before + 2)

    def test_a_change_the_student_cannot_see_does_not_bump(self):
        before = ContentVersion.current()
        user = User.objects.create_user(email="learner@udm.ac.ke", password="long-enough-pass")
        UserProfile.objects.create(user=user, full_name="Grace")
        self.assertEqual(ContentVersion.current(), before)

    def test_every_model_the_app_renders_is_tracked(self):
        from content.signals import TRACKED_MODELS

        for model in (DevotionalSeries, Devotional, Article, MemoryVerse):
            self.assertIn(model, TRACKED_MODELS)


class ContentVersionApiTests(UdmAPITestCase):
    def test_endpoint_is_public_and_returns_a_number(self):
        response = self.client.get("/api/v1/content-version/")
        self.assertEqual(response.status_code, 200)
        self.assertIsInstance(response.json()["version"], int)

    def test_the_app_sees_the_bump_immediately(self):
        before = self.client.get("/api/v1/content-version/").json()["version"]
        Devotional.objects.create(
            title="Edited just now", scripture_reference="James 1:1", body="Text.", is_published=True
        )
        after = self.client.get("/api/v1/content-version/").json()["version"]
        self.assertGreater(after, before)

    def test_a_payload_dates_the_copy_it_sends(self):
        # The number travels with the content, not only on its own endpoint: a
        # device that asked for both at once must still be able to say which
        # copy it was given, and a screen may not stamp its rows with a number
        # that a later edit already moved.
        series = DevotionalSeries.objects.create(title="The Book of James", is_published=True)
        Devotional.objects.create(
            title="Count it all joy", scripture_reference="James 1:2-4", body="Text.",
            series=series, day=1, is_published=True,
        )

        version = ContentVersion.current()
        home = self.client.get("/api/v1/home/").json()
        grid = self.client.get("/api/v1/devotions/series/").json()["results"]
        detail = self.client.get(f"/api/v1/devotions/series/{series.pk}/").json()

        self.assertEqual(home["content_version"], version)
        self.assertEqual(grid[0]["content_version"], version)
        self.assertEqual(detail["content_version"], version)

    def test_an_edited_series_carries_a_newer_number_than_the_copy_before_it(self):
        series = DevotionalSeries.objects.create(title="Christmas", is_published=True)
        Devotional.objects.create(
            title="Day of light", scripture_reference="John 1:1-5", body="Text.",
            series=series, day=1, is_published=True,
        )
        before = self.client.get("/api/v1/devotions/series/").json()["results"][0]

        Devotional.objects.create(
            title="Day of peace", scripture_reference="Luke 2:14", body="Text.",
            series=series, day=2, is_published=True,
        )
        after = self.client.get("/api/v1/devotions/series/").json()["results"][0]

        self.assertGreater(after["content_version"], before["content_version"])
        self.assertEqual(after["day_count"], before["day_count"] + 1)
