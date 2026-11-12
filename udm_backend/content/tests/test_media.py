"""The Learn tab: shelves of ministry video and audio, and what a student does with one.

Courses and quizzes are gone; a recording is watched, not graded. The rules these
tests hold are the ones the app's screens depend on: nothing renders that cannot
be played or read, a pasted YouTube address is stored as the video it names, and
a note or a resume point belongs to its writer alone.
"""

import io
import tempfile
import unittest
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import IntegrityError, transaction
from django.test import override_settings
from django.utils import timezone
from PIL import Image

from content.media_refs import youtube_thumbnail, youtube_video_id
from content.models import ContentVersion, MediaCollection, MediaItem, MediaNote, MediaWatch
from core.testing import UdmAPITestCase

# A real YouTube id, so the parser is tested against the shape staff paste.
VIDEO_ID = "dQw4w9WgXcQ"
WATCH = f"https://www.youtube.com/watch?v={VIDEO_ID}&si=track"


def png_bytes():
    buffer = io.BytesIO()
    Image.new("RGB", (4, 4), "white").save(buffer, format="PNG")
    return buffer.getvalue()


def make_shelf(title="SOMA", **overrides):
    fields = dict(
        title=title,
        description="Study, Observe, Meditate, and Apply the Scriptures.",
        order=1,
        is_published=True,
    )
    fields.update(overrides)
    return MediaCollection.objects.create(**fields)


def make_recording(shelf, order=1, title="True Faith Trusts and Sides with God", **overrides):
    fields = dict(
        collection=shelf,
        order=order,
        title=title,
        author="Edgar Karuma",
        body="Israel stood at the edge of the Red Sea.",
        youtube_url=WATCH,
        is_published=True,
    )
    fields.update(overrides)
    return MediaItem.objects.create(**fields)


class YouTubeLinkTests(unittest.TestCase):
    def test_every_form_staff_paste_reads_back_the_same_video(self):
        for url in (
            WATCH,
            f"https://youtu.be/{VIDEO_ID}",
            f"https://m.youtube.com/watch?v={VIDEO_ID}",
            f"https://www.youtube.com/embed/{VIDEO_ID}",
            f"https://www.youtube.com/shorts/{VIDEO_ID}",
            f"https://www.youtube.com/live/{VIDEO_ID}?t=95",
            f"https://music.youtube.com/watch?v={VIDEO_ID}",
            VIDEO_ID,
            f"youtube.com/watch?v={VIDEO_ID}",
        ):
            self.assertEqual(youtube_video_id(url), VIDEO_ID, url)

    def test_a_link_that_is_not_a_video_is_refused_rather_than_guessed(self):
        for url in ("", None, "https://example.org/watch?v=x", "https://youtu.be/short", "https://vimeo.com/123"):
            self.assertIsNone(youtube_video_id(url), url)

    def test_the_thumbnail_follows_the_video_when_nobody_uploaded_artwork(self):
        self.assertEqual(youtube_thumbnail(WATCH), f"https://i.ytimg.com/vi/{VIDEO_ID}/hqdefault.jpg")
        self.assertIsNone(youtube_thumbnail("https://example.org/talk"))


