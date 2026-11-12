"""Import a licensed Bible translation from a reviewed JSON file.

The command does not bundle or fetch Scripture text. The operator must hold
distribution rights and provide attribution and license metadata in the file.
"""

import json
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import IntegrityError, transaction

from content.models import BibleBook, BibleChapter, BibleTranslation, BibleVerse
from content.signals import mark_content_changed


class Command(BaseCommand):
    help = "Import a Bible JSON catalog after confirming its license and attribution."

    def add_arguments(self, parser):
        parser.add_argument("file", type=Path, help="Path to the reviewed translation JSON file")

    def handle(self, *args, **options):
        path = options["file"]
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise CommandError(f"Could not read Bible JSON: {exc}") from exc

        if not isinstance(payload, dict):
            raise CommandError("The file root must be a JSON object.")
        translation_data = payload.get("translation", {})
        if not isinstance(translation_data, dict):
            raise CommandError("The translation entry must be a JSON object.")
        required = ("code", "name", "license_name", "attribution")
        missing = [field for field in required if not str(translation_data.get(field, "")).strip()]
        if missing:
            raise CommandError(f"Translation metadata is missing: {', '.join(missing)}")
        books = payload.get("books")
        if not isinstance(books, list) or not books:
            raise CommandError("The file must contain a non-empty books list.")
        for flag in ("offline_allowed", "is_active"):
            if flag in translation_data and not isinstance(translation_data[flag], bool):
                raise CommandError(f"Translation field {flag} must be true or false.")

        counts = {"books": 0, "chapters": 0, "verses": 0}
        try:
            with transaction.atomic():
                translation, _ = BibleTranslation.objects.update_or_create(
                    code=translation_data["code"],
                    defaults={
                        "name": translation_data["name"],
                        "license_name": translation_data["license_name"],
                        "attribution": translation_data["attribution"],
                        "source_url": translation_data.get("source_url", ""),
                        "offline_allowed": bool(translation_data.get("offline_allowed", False)),
                        "is_active": bool(translation_data.get("is_active", True)),
                        "source_provider": "",
                    },
                )
                for book_data in books:
                    book = self._object(book_data, ("name", "order", "testament"), "book")
                    book_obj, _ = BibleBook.objects.update_or_create(
                        translation=translation,
                        name=book["name"],
                        defaults={"order": book["order"], "testament": book["testament"]},
                    )
                    counts["books"] += 1
                    chapters = book_data.get("chapters")
                    if not isinstance(chapters, list) or not chapters:
                        raise CommandError(f"Book {book['name']} must contain chapters.")
                    for chapter_data in chapters:
                        chapter = self._object(chapter_data, ("number",), "chapter")
                        chapter_obj, _ = BibleChapter.objects.update_or_create(
                            book=book_obj,
                            number=chapter["number"],
                        )
                        counts["chapters"] += 1
                        verses = chapter_data.get("verses")
                        if not isinstance(verses, list) or not verses:
                            raise CommandError(f"{book['name']} {chapter['number']} must contain verses.")
                        verse_rows = []
                        for verse_data in verses:
                            verse = self._object(verse_data, ("number", "text"), "verse")
                            verse_rows.append(
                                BibleVerse(
                                    chapter=chapter_obj,
                                    number=verse["number"],
                                    text=verse["text"],
                                )
                            )
                        BibleVerse.objects.bulk_create(
                            verse_rows,
                            batch_size=1000,
                            update_conflicts=True,
                            update_fields=["text", "updated_at"],
                            unique_fields=["chapter", "number"],
                        )
                        counts["verses"] += len(verse_rows)
        except IntegrityError as exc:
            raise CommandError(f"The import contains duplicate or conflicting canonical ordering: {exc}") from exc
        except (KeyError, TypeError, ValueError) as exc:
            raise CommandError(f"Invalid Bible JSON structure: {exc}") from exc

        # bulk_create fires no post_save, so the app would otherwise keep the
        # version number it had before the translation existed.
        mark_content_changed()

        self.stdout.write(
            self.style.SUCCESS(
                f"Imported {translation.name}: {counts['books']} books, "
                f"{counts['chapters']} chapters, {counts['verses']} verses."
            )
        )

    @staticmethod
    def _object(value, fields, kind):
        if not isinstance(value, dict):
            raise CommandError(f"Each {kind} must be a JSON object.")
        missing = [field for field in fields if field not in value]
        if missing:
            raise CommandError(f"{kind.title()} is missing: {', '.join(missing)}")
        if "text" in fields and not str(value["text"]).strip():
            raise CommandError("Verse text cannot be empty.")
        if "order" in fields:
            if not isinstance(value["order"], int) or isinstance(value["order"], bool) or value["order"] < 1:
                raise CommandError("Book order must be a positive integer.")
            if value.get("testament") not in ("old", "new"):
                raise CommandError("Book testament must be 'old' or 'new'.")
        if "number" in fields and (
            not isinstance(value["number"], int)
            or isinstance(value["number"], bool)
            or value["number"] < 1
        ):
            raise CommandError(f"{kind.title()} number must be a positive integer.")
        return value
