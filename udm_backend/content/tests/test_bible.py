import json
from pathlib import Path
from unittest.mock import patch

from django.core.management import call_command
from django.core.management.base import CommandError
from core.testing import UdmAPITestCase
from accounts.models import User
from content.models import (BibleBookmark, BibleBook, BibleChapter, BibleNote, BibleReadingAssignment,
                            BibleReadingPlan, BibleReadingProgress, BibleTranslation, BibleVerse)


class BibleApiTests(UdmAPITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="reader@udm.ac.ke", password="long-enough-pass")
        self.other = User.objects.create_user(email="other@udm.ac.ke", password="long-enough-pass")
        translation = BibleTranslation.objects.create(code="kjv", name="King James Version", license_name="Public domain", attribution="KJV")
        book = BibleBook.objects.create(translation=translation, name="Genesis", order=1, testament="old")
        chapter = BibleChapter.objects.create(book=book, number=1)
        self.verse = BibleVerse.objects.create(chapter=chapter, number=1, text="In the beginning...")

    @patch("content.views.available_translations", return_value=[])
    def test_public_reader_only_lists_active_translations_and_licensed_text(self, _translations):
        response = self.client.get("/api/v1/bible/translations/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["results"][0]["code"], "kjv")
        books = self.client.get("/api/v1/bible/kjv/books/")
        self.assertEqual(books.json()["results"][0]["chapter_count"], 1)
        chapter = self.client.get("/api/v1/bible/kjv/Genesis/1/")
        self.assertEqual(chapter.status_code, 200)
        self.assertEqual(chapter.json()["verses"][0]["text"], "In the beginning...")

    @patch("content.views.translation_chapter")
    @patch("content.views.translation_books")
    @patch("content.views.available_translations")
    def test_youversion_translation_is_browsable_and_verse_saves_still_work(
        self, provider_translations, provider_books, provider_chapter
    ):
        metadata = {
            "id": "BSB", "code": "BSB", "name": "Berean Standard Bible",
            "language": "English", "license_name": "Public domain",
            "attribution": "Berean Standard Bible", "source_url": "https://berean.bible/",
            "offline_allowed": False, "source_provider": "youversion",
        }
        books = [{
            "id": "GEN", "provider_id": "GEN", "name": "Genesis",
            "order": 1, "testament": "old", "chapters": [1],
        }]
        provider_translations.return_value = [metadata]
        provider_books.return_value = (metadata, books)
        response = self.client.get("/api/v1/bible/translations/")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(any(row["code"] == "BSB" for row in response.json()["results"]))

        book_response = self.client.get("/api/v1/bible/BSB/books/")
        self.assertEqual(book_response.status_code, 200)
        self.assertEqual(book_response.json()[0]["provider_id"], "GEN", book_response.json())
        chapters_response = self.client.get("/api/v1/bible/BSB/GEN/chapters/")
        self.assertEqual(chapters_response.json(), [1])
        provider_chapter.return_value = {
            "book_id": "genesis", "number": 1,
            "verses": [{"number": 1, "text": "In the beginning God created."}],
        }
        chapter_response = self.client.get("/api/v1/bible/BSB/GEN/1/")
        self.assertEqual(chapter_response.status_code, 200)
        self.assertEqual(chapter_response.json()["verses"][0]["text"], "In the beginning God created.")

        verse_id = chapter_response.json()["verses"][0]["id"]
        self.client.force_authenticate(self.user)
        bookmark = self.client.post("/api/v1/bible/bookmarks/", {"verse_id": verse_id}, format="json")
        note = self.client.post(
            "/api/v1/bible/notes/", {"verse_id": verse_id, "body": "Creation begins here."}, format="json"
        )
        self.assertEqual(bookmark.status_code, 201)
        self.assertEqual(note.status_code, 201)

    def test_bookmarks_and_notes_are_private_and_idempotent(self):
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.post("/api/v1/bible/bookmarks/", {"verse_id": str(self.verse.id)}, format="json").status_code, 201)
        self.client.post("/api/v1/bible/bookmarks/", {"verse_id": str(self.verse.id)}, format="json")
        self.assertEqual(BibleBookmark.objects.filter(user=self.user).count(), 1)
        note_response = self.client.post("/api/v1/bible/notes/", {"verse_id": str(self.verse.id), "body": "personal"}, format="json")
        self.assertEqual(note_response.status_code, 201, note_response.json())
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get("/api/v1/bible/bookmarks/").json()["results"], [])
        self.assertEqual(self.client.get("/api/v1/bible/notes/").json()["results"], [])

    def test_owner_can_edit_and_delete_notes_but_another_student_cannot(self):
        self.client.force_authenticate(self.user)
        created = self.client.post(
            "/api/v1/bible/notes/",
            {"verse_id": str(self.verse.id), "body": "first"},
            format="json",
        )
        note_id = created.json()["id"]
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.patch(f"/api/v1/bible/notes/{note_id}/", {"body": "intrusion"}, format="json").status_code, 404)
        self.assertEqual(self.client.delete(f"/api/v1/bible/notes/{note_id}/").status_code, 404)
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.patch(f"/api/v1/bible/notes/{note_id}/", {"body": "updated"}, format="json").status_code, 200)
        self.assertEqual(self.client.delete(f"/api/v1/bible/notes/{note_id}/").status_code, 204)

    def test_unpublished_plan_assignments_cannot_be_completed(self):
        plan = BibleReadingPlan.objects.create(title="Draft plan", is_published=False)
        assignment = BibleReadingAssignment.objects.create(plan=plan, day=1, reference="Genesis 1")
        self.client.force_authenticate(self.user)
        response = self.client.post(
            "/api/v1/bible/reading-progress/",
            {"assignment": str(assignment.id)},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(BibleReadingProgress.objects.exists())

    def test_plan_progress_is_scoped_to_signed_in_student(self):
        plan = BibleReadingPlan.objects.create(title="Start reading", is_published=True)
        assignment = BibleReadingAssignment.objects.create(plan=plan, day=1, reference="Genesis 1")
        self.client.force_authenticate(self.user)
        self.assertEqual(self.client.post("/api/v1/bible/reading-progress/", {"assignment": str(assignment.id)}, format="json").status_code, 201)
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get("/api/v1/bible/plans/").json()["results"][0]["assignments"][0]["completed"], False)
        self.assertEqual(BibleReadingProgress.objects.filter(user=self.user).count(), 1)