class MediaApiTests(UdmAPITestCase):
    def setUp(self):
        self.soma = make_shelf("SOMA", order=2)
        self.uliza = make_shelf("Uliza", order=1, description="Ask a question, get a biblical response.")
        make_recording(self.uliza, 1, "Who is God?")
        make_recording(self.soma, 2, "Faith That Heeds God's Command")
        make_recording(self.soma, 1, "Faith That Overcomes the Fear of Man")
        self.empty = make_shelf("Podcast", order=3, description="Longer conversations.")

    def test_list_orders_by_the_authored_position_and_hides_an_empty_shelf(self):
        rows = self.client.get("/api/v1/media/").json()["results"]
        self.assertEqual([row["title"] for row in rows], ["Uliza", "SOMA"])

    def test_the_count_a_shelf_promises_is_the_count_its_page_shows(self):
        row = next(r for r in self.client.get("/api/v1/media/").json()["results"] if r["title"] == "SOMA")
        self.assertEqual(row["item_count"], 2)
        self.assertEqual(len(self.client.get(f"/api/v1/media/{self.soma.id}/").json()["items"]), 2)

    def test_detail_lists_authored_order_first_and_newest_after_it(self):
        make_recording(self.soma, None, "Undated talk", publish_at=timezone.now() - timedelta(days=3))
        newest = make_recording(self.soma, None, "This week's talk", publish_at=timezone.now())
        titles = [i["title"] for i in self.client.get(f"/api/v1/media/{self.soma.id}/").json()["items"]]
        self.assertEqual(
            titles,
            [
                "Faith That Overcomes the Fear of Man",
                "Faith That Heeds God's Command",
                newest.title,
                "Undated talk",
            ],
        )

    def test_draft_and_future_recordings_are_not_on_the_page(self):
        make_recording(self.soma, 5, "In the edit", is_published=False)
        make_recording(self.soma, 6, "Next Sunday", publish_at=timezone.now() + timedelta(hours=6))
        orders = [i["order"] for i in self.client.get(f"/api/v1/media/{self.soma.id}/").json()["items"]]
        self.assertEqual(orders, [1, 2])

    def test_a_shelf_whose_only_recording_is_draft_stays_hidden(self):
        make_recording(self.empty, 1, "Pilot episode", is_published=False)
        titles = [r["title"] for r in self.client.get("/api/v1/media/").json()["results"]]
        self.assertNotIn("Podcast", titles)
        self.assertEqual(self.client.get(f"/api/v1/media/{self.empty.id}/").status_code, 404)

    def test_a_draft_shelf_has_no_page(self):
        hidden = make_shelf("In production", is_published=False)
        make_recording(hidden, 1, "Whatever")
        self.assertEqual(self.client.get(f"/api/v1/media/{hidden.id}/").status_code, 404)

    def test_a_row_carries_the_video_id_the_player_needs_and_none_of_the_body(self):
        item = self.client.get(f"/api/v1/media/{self.soma.id}/").json()["items"][0]
        self.assertEqual(item["youtube_video_id"], VIDEO_ID)
        self.assertEqual(item["image_url"], f"https://i.ytimg.com/vi/{VIDEO_ID}/hqdefault.jpg")
        self.assertNotIn("body", item)

    def test_the_recording_page_answers_with_the_link_and_the_shelf_it_sits_on(self):
        recording = make_recording(self.soma, 3, "Faith That Outlasts Us")
        payload = self.client.get(f"/api/v1/media/items/{recording.id}/").json()
        self.assertEqual(payload["body"], "Israel stood at the edge of the Red Sea.")
        self.assertEqual(payload["collection"]["title"], "SOMA")
        self.assertEqual(payload["collection"]["item_count"], 3)
        self.assertIsNotNone(payload["content_version"])

    def test_download_is_offered_only_where_the_ministry_hosts_a_file(self):
        youtube_only = self.client.get(f"/api/v1/media/items/{make_recording(self.soma, 4, 'Watch only').id}/").json()
        self.assertEqual(youtube_only["download_url"], "")
        file = make_recording(
            self.soma,
            5,
            "Sermon audio",
            youtube_url="",
            download_url="https://sermons.udm.ac.ug/week-12.mp3",
        )
        payload = self.client.get(f"/api/v1/media/items/{file.id}/").json()
        self.assertEqual(payload["download_url"], "https://sermons.udm.ac.ug/week-12.mp3")
        self.assertIsNone(payload["youtube_video_id"])

    def test_a_draft_recording_has_no_page(self):
        draft = make_recording(self.soma, 6, "Not released", is_published=False)
        self.assertEqual(self.client.get(f"/api/v1/media/items/{draft.id}/").status_code, 404)

    def test_anonymous_readers_are_told_there_is_no_note_of_theirs(self):
        payload = self.client.get(f"/api/v1/media/items/{make_recording(self.soma, 7, 'Quiet').id}/").json()
        self.assertIsNone(payload["note"])
        self.assertIsNone(payload["watch"])
        self.assertFalse(payload["watched"])


