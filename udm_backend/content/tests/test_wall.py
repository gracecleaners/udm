"""The community wall, the place a student stopped, and the numbers they keep.

Three surfaces the 2026 app design asked the backend for. A wall that says
whose prayer it is, how many are standing with it and what was said underneath;
a resume list the home feed can ask for directly instead of walking every
shelf; and a summary whose every number is a count of rows the app could
already list. The artwork tests sit here too because the same design puts a
picture behind a verse, a devotion and an article — and a picture a student
sees is a picture staff uploaded.
"""

import io
import tempfile
from datetime import timedelta

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone
from PIL import Image

from accounts.models import User
from content.models import (
    Article,
    BibleBook,
    BibleBookmark,
    BibleChapter,
    BibleNote,
    BibleReadingAssignment,
    BibleReadingPlan,
    BibleReadingProgress,
    BibleTranslation,
    BibleVerse,
    Devotional,
    DiscipleshipGroup,
    GroupMembership,
    MediaCollection,
    MediaItem,
    MediaWatch,
    MemoryVerse,
    PrayerAffirmation,
    PrayerComment,
    PrayerRequest,
    ResourceStep,
    ResourceTopic,
    UserContentProgress,
)
from core.testing import UdmAPITestCase

# A real YouTube id, so the resume rows carry the shape staff actually paste.
WATCH = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"


def png_bytes():
    buffer = io.BytesIO()
    Image.new("RGB", (4, 4), "white").save(buffer, format="PNG")
    return buffer.getvalue()


def uploaded(name="cover.png"):
    return SimpleUploadedFile(name, png_bytes(), content_type="image/png")


def make_verse():
    """A synced verse, because a bookmark or a note is always about one."""
    translation = BibleTranslation.objects.create(
        code="kjv", name="King James Version", license_name="Public domain",
        attribution="KJV",
    )
    book = BibleBook.objects.create(translation=translation, name="John", order=43, testament="new")
    chapter = BibleChapter.objects.create(book=book, number=3)
    return BibleVerse.objects.create(chapter=chapter, number=16, text="For God so loved the world")


def shared(owner, **overrides):
    """A request already on the wall: consented, approved, public."""
    fields = dict(
        owner=owner,
        body="Please pray for my exams this week.",
        visibility="public",
        share_consent=True,
        moderation_state="approved",
    )
    fields.update(overrides)
    return PrayerRequest.objects.create(**fields)


