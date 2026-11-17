"""A reading day, followed from the console write to the payload the phone draws.

The ministry writes a day in four sections and marks one plan as the daily one,
so these tests hold exactly that: what staff type reaches the student, what a
section left blank means, and which plan the daily flag picks.
"""

from core.testing import UdmAPITestCase

from accounts.models import User
from content.models import BibleReadingAssignment, BibleReadingPlan, BibleReadingProgress

PLANS = "/api/v1/admin/reading-plans/"
HOME = "/api/v1/home/"


class ReadingSectionsFromTheConsoleTests(UdmAPITestCase):
    def setUp(self):
        self.staff = User.objects.create_user(
            email="worker@udm.ac.ug", password="long-enough-pass", is_staff=True
        )
        self.student = User.objects.create_user(email="learner@udm.ac.ug", password="long-enough-pass")

    def create_plan(self, title="Romans in a month", **fields):
        self.client.force_authenticate(user=self.staff)
        body = {"title": title, "description": "Thirty days in the letter.", "is_published": True, "is_daily": True}
        body.update(fields)
        response = self.client.post(PLANS, body, format="json")
        self.assertEqual(response.status_code, 201, response.json())
        return response.json()["id"]

    def create_day(self, plan_id, **fields):
        body = {"day": 1, "reference": "Romans 1:16-17"}
        body.update(fields)
        response = self.client.post(f"{PLANS}{plan_id}/assignments/", body, format="json")
        self.assertEqual(response.status_code, 201, response.json())
        return response.json()["id"]

    def reading(self, user=None):
        self.client.force_authenticate(user=user or self.student)
        payload = self.client.get(HOME).json()
        self.assertEqual(payload["reading"] is None, False, payload.get("reading"))
        return payload["reading"]

    def test_a_day_written_in_sections_comes_back_in_sections(self):
        plan_id = self.create_plan()
        self.create_day(
            plan_id,
            title="Not ashamed",
            verse_reference="Romans 1:17",
            verse_text="The righteous shall live by faith.",
            what_it_says="Paul names the theme of the whole letter before he argues it.",
            what_to_learn="Faith is God's righteousness reaching the reader, not the reader's reaching God.",
        )

        reading = self.reading()

        self.assertEqual(reading["plan_title"], "Romans in a month")
        self.assertEqual(reading["total"], 1)
        self.assertEqual(reading["completed"], 0)
        day = reading["assignment"]
        self.assertEqual(day["title"], "Not ashamed")
        self.assertEqual(day["reference"], "Romans 1:16-17")
        self.assertEqual(day["verse_reference"], "Romans 1:17")
        self.assertEqual(day["verse_text"], "The righteous shall live by faith.")
        self.assertEqual(day["what_it_says"], "Paul names the theme of the whole letter before he argues it.")
        self.assertEqual(
            day["what_to_learn"], "Faith is God's righteousness reaching the reader, not the reader's reaching God."
        )
        self.assertEqual(day["completed"], False)

    def test_a_section_left_blank_is_blank_on_the_phone(self):
        # The app draws a section only when the ministry wrote one, so the API
        # must not answer with invented wording or with a null the client reads
        # as missing data.
        plan_id = self.create_plan(title="Psalms alongside")
        self.create_day(plan_id, reference="Psalm 1")

        day = self.reading()["assignment"]

        self.assertEqual(day["title"], "")
        self.assertEqual(day["verse_reference"], "")
        self.assertEqual(day["verse_text"], "")
        self.assertEqual(day["what_it_says"], "")
        self.assertEqual(day["what_to_learn"], "")

    def test_an_edit_to_one_section_reaches_the_next_read(self):
        plan_id = self.create_plan()
        day_id = self.create_day(plan_id, what_it_says="An early draft of the note.")

        self.client.force_authenticate(user=self.staff)
        edited = self.client.patch(
            f"{PLANS}{plan_id}/assignments/{day_id}/",
            {"what_it_says": "Paul stands in awe, not in argument."},
            format="json",
        )
        self.assertEqual(edited.status_code, 200, edited.json())

        self.assertEqual(self.reading()["assignment"]["what_it_says"], "Paul stands in awe, not in argument.")

    def test_the_daily_flag_decides_which_plan_the_app_shows(self):
        romans = self.create_plan(title="Romans in a month")
        self.create_day(romans, reference="Romans 1:16-17")

        psalms_id = self.create_plan(title="A Psalm a day", is_daily=False)
        self.create_day(psalms_id, reference="Psalm 23")

        self.assertEqual(self.reading()["plan_title"], "Romans in a month")

        self.client.force_authenticate(user=self.staff)
        self.client.patch(PLANS + f"{romans}/", {"is_daily": False}, format="json")
        self.client.patch(PLANS + f"{psalms_id}/", {"is_daily": True}, format="json")

        self.assertEqual(self.reading()["plan_title"], "A Psalm a day")

    def test_no_plan_marked_daily_leaves_the_app_no_reading_at_all(self):
        plan_id = self.create_plan(is_daily=False)
        self.create_day(plan_id)

        self.client.force_authenticate(user=self.student)

        self.assertIsNone(self.client.get(HOME).json()["reading"])

    def test_a_daily_plan_that_is_not_published_is_not_offered(self):
        plan_id = self.create_plan(is_published=False)
        self.create_day(plan_id)

        self.client.force_authenticate(user=self.student)

        self.assertIsNone(self.client.get(HOME).json()["reading"])

    def test_the_progress_line_counts_the_plan_not_the_day(self):
        plan_id = self.create_plan(title="Romans in a month")
        first = self.create_day(plan_id, day=1, reference="Romans 1:16-17")
        self.create_day(plan_id, day=2, reference="Romans 3:21-26")
        self.create_day(plan_id, day=3, reference="Romans 8:1-4")

        self.client.force_authenticate(user=self.student)
        self.assertEqual(
            self.client.post("/api/v1/bible/reading-progress/", {"assignment": first}, format="json").status_code,
            201,
        )

        reading = self.reading()
        self.assertEqual(reading["total"], 3)
        self.assertEqual(reading["completed"], 1)
        self.assertEqual(reading["assignment"]["reference"], "Romans 3:21-26")

    def test_a_day_written_twice_in_one_plan_is_refused_here_too(self):
        plan_id = self.create_plan()
        self.create_day(plan_id, day=4, reference="Romans 4")

        self.client.force_authenticate(user=self.staff)
        duplicate = self.client.post(
            f"{PLANS}{plan_id}/assignments/", {"day": 4, "reference": "Romans 4 again"}, format="json"
        )

        self.assertEqual(duplicate.status_code, 400, duplicate.json())
        self.assertEqual(BibleReadingAssignment.objects.filter(plan_id=plan_id).count(), 1)

    def test_a_student_cannot_write_the_plan(self):
        self.client.force_authenticate(user=self.student)

        self.assertEqual(self.client.post(PLANS, {"title": "My own plan"}, format="json").status_code, 403)

    def test_marking_a_day_stays_the_students_own_record(self):
        plan_id = self.create_plan()
        day_id = self.create_day(plan_id)
        self.client.force_authenticate(user=self.student)
        self.client.post("/api/v1/bible/reading-progress/", {"assignment": day_id}, format="json")

        self.assertEqual(BibleReadingProgress.objects.filter(user=self.student).count(), 1)
        self.assertEqual(BibleReadingProgress.objects.filter(user=self.staff).count(), 0)
        self.assertEqual(BibleReadingAssignment.objects.get(pk=day_id).progress.count(), 1)