class MediaStudentStateTests(UdmAPITestCase):
    def setUp(self):
        self.User = get_user_model()
        self.student = self.User.objects.create_user(email="learner@udm.ac.ke", password="long-enough-pass")
        self.other = self.User.objects.create_user(email="friend@udm.ac.ke", password="long-enough-pass")
        self.shelf = make_shelf()
        self.recording = make_recording(self.shelf, 1, "Hebrews 11")
        self.note_url = f"/api/v1/media/items/{self.recording.id}/note/"
        self.watch_url = f"/api/v1/media/items/{self.recording.id}/watch/"
        self.client.force_authenticate(user=self.student)

    def detail(self):
        return self.client.get(f"/api/v1/media/items/{self.recording.id}/").json()

    def test_a_note_is_written_read_and_cleared(self):
        written = self.client.put(self.note_url, {"text": "Verse 29 — turning aside is the point."}, format="json")
        self.assertEqual(written.status_code, 200, written.json())
        self.assertEqual(self.detail()["note"]["text"], "Verse 29 — turning aside is the point.")

        self.client.put(self.note_url, {"text": "   "}, format="json")
        self.assertIsNone(self.detail()["note"])
        self.assertFalse(MediaNote.objects.filter(user=self.student).exists())

    def test_writing_a_note_twice_keeps_one_note(self):
        for text in ("First thought", "Second thought"):
            self.client.put(self.note_url, {"text": text}, format="json")
        self.assertEqual(MediaNote.objects.filter(user=self.student, item=self.recording).count(), 1)
        self.assertEqual(self.detail()["note"]["text"], "Second thought")

    def test_another_student_cannot_read_or_write_it(self):
        self.client.put(self.note_url, {"text": "Private"}, format="json")
        self.client.force_authenticate(user=self.other)
        self.assertIsNone(self.detail()["note"])
        self.client.put(self.note_url, {"text": "Someone else's"}, format="json")
        self.client.force_authenticate(user=self.student)
        self.assertEqual(self.detail()["note"]["text"], "Private")
        self.assertEqual(MediaNote.objects.filter(item=self.recording).count(), 2)

    def test_a_note_never_reaches_the_console(self):
        self.client.put(self.note_url, {"text": "Private"}, format="json")
        staff = self.User.objects.create_user(email="worker@udm.ac.ke", password="long-enough-pass", is_staff=True)
        self.client.force_authenticate(user=staff)
        self.assertNotIn(b"Private", self.client.get("/api/v1/admin/media-items/").content)

    def test_a_resume_point_is_kept_and_the_shelf_says_which_recordings_finished(self):
        saved = self.client.put(self.watch_url, {"position_seconds": 940, "completed": False}, format="json")
        self.assertEqual(saved.status_code, 200, saved.json())
        self.assertFalse(self.detail()["watched"])
        make_recording(self.shelf, 2, "Second talk")
        self.client.put(self.watch_url, {"position_seconds": 1200, "completed": True}, format="json")
        payload = self.detail()
        self.assertTrue(payload["watched"])
        self.assertEqual(payload["watch"]["position_seconds"], 1200)
        rows = self.client.get(f"/api/v1/media/{self.shelf.id}/").json()["items"]
        self.assertEqual([row["watched"] for row in rows], [True, False])

    def test_un_marking_watched_clears_the_completion(self):
        self.client.put(self.watch_url, {"completed": True}, format="json")
        self.client.put(self.watch_url, {"completed": False}, format="json")
        self.assertIsNone(MediaWatch.objects.get(user=self.student, item=self.recording).completed_at)

    def test_a_negative_position_is_refused(self):
        refused = self.client.put(self.watch_url, {"position_seconds": -5}, format="json")
        self.assertEqual(refused.status_code, 400)

    def test_state_is_not_written_against_a_recording_that_is_not_out(self):
        draft = make_recording(self.shelf, 9, "Draft talk", is_published=False)
        for url in (f"/api/v1/media/items/{draft.id}/note/", f"/api/v1/media/items/{draft.id}/watch/"):
            self.assertEqual(self.client.put(url, {"text": "Early"}, format="json").status_code, 404)

    def test_a_signed_out_reader_cannot_write_state(self):
        self.client.force_authenticate(user=None)
        self.assertIn(
            self.client.put(self.note_url, {"text": "x"}, format="json").status_code, (401, 403)
        )