class WallApiTests(UdmAPITestCase):
    def setUp(self):
        self.student = User.objects.create_user(email="student@udm.ac.ke", password="long-enough-pass")
        self.other = User.objects.create_user(email="other@udm.ac.ke", password="long-enough-pass")
        self.staff = User.objects.create_user(email="staff@udm.ac.ke", password="long-enough-pass", is_staff=True)

    def test_the_wall_says_who_shared_and_who_stands_with_them(self):
        prayer = shared(self.student)
        self.client.force_authenticate(self.other)
        affirm = self.client.post(f"/api/v1/prayers/{prayer.id}/affirm/").json()
        self.assertEqual(affirm, {"affirmed": True, "count": 1})

        self.client.force_authenticate(self.student)
        row = self.client.get("/api/v1/prayers/").json()["results"][0]
        self.assertEqual(row["affirmation_count"], 1)
        # The count is somebody else's; the student has not promised anything.
        self.assertFalse(row["affirmed"])
        self.assertEqual(row["category"], "prayer")

        self.client.force_authenticate(self.other)
        self.assertTrue(self.client.get("/api/v1/prayers/").json()["results"][0]["affirmed"])

    def test_a_name_never_falls_back_to_the_signup_address(self):
        # `display_name` answers with the local part of the email when no name
        # was ever given, and the wall is read by the whole campus.
        shared(self.other)
        self.client.force_authenticate(self.student)
        row = self.client.get("/api/v1/prayers/").json()["results"][0]
        self.assertEqual(row["owner_name"], "A student")

    def test_the_feed_filters_by_wall(self):
        shared(self.student, category="prayer")
        shared(self.student, category="testimony", body="God answered.")
        rows = self.client.get("/api/v1/prayers/?category=testimony").json()["results"]
        self.assertEqual([row["category"] for row in rows], ["testimony"])
        self.assertEqual(len(self.client.get("/api/v1/prayers/").json()["results"]), 2)

    def test_an_unknown_wall_is_refused_rather_than_answering_with_everything(self):
        self.assertEqual(
            self.client.get("/api/v1/prayers/?category=gossip").status_code, 400
        )

    def test_affirming_twice_is_one_promise(self):
        prayer = shared(self.student)
        self.client.force_authenticate(self.other)
        url = f"/api/v1/prayers/{prayer.id}/affirm/"
        self.client.post(url)
        self.assertEqual(self.client.post(url).json(), {"affirmed": True, "count": 1})
        self.assertEqual(PrayerAffirmation.objects.filter(prayer=prayer).count(), 1)
        self.assertEqual(self.client.delete(url).json(), {"affirmed": False, "count": 0})

    def test_a_word_under_a_request_is_listed_newest_first(self):
        prayer = shared(self.student)
        self.client.force_authenticate(self.other)
        comments = f"/api/v1/prayers/{prayer.id}/comments/"
        self.assertEqual(
            self.client.post(comments, {"body": "Standing with you."}, format="json").status_code,
            201,
        )
        # The wall's order is by the minute a word was written, so the second one
        # is posted a day later; two rows in the same second carry no order promise.
        PrayerComment.objects.update(created_at=timezone.now() - timedelta(days=1))
        self.client.post(comments, {"body": "Praying right now."}, format="json")
        rows = self.client.get(comments).json()
        self.assertEqual([row["body"] for row in rows], ["Praying right now.", "Standing with you."])
        self.assertEqual(rows[0]["author_name"], "A student")

        self.client.force_authenticate(self.student)
        self.assertEqual(self.client.get("/api/v1/prayers/").json()["results"][0]["comment_count"], 2)

    def test_an_empty_word_is_not_posted(self):
        prayer = shared(self.student)
        self.client.force_authenticate(self.student)
        response = self.client.post(
            f"/api/v1/prayers/{prayer.id}/comments/", {"body": "   "}, format="json"
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("body", response.json()["errors"])
        self.assertEqual(PrayerComment.objects.filter(prayer=prayer).count(), 0)

    def test_only_the_writer_takes_their_word_back(self):
        prayer = shared(self.student)
        self.client.force_authenticate(self.other)
        created = self.client.post(
            f"/api/v1/prayers/{prayer.id}/comments/", {"body": "I will pray."}, format="json"
        ).json()
        url = f"/api/v1/prayers/{prayer.id}/comments/{created['id']}/"
        self.client.force_authenticate(self.student)
        self.assertEqual(self.client.delete(url).status_code, 403)
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.delete(url).status_code, 204)
        self.assertEqual(PrayerComment.objects.filter(prayer=prayer).count(), 0)

    def test_a_word_is_marked_as_the_viewers_own(self):
        # The app hides a delete it knows the endpoint would refuse, so the list
        # carries the same answer the write does.
        prayer = shared(self.student)
        self.client.force_authenticate(self.other)
        self.client.post(f"/api/v1/prayers/{prayer.id}/comments/", {"body": "I will pray."}, format="json")
        self.client.force_authenticate(self.student)
        self.client.post(f"/api/v1/prayers/{prayer.id}/comments/", {"body": "Thank you."}, format="json")
        rows = self.client.get(f"/api/v1/prayers/{prayer.id}/comments/").json()
        self.assertEqual({row["body"]: row["is_owner"] for row in rows}, {"Thank you.": True, "I will pray.": False})

    def test_a_private_request_cannot_be_answered_by_somebody_else(self):
        private = PrayerRequest.objects.create(owner=self.student, body="Only mine.")
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.post(f"/api/v1/prayers/{private.id}/affirm/").status_code, 404)
        self.assertEqual(
            self.client.get(f"/api/v1/prayers/{private.id}/comments/").status_code, 404
        )

    def test_a_group_request_is_the_group_s_business(self):
        group = DiscipleshipGroup.objects.create(name="Tuesday Study", leader=self.staff)
        prayer = shared(self.student, visibility="group", group=group)
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get("/api/v1/prayers/").json()["results"], [])
        GroupMembership.objects.create(
            user=self.other, group=group, status=GroupMembership.Status.APPROVED
        )
        self.assertEqual(len(self.client.get("/api/v1/prayers/").json()["results"]), 1)
        self.assertTrue(
            self.client.post(f"/api/v1/prayers/{prayer.id}/affirm/").json()["affirmed"]
        )

    def test_staff_can_file_a_request_on_the_right_wall_while_they_review_it(self):
        # The moderation queue holds pending requests only, so a correction to
        # which wall it belongs on happens on the way through, never after.
        prayer = shared(self.student, moderation_state="pending")
        self.client.force_authenticate(self.staff)
        response = self.client.patch(
            f"/api/v1/prayers/moderation/{prayer.id}/", {"category": "testimony"}, format="json"
        )
        self.assertEqual(response.status_code, 200)
        prayer.refresh_from_db()
        self.assertEqual(prayer.category, "testimony")
        self.assertEqual(prayer.moderation_state, "pending")
        self.assertEqual(
            self.client.patch(
                f"/api/v1/prayers/moderation/{shared(self.student).id}/",
                {"category": "prayer"},
                format="json",
            ).status_code,
            404,
        )

    def test_a_student_chooses_the_wall_when_they_share(self):
        self.client.force_authenticate(self.student)
        self.assertEqual(
            self.client.post(
                "/api/v1/prayers/",
                {"body": "Thank You, God.", "visibility": "public", "share_consent": True,
                 "category": "testimony"},
                format="json",
            ).status_code,
            201,
        )
        self.assertEqual(PrayerRequest.objects.get().category, "testimony")


