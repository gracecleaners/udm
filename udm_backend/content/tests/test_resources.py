"""The home "Find resources on" list and the guided pages it opens.

A resource guide is a question a student actually asks — *Receive Christ*,
*Prayer* — answered in ordered steps. The two rules these tests hold: nothing
renders that cannot be read, and a step number is unique only inside its own
guide.
"""

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.utils import timezone
from core.testing import UdmAPITestCase

from content.models import ResourceStep, ResourceTopic, UserContentProgress


def make_topic(title="Receive Christ", **overrides):
    fields = dict(title=title, summary="A guide in five steps.", order=1, is_published=True)
    fields.update(overrides)
    return ResourceTopic.objects.create(**fields)


def make_step(topic, order, title, **overrides):
    fields = dict(
        topic=topic,
        order=order,
        title=title,
        scripture_reference="John 3:16",
        body="For God so loved the world.",
        is_published=True,
    )
    fields.update(overrides)
    return ResourceStep.objects.create(**fields)


class ResourceApiTests(UdmAPITestCase):
    def setUp(self):
        self.receive = make_topic("Receive Christ", order=2)
        self.prayer = make_topic("Prayer", order=1)
        make_step(self.prayer, 1, "Being heard")
        make_step(self.receive, 2, "We have all turned aside")
        make_step(self.receive, 1, "God is near")
        make_step(self.receive, None, "Before you begin")
        self.empty = make_topic("Written next term", order=3)

    def test_list_orders_by_the_authored_position_and_hides_an_empty_guide(self):
        rows = self.client.get("/api/v1/resources/").json()["results"]
        self.assertEqual([row["title"] for row in rows], ["Prayer", "Receive Christ"])

    def test_the_count_a_row_promises_is_the_count_the_page_shows(self):
        row = next(r for r in self.client.get("/api/v1/resources/").json()["results"] if r["title"] == "Receive Christ")
        self.assertEqual(row["step_count"], 3)
        self.assertEqual(len(self.client.get(f"/api/v1/resources/{self.receive.id}/").json()["steps"]), 3)

    def test_a_guide_whose_only_step_is_draft_is_not_in_the_list(self):
        make_topic("Almost", order=4)
        make_step(ResourceTopic.objects.get(title="Almost"), 1, "Draft opening", is_published=False)
        titles = [r["title"] for r in self.client.get("/api/v1/resources/").json()["results"]]
        self.assertNotIn("Almost", titles)

    def test_detail_puts_the_unnumbered_starting_point_first(self):
        payload = self.client.get(f"/api/v1/resources/{self.receive.id}/").json()
        self.assertEqual([s["order"] for s in payload["steps"]], [None, 1, 2])
        self.assertEqual(payload["steps"][0]["title"], "Before you begin")
        self.assertNotIn("body", payload["steps"][0])

    def test_detail_hides_draft_and_future_steps(self):
        make_step(self.receive, 3, "Not ready", is_published=False)
        make_step(self.receive, 4, "Tomorrow", publish_at=timezone.now() + timedelta(hours=5))
        orders = [s["order"] for s in self.client.get(f"/api/v1/resources/{self.receive.id}/").json()["steps"]]
        self.assertEqual(orders, [None, 1, 2])

    def test_a_draft_guide_has_no_detail_page(self):
        draft = make_topic("In production", is_published=False)
        self.assertEqual(self.client.get(f"/api/v1/resources/{draft.id}/").status_code, 404)

    def test_the_step_page_carries_the_video_only_when_the_ministry_curated_one(self):
        silent = self.client.get(f"/api/v1/resources/steps/{make_step(self.receive, 5, 'Silent step').id}/").json()
        self.assertEqual(silent["video_url"], "")
        watched = self.client.get(
            f"/api/v1/resources/steps/{make_step(self.receive, 6, 'With a talk', video_url='https://example.org/talk').id}/"
        ).json()
        self.assertEqual(watched["video_url"], "https://example.org/talk")

    def test_the_step_page_says_where_the_step_sits(self):
        step = self.client.get(f"/api/v1/resources/steps/{make_step(self.receive, 7, 'Calling on him').id}/").json()
        self.assertEqual(step["topic"]["title"], "Receive Christ")
        self.assertEqual(step["topic"]["step_count"], 4)

    def test_the_home_payload_hands_the_list_to_the_app_in_one_request(self):
        rows = self.client.get("/api/v1/home/").json()["resources"]
        self.assertEqual([row["title"] for row in rows], ["Prayer", "Receive Christ"])
        self.assertIsNotNone(rows[0]["content_version"])

    def test_a_student_can_mark_a_step_read(self):
        student = get_user_model().objects.create_user(email="learner@udm.ac.ke", password="long-enough-pass")
        self.client.force_authenticate(user=student)
        step = make_step(self.receive, 8, "Grace means you cannot earn it")
        response = self.client.post(
            "/api/v1/progress/", {"kind": "resource_step", "content_id": str(step.id)}, format="json"
        )
        self.assertEqual(response.status_code, 201, response.json())
        self.assertTrue(UserContentProgress.objects.filter(user=student, kind="resource_step").exists())

    def test_the_step_number_is_unique_within_a_guide_only(self):
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                make_step(self.receive, 1, "Clash")
        make_step(make_topic("Salt and Light", order=4), 1, "Day 1: Salt")