class BibleImportCommandTests(UdmAPITestCase):
    def setUp(self):
        self.payload = {
            "translation": {
                "code": "sample",
                "name": "Sample Translation",
                "license_name": "Public domain sample",
                "attribution": "Sample attribution",
                "offline_allowed": True,
            },
            "books": [
                {
                    "name": "Genesis",
                    "order": 1,
                    "testament": "old",
                    "chapters": [
                        {"number": 1, "verses": [{"number": 1, "text": "Sample verse text."}]}
                    ],
                }
            ],
        }

    def test_import_is_idempotent_and_updates_verse_text(self):
        with patch.object(Path, "read_text", side_effect=lambda **_: json.dumps(self.payload)):
            call_command("import_bible", Path("sample.json"), verbosity=0)
            self.payload["books"][0]["chapters"][0]["verses"][0]["text"] = "Updated sample text."
            call_command("import_bible", Path("sample.json"), verbosity=0)
        self.assertEqual(BibleTranslation.objects.filter(code="sample").count(), 1)
        self.assertEqual(BibleBook.objects.filter(translation__code="sample").count(), 1)
        self.assertEqual(BibleChapter.objects.filter(book__translation__code="sample").count(), 1)
        self.assertEqual(BibleVerse.objects.get(chapter__book__translation__code="sample").text, "Updated sample text.")

    def test_import_requires_license_and_attribution(self):
        self.payload["translation"].pop("attribution")
        with patch.object(Path, "read_text", side_effect=lambda **_: json.dumps(self.payload)):
            with self.assertRaises(CommandError):
                call_command("import_bible", Path("sample.json"), verbosity=0)
        self.assertFalse(BibleTranslation.objects.exists())


class YouVersionProviderParsingTests(UdmAPITestCase):
    @patch("content.youversion.fetch_json")
    def test_chapter_fetches_each_indexed_verse(self, fetch):
        from content.youversion import translation_chapter

        def response(path, **_):
            if path.endswith("/books/GEN"):
                return {"chapters": [{"id": 1, "verses": [
                    {"id": 1, "passage_id": "GEN.1.1"},
                    {"id": 2, "passage_id": "GEN.1.2"},
                ]}]}
            return {
                "GEN.1.1": {"id": "GEN.1.1", "content": "In the beginning."},
                "GEN.1.2": {"id": "GEN.1.2", "content": "The earth was without form."},
            }[path.rsplit("/", 1)[-1]]

        fetch.side_effect = response
        parsed = translation_chapter("3034", "GEN", 1)
        self.assertEqual(parsed["verses"], [
            {"number": 1, "text": "In the beginning."},
            {"number": 2, "text": "The earth was without form."},
        ])