class ResumeApiTests(UdmAPITestCase):
    def setUp(self):
        self.student = User.objects.create_user(email="student@udm.ac.ke", password="long-enough-pass")
        self.shelf = MediaCollection.objects.create(
            title="SOMA", is_published=True, publish_at=timezone.now() - timedelta(days=1)
        )
        self.first = MediaItem.objects.create(
            collection=self.shelf, title="Faith in Action", youtube_url=WATCH,
            duration_seconds=1440, is_published=True, publish_at=timezone.now() - timedelta(days=1),
        )
        self.second = MediaItem.objects.create(
            collection=self.shelf, title="Be Strong", youtube_url=WATCH,
            duration_seconds=600, is_published=True, publish_at=timezone.now() - timedelta(days=1),
        )

    def _stop(self, item, seconds, completed=False):
        watch = MediaWatch.objects.create(user=self.student, item=item, position_seconds=seconds)
        if completed:
            MediaWatch.objects.filter(pk=watch.pk).update(completed_at=timezone.now())
        return watch

    def test_resume_lists_what_the_student_stopped_in(self):
        self._stop(self.first, 300)
        self.client.force_authenticate(self.student)
        rows = self.client.get("/api/v1/media/resume/").json()
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(row["id"], str(self.first.id))
        self.assertEqual(row["title"], "Faith in Action")
        self.assertEqual(row["position_seconds"], 300)
        self.assertEqual(row["duration_seconds"], 1440)
        self.assertEqual(row["collection"]["title"], "SOMA")
        # No artwork was uploaded, so the frame YouTube publishes is the tile.
        self.assertIn("i.ytimg.com", row["image_url"])

    def test_a_finished_recording_is_not_offered_again(self):
        self._stop(self.first, 1440, completed=True)
        self.client.force_authenticate(self.student)
        self.assertEqual(self.client.get("/api/v1/media/resume/").json(), [])

    def test_a_withdrawn_recording_is_not_offered(self):
        self._stop(self.first, 300)
        MediaItem.objects.filter(pk=self.first.pk).update(is_published=False)
        self.client.force_authenticate(self.student)
        self.assertEqual(self.client.get("/api/v1/media/resume/").json(), [])

    def test_the_most_recently_touched_recording_is_offered_first(self):
        older = self._stop(self.first, 100)
        newer = self._stop(self.second, 60)
        MediaWatch.objects.filter(pk=older.pk).update(updated_at=timezone.now() - timedelta(days=2))
        MediaWatch.objects.filter(pk=newer.pk).update(updated_at=timezone.now())
        self.client.force_authenticate(self.student)
        rows = self.client.get("/api/v1/media/resume/").json()
        self.assertEqual([row["title"] for row in rows], ["Be Strong", "Faith in Action"])

    def test_resume_needs_a_student(self):
        self.assertEqual(self.client.get("/api/v1/media/resume/").status_code, 401)