class ResourceCurationTests(UdmAPITestCase):
    def setUp(self):
        self.User = get_user_model()
        self.staff = self.User.objects.create_user(
            email="worker@udm.ac.ke", password="long-enough-pass", is_staff=True
        )
        self.client.force_authenticate(user=self.staff)

    def test_staff_author_a_guide_and_its_steps(self):
        created = self.client.post(
            "/api/v1/admin/resource-topics/",
            {"title": "New Believer", "summary": "The first months.", "order": 2, "is_published": True},
            format="json",
        )
        self.assertEqual(created.status_code, 201, created.json())
        topic = created.json()["id"]

        step = self.client.post(
            "/api/v1/admin/resource-steps/",
            {
                "topic": topic,
                "title": "You can know that you are saved",
                "order": 1,
                "scripture_reference": "1 John 5:13",
                "body": "These things have I written unto you.",
                "is_published": True,
            },
            format="json",
        )
        self.assertEqual(step.status_code, 201, step.json())
        self.assertEqual(step.json()["topic_title"], "New Believer")

        listed = self.client.get("/api/v1/admin/resource-steps/", {"topic": topic}).json()["results"]
        self.assertEqual([row["topic_title"] for row in listed], ["New Believer"])
        self.assertEqual(
            self.client.get(f"/api/v1/admin/resource-topics/{topic}/").json()["step_count"], 1
        )

    def test_a_duplicate_step_number_in_the_same_guide_is_refused(self):
        topic = self.client.post("/api/v1/admin/resource-topics/", {"title": "Faith"}, format="json").json()
        first = {
            "topic": topic["id"],
            "title": "What faith is",
            "order": 1,
            "scripture_reference": "Hebrews 11:1",
            "body": "Faith is the substance of things hoped for.",
        }
        self.assertEqual(self.client.post("/api/v1/admin/resource-steps/", first, format="json").status_code, 201)
        clash = self.client.post(
            "/api/v1/admin/resource-steps/", {**first, "title": "The same number twice"}, format="json"
        )
        self.assertEqual(clash.status_code, 400, clash.json())
        self.assertEqual(ResourceStep.objects.filter(topic_id=topic["id"], order=1).count(), 1)

    def test_two_unnumbered_steps_in_one_guide_are_allowed(self):
        # The model constraint only compares numbered rows, and DRF must not
        # turn that into a requirement to number every step.
        topic = self.client.post("/api/v1/admin/resource-topics/", {"title": "Prayer"}, format="json").json()
        for title in ("A starting point", "Another opening"):
            response = self.client.post(
                "/api/v1/admin/resource-steps/",
                {"topic": topic["id"], "title": title, "scripture_reference": "Psalm 65:2", "body": "O thou that hearest prayer."},
                format="json",
            )
            self.assertEqual(response.status_code, 201, response.json())
        self.assertEqual(ResourceStep.objects.filter(topic_id=topic["id"], order__isnull=True).count(), 2)

    def test_an_insecure_video_link_is_refused_where_it_is_written(self):
        topic = self.client.post("/api/v1/admin/resource-topics/", {"title": "The Bible"}, format="json").json()
        refused = self.client.post(
            "/api/v1/admin/resource-steps/",
            {
                "topic": topic["id"],
                "title": "Where these books came from",
                "scripture_reference": "2 Timothy 3:16",
                "body": "All scripture is given by inspiration of God.",
                "video_url": "http://example.org/talk",
            },
            format="json",
        )
        self.assertEqual(refused.status_code, 400, refused.json())
        self.assertIn("video_url", refused.json()["errors"])

    def test_saving_a_guide_moves_the_stamp_the_app_polls(self):
        before = self.client.get("/api/v1/content-version/").json()["version"]
        created = self.client.post("/api/v1/admin/resource-topics/", {"title": "Church"}, format="json")
        self.assertEqual(created.status_code, 201, created.json())
        self.assertGreater(self.client.get("/api/v1/content-version/").json()["version"], before)