class MediaCurationTests(UdmAPITestCase):
    def setUp(self):
        self.User = get_user_model()
        self.staff = self.User.objects.create_user(email="worker@udm.ac.ke", password="long-enough-pass", is_staff=True)
        self.client.force_authenticate(user=self.staff)

    def test_staff_author_a_shelf_and_the_recording_on_it(self):
        shelf = self.client.post(
            "/api/v1/admin/media-collections/",
            {"title": "Podcast", "description": "Longer conversations.", "order": 3, "is_published": True},
            format="json",
        )
        self.assertEqual(shelf.status_code, 201, shelf.json())
        created = self.client.post(
            "/api/v1/admin/media-items/",
            {
                "collection": shelf.json()["id"],
                "title": "What does the church believe?",
                "author": "Edgar Karuma",
                "body": "A longer conversation.",
                "order": 1,
                "youtube_url": f"https://youtu.be/{VIDEO_ID}",
                "duration_seconds": 1740,
                "is_published": True,
            },
            format="json",
        )
        self.assertEqual(created.status_code, 201, created.json())
        self.assertEqual(created.json()["youtube_url"], f"https://youtu.be/{VIDEO_ID}")
        self.assertEqual(self.client.get("/api/v1/media/").json()["results"][0]["title"], "Podcast")

    def test_a_link_that_is_not_youtube_is_refused_with_its_reason(self):
        shelf = make_shelf()
        refused = self.client.post(
            "/api/v1/admin/media-items/",
            {
                "collection": str(shelf.id),
                "title": "Vimeo talk",
                "body": "x",
                "youtube_url": "https://vimeo.com/1234",
            },
            format="json",
        )
        self.assertEqual(refused.status_code, 400)
        self.assertIn("youtube_url", refused.json()["errors"])

    def test_plain_http_media_is_refused(self):
        shelf = make_shelf()
        refused = self.client.post(
            "/api/v1/admin/media-items/",
            {
                "collection": str(shelf.id),
                "title": "Insecure",
                "body": "x",
                "download_url": "http://files.udm.ac.ug/a.mp3",
            },
            format="json",
        )
        self.assertEqual(refused.status_code, 400)
        self.assertIn("download_url", refused.json()["errors"])

    @override_settings(MEDIA_ROOT=tempfile.mkdtemp())
    def test_an_uploaded_cover_is_stored_and_handed_back_as_a_url(self):
        shelf = make_shelf()
        upload = SimpleUploadedFile("talk.png", png_bytes(), content_type="image/png")
        created = self.client.post(
            "/api/v1/admin/media-items/",
            {
                "collection": str(shelf.id),
                "title": "Covered talk",
                "body": "x",
                "youtube_url": WATCH,
                "image": upload,
                "is_published": True,
            },
            format="multipart",
        )
        self.assertEqual(created.status_code, 201, created.json())
        url = created.json()["image_url"]
        self.assertTrue(url.startswith("http://testserver/media/media_items/"), url)
        self.assertEqual(self.client.get(f"/api/v1/media/items/{created.json()['id']}/").json()["image_url"], url)

    def test_the_position_is_unique_within_a_shelf_only(self):
        first, second = make_shelf("SOMA"), make_shelf("Uliza", order=2)
        make_recording(first, 1, "Taken")
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                make_recording(first, 1, "Clash")
        make_recording(second, 1, "Same number, different shelf")

    def test_publishing_is_a_field_write_the_state_is_derived_from(self):
        recording = make_recording(make_shelf("Podcast"), 1, "Pilot")
        live = self.client.patch(
            f"/api/v1/admin/media-items/{recording.id}/", {"publish_at": timezone.now()}, format="json"
        )
        self.assertEqual(live.json()["publish_state"], "live")
        scheduled = self.client.patch(
            f"/api/v1/admin/media-items/{recording.id}/",
            {"publish_at": timezone.now() + timedelta(days=2)},
            format="json",
        )
        self.assertEqual(scheduled.json()["publish_state"], "scheduled")

    def test_saving_a_recording_moves_the_change_stamp(self):
        shelf = make_shelf()
        before = ContentVersion.current()
        make_recording(shelf, 1, "New talk")
        self.assertGreater(ContentVersion.current(), before)

    def test_the_learning_endpoints_a_student_used_are_gone(self):
        for path in ("/api/v1/courses/", "/api/v1/lesson-progress/"):
            self.assertEqual(self.client.get(path).status_code, 404)
        for path in ("/api/v1/admin/courses/", "/api/v1/admin/quizzes/"):
            self.assertEqual(self.client.get(path).status_code, 404)