class SummaryApiTests(UdmAPITestCase):
    def setUp(self):
        self.student = User.objects.create_user(email="student@udm.ac.ke", password="long-enough-pass")
        self.devotional = Devotional.objects.create(
            title="Trust God", scripture_reference="Romans 8", body="...",
            is_published=True, publish_at=timezone.now() - timedelta(days=1),
        )
        self.guide = ResourceTopic.objects.create(title="Receive Christ", is_published=True)
        self.steps = [
            ResourceStep.objects.create(
                topic=self.guide, title=f"Step {n}", scripture_reference="John 3", body="...",
                order=n, is_published=True, publish_at=timezone.now() - timedelta(days=1),
            )
            for n in (1, 2)
        ]

    def _finish(self, kind, content_id, days_ago=0):
        row = UserContentProgress.objects.create(user=self.student, kind=kind, content_id=content_id)
        UserContentProgress.objects.filter(pk=row.pk).update(
            completed_at=timezone.now() - timedelta(days=days_ago)
        )
        return row

    def test_the_numbers_come_from_the_rows_themselves(self):
        self._finish("devotional", self.devotional.id)
        self._finish("resource_step", self.steps[0].id)
        verse = make_verse()
        BibleBookmark.objects.create(user=self.student, verse=verse)
        BibleNote.objects.create(user=self.student, verse=verse, body="A verse to sit with.")
        self.client.force_authenticate(self.student)
        summary = self.client.get("/api/v1/progress/summary/").json()
        self.assertEqual(summary["devotionals_completed"], 1)
        self.assertEqual(summary["steps_completed"], 1)
        self.assertEqual(summary["articles_completed"], 0)
        self.assertEqual(summary["bookmarks"], 1)
        self.assertEqual(summary["notes"], 1)
        # One of two lessons: the guide is not finished yet.
        self.assertEqual(summary["guides_completed"], 0)

        self._finish("resource_step", self.steps[1].id)
        self.assertEqual(self.client.get("/api/v1/progress/summary/").json()["guides_completed"], 1)

    def test_history_names_the_item_that_was_finished(self):
        self._finish("devotional", self.devotional.id, days_ago=1)
        self._finish("resource_step", self.steps[0].id)
        self.client.force_authenticate(self.student)
        rows = self.client.get("/api/v1/progress/").json()["results"]
        self.assertEqual(
            [(row["title"], row["kind_label"]) for row in rows],
            [("Step 1", "Resource step"), ("Trust God", "Devotional")],
        )

    def test_a_streak_counts_every_kind_of_study_day(self):
        self._finish("devotional", self.devotional.id, days_ago=2)
        watch = MediaWatch.objects.create(user=self.student, item=MediaItem.objects.create(
            collection=MediaCollection.objects.create(title="SOMA", is_published=True),
            title="Faith in Action", youtube_url=WATCH, is_published=True,
        ), position_seconds=600)
        MediaWatch.objects.filter(pk=watch.pk).update(
            completed_at=timezone.now() - timedelta(days=1),
        )
        assignment = BibleReadingAssignment.objects.create(
            plan=BibleReadingPlan.objects.create(title="Romans in a month", is_published=True),
            day=1,
            reference="John 3",
        )
        progress = BibleReadingProgress.objects.create(user=self.student, assignment=assignment)
        BibleReadingProgress.objects.filter(pk=progress.pk).update(completed_at=timezone.now())
        self.client.force_authenticate(self.student)
        summary = self.client.get("/api/v1/progress/summary/").json()
        self.assertEqual(summary["day_streak"], 3)
        self.assertEqual(summary["plan_days_completed"], 1)

    def test_a_day_that_has_just_begun_does_not_break_the_streak(self):
        self._finish("devotional", self.devotional.id, days_ago=1)
        self.client.force_authenticate(self.student)
        self.assertEqual(self.client.get("/api/v1/progress/summary/").json()["day_streak"], 1)

    def test_a_missed_day_breaks_the_streak(self):
        self._finish("devotional", self.devotional.id, days_ago=4)
        self.client.force_authenticate(self.student)
        self.assertEqual(self.client.get("/api/v1/progress/summary/").json()["day_streak"], 0)

    def test_a_signed_out_caller_gets_nothing_to_count(self):
        self.assertEqual(self.client.get("/api/v1/progress/summary/").status_code, 401)


class ArtworkApiTests(UdmAPITestCase):
    """A picture on a card is a picture staff chose, or the brand tile."""

    def setUp(self):
        self.now = timezone.now() - timedelta(days=1)

    def test_an_uploaded_cover_comes_back_as_a_url(self):
        devotional = Devotional.objects.create(
            title="Trust God in Every Season", scripture_reference="Romans 8", body="...",
            image=uploaded(), is_published=True, publish_at=self.now,
        )
        article = Article.objects.create(
            title="How to study", body="...", image=uploaded("article.png"),
            is_published=True, publish_at=self.now,
        )
        verse = MemoryVerse.objects.create(
            reference="Philippians 4:13", text="I can do all things...",
            image=uploaded("verse.png"), is_published=True,
        )
        home = self.client.get("/api/v1/home/").json()
        self.assertTrue(home["devotion"]["image_url"].endswith(".png"))
        self.assertTrue(home["articles"][0]["image_url"].endswith(".png"))
        self.assertTrue(home["memory_verse"]["image_url"].endswith(".png"))

    def test_a_card_without_a_picture_says_so_rather_than_breaking(self):
        Devotional.objects.create(
            title="No art", scripture_reference="Romans 8", body="...",
            is_published=True, publish_at=self.now,
        )
        home = self.client.get("/api/v1/home/").json()
        self.assertIsNone(home["devotion"]["image_url"])


