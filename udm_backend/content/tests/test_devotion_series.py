"""The Devotions tab: a grid of series, each opening onto its days in order."""

from datetime import timedelta

from django.db import IntegrityError, transaction
from django.utils import timezone
from core.testing import UdmAPITestCase

from content.models import Devotional, DevotionalSeries


def make_series(title="The Book of James", **overrides):
    fields = dict(title=title, description="Seven days in the letter.", order=1, is_published=True)
    fields.update(overrides)
    return DevotionalSeries.objects.create(**fields)


def make_day(series, day, title, **overrides):
    fields = dict(
        series=series,
        day=day,
        title=title,
        scripture_reference="James 1:1",
        body="Text.",
        is_published=True,
    )
    fields.update(overrides)
    return Devotional.objects.create(**fields)


class DevotionalSeriesApiTests(UdmAPITestCase):
    def setUp(self):
        self.james = make_series("The Book of James", order=2)
        self.christmas = make_series("Christmas", order=1)
        make_day(self.christmas, 1, "Day 1: The census")
        make_day(self.james, 2, "Day 2: Taming the tongue")
        make_day(self.james, 1, "Day 1: Trials and patience")
        make_day(self.james, None, "Introduction")
        self.empty = make_series("Advent, not yet written")

    def test_grid_orders_by_the_series_order_field(self):
        titles = [row["title"] for row in self.client.get("/api/v1/devotions/series/").json()["results"]]
        self.assertEqual(titles, ["Christmas", "The Book of James"])

    def test_a_series_without_a_readable_day_is_not_in_the_grid(self):
        # The empty series exists and is published; it just has nothing to open.
        titles = [row["title"] for row in self.client.get("/api/v1/devotions/series/").json()["results"]]
        self.assertNotIn("Advent, not yet written", titles)

    def test_grid_counts_only_days_a_student_can_read(self):
        make_day(self.james, 3, "Not ready yet", is_published=False)
        rows = {r["title"]: r["day_count"] for r in self.client.get("/api/v1/devotions/series/").json()["results"]}
        self.assertEqual(rows["The Book of James"], 3)
        self.assertNotIn("Advent, not yet written", rows)

    def test_a_series_whose_only_day_is_scheduled_stays_hidden(self):
        make_day(self.empty, 1, "Opening day", publish_at=timezone.now() + timedelta(days=1))
        titles = [r["title"] for r in self.client.get("/api/v1/devotions/series/").json()["results"]]
        self.assertNotIn("Advent, not yet written", titles)

    def test_unpublished_series_is_hidden(self):
        make_series("Private plan", is_published=False)
        titles = [row["title"] for row in self.client.get("/api/v1/devotions/series/").json()["results"]]
        self.assertNotIn("Private plan", titles)

    def test_detail_lists_the_introduction_before_the_numbered_days(self):
        payload = self.client.get(f"/api/v1/devotions/series/{self.james.id}/").json()
        self.assertEqual([d["day"] for d in payload["days"]], [None, 1, 2])
        self.assertEqual(payload["days"][0]["title"], "Introduction")
        self.assertNotIn("body", payload["days"][0])

    def test_detail_hides_draft_and_future_days(self):
        make_day(self.james, 3, "Not ready", is_published=False)
        make_day(self.james, 4, "Tomorrow", publish_at=timezone.now() + timedelta(hours=5))
        days = self.client.get(f"/api/v1/devotions/series/{self.james.id}/").json()["days"]
        self.assertEqual([d["day"] for d in days], [None, 1, 2])

    def test_draft_series_detail_is_not_found(self):
        draft = make_series("In production", is_published=False)
        self.assertEqual(self.client.get(f"/api/v1/devotions/series/{draft.id}/").status_code, 404)

    def test_a_series_with_no_readable_day_has_no_detail_rows(self):
        # Nothing links to it, but an old bookmark must not error either.
        payload = self.client.get(f"/api/v1/devotions/series/{self.empty.id}/").json()
        self.assertEqual(payload["days"], [])
        self.assertEqual(payload["day_count"], 0)

    def test_list_devotion_carries_its_series_and_day(self):
        row = next(
            r for r in self.client.get("/api/v1/devotions/", {"search": "Trials"}).json()["results"]
        )
        self.assertEqual(row["series"], str(self.james.id))
        self.assertEqual(row["series_title"], "The Book of James")
        self.assertEqual(row["day"], 1)

    def test_a_standalone_devotion_has_an_empty_series_title(self):
        Devotional.objects.create(
            title="One-off reading", scripture_reference="Psalm 1", body="Text.", is_published=True
        )
        row = next(r for r in self.client.get("/api/v1/devotions/", {"search": "One-off"}).json()["results"])
        self.assertIsNone(row["series"])
        self.assertEqual(row["series_title"], "")

    def test_the_day_number_is_unique_within_a_series_only(self):
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                make_day(self.james, 1, "Clash")
        # The same day number in a second series is the normal case, not a clash.
        make_day(make_series("Salt and Light", order=3), 1, "Day 1: Salt")