class CurationImageWriteApiTests(UdmAPITestCase):
    """The console's own write, for the three pictures the 2026 design added.

    A shelf cover has always been uploaded here, so its multipart path was
    proven. A devotion, an article and a verse of the day now carry a picture
    too, and the console sends each one the same two-step way: the row's text as
    JSON, then only the file as `multipart/form-data`. These are those requests.
    """

    def setUp(self):
        self.staff = User.objects.create_user(
            email="curator@udm.ac.ke", password="long-enough-pass", is_staff=True
        )
        self.client.force_authenticate(self.staff)

    @override_settings(MEDIA_ROOT=tempfile.mkdtemp())
    def test_a_chosen_picture_is_stored_and_handed_to_the_student_api(self):
        devotion = self.client.post(
            "/api/v1/admin/devotions/",
            {
                "title": "Trust God in Every Season",
                "scripture_reference": "Romans 8:28",
                "body": "Every season is covered by somebody.",
                "is_published": "true",
                "image": uploaded(),
            },
            format="multipart",
        )
        self.assertEqual(devotion.status_code, 201, devotion.json())
        url = devotion.json()["image_url"]
        self.assertTrue(url.startswith("http://testserver/media/devotionals/"), url)
        self.assertEqual(
            self.client.get(f"/api/v1/devotions/{devotion.json()['id']}/").json()["image_url"], url
        )

        article = self.client.post(
            "/api/v1/admin/articles/",
            {
                "title": "How to study",
                "body": "Four steps, one paragraph each.",
                "is_published": "true",
                "image": uploaded("article.png"),
            },
            format="multipart",
        )
        self.assertEqual(article.status_code, 201, article.json())
        self.assertTrue(article.json()["image_url"].startswith("http://testserver/media/articles/"))

        # The verse of the day is the one row whose write also runs a licensing
        # check, so a file must not turn that refusal into a server error.
        verse = self.client.post(
            "/api/v1/admin/memory-verses/",
            {
                "reference": "Philippians 4:13",
                "text": "I can do all things through Christ.",
                "translation_code": "kjv",
                "is_published": "true",
                "image": uploaded("verse.png"),
            },
            format="multipart",
        )
        self.assertEqual(verse.status_code, 201, verse.json())
        self.assertTrue(verse.json()["image_url"].startswith("http://testserver/media/memory_verses/"))

        refused = self.client.post(
            "/api/v1/admin/memory-verses/",
            {
                "reference": "Philippians 4:13",
                "text": "I can do all things through Christ.",
                "translation_code": "niv",
                "image": uploaded("verse.png"),
            },
            format="multipart",
        )
        self.assertEqual(refused.status_code, 400, refused.json())

    @override_settings(MEDIA_ROOT=tempfile.mkdtemp())
    def test_a_picture_can_be_added_to_a_row_that_already_exists(self):
        # This is the console's second write on its own: the row was created as
        # JSON, and a curator who picks a picture afterwards PATCHes the file
        # alone to the same detail route.
        created = self.client.post(
            "/api/v1/admin/devotions/",
            {
                "title": "A quiet morning",
                "scripture_reference": "Psalm 46:10",
                "body": "Be still.",
                "is_published": "true",
            },
            format="json",
        )
        self.assertIsNone(created.json()["image_url"])

        patched = self.client.patch(
            f"/api/v1/admin/devotions/{created.json()['id']}/",
            {"image": uploaded()},
            format="multipart",
        )
        self.assertEqual(patched.status_code, 200, patched.json())
        self.assertTrue(patched.json()["image_url"].startswith("http://testserver/media/devotionals/"))

        cleared = self.client.patch(
            f"/api/v1/admin/devotions/{created.json()['id']}/",
            {"image": ""},
            format="multipart",
        )
        self.assertEqual(cleared.status_code, 200, cleared.json())
        self.assertIsNone(cleared.json()["image_url"])
