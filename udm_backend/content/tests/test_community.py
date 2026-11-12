from datetime import timedelta

from django.utils import timezone

from accounts.models import User
from content.models import (
    Campus,
    DiscipleshipGroup,
    Event,
    EventRegistration,
    GroupMembership,
    PrayerRequest,
    University,
)
from core.testing import UdmAPITestCase


class CommunityApiTests(UdmAPITestCase):
    def setUp(self):
        self.student = User.objects.create_user(email="student@udm.ac.ke", password="long-enough-pass")
        self.other = User.objects.create_user(email="other@udm.ac.ke", password="long-enough-pass")
        self.leader = User.objects.create_user(email="leader@udm.ac.ke", password="long-enough-pass")
        self.staff = User.objects.create_user(email="staff@udm.ac.ke", password="long-enough-pass", is_staff=True)
        self.university = University.objects.create(name="Example University", country="Kenya", city="Nairobi")
        self.campus = Campus.objects.create(university=self.university, name="Main Campus", location="Town")
        self.group = DiscipleshipGroup.objects.create(
            campus=self.campus,
            name="Tuesday Study",
            description="Weekly discipleship",
            leader=self.leader,
        )

    def test_directory_and_private_group_visibility(self):
        private = DiscipleshipGroup.objects.create(name="Private group", visibility="private")
        self.assertEqual(self.client.get("/api/v1/universities/").json()["results"][0]["name"], "Example University")
        visible = self.client.get("/api/v1/groups/").json()["results"]
        self.assertEqual({row["name"] for row in visible}, {"Tuesday Study"})
        self.client.force_authenticate(self.student)
        self.client.post(f"/api/v1/groups/{private.id}/join/")
        visible = self.client.get("/api/v1/groups/").json()["results"]
        self.assertIn("Private group", {row["name"] for row in visible})

    def test_membership_is_idempotent_and_only_the_group_leader_decides(self):
        self.client.force_authenticate(self.student)
        join_url = f"/api/v1/groups/{self.group.id}/join/"
        self.assertEqual(self.client.post(join_url).status_code, 201)
        self.client.post(join_url)
        self.assertEqual(GroupMembership.objects.filter(user=self.student, group=self.group).count(), 1)
        membership = GroupMembership.objects.get(user=self.student, group=self.group)
        decision_url = f"/api/v1/groups/{self.group.id}/memberships/{membership.id}/"
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.patch(decision_url, {"status": "approved"}, format="json").status_code, 403)
        self.client.force_authenticate(self.leader)
        self.assertEqual(self.client.patch(decision_url, {"status": "approved"}, format="json").status_code, 200)
        self.assertEqual(self.client.get("/api/v1/groups/memberships/").json()["results"], [])
        self.client.force_authenticate(self.student)
        self.assertEqual(self.client.get("/api/v1/groups/memberships/").json()["results"][0]["status"], "approved")

    def test_group_capacity_is_checked_when_leader_approves(self):
        self.group.capacity = 1
        self.group.save(update_fields=["capacity"])
        GroupMembership.objects.create(user=self.other, group=self.group, status=GroupMembership.Status.APPROVED)
        membership = GroupMembership.objects.create(user=self.student, group=self.group)
        self.client.force_authenticate(self.leader)
        response = self.client.patch(
            f"/api/v1/groups/{self.group.id}/memberships/{membership.id}/",
            {"status": "approved"},
            format="json",
        )
        self.assertEqual(response.status_code, 409)
        membership.refresh_from_db()
        self.assertEqual(membership.status, GroupMembership.Status.REQUESTED)

    def test_event_registration_is_idempotent_and_capacity_is_enforced(self):
        event = Event.objects.create(
            campus=self.campus,
            title="Campus gathering",
            starts_at=timezone.now() + timedelta(days=1),
            capacity=1,
            online_url="https://meet.example.org/campus-gathering",
            status=Event.Status.PUBLISHED,
        )
        register_url = f"/api/v1/events/{event.id}/register/"
        event_url = f"/api/v1/events/"
        anonymous_event = next(item for item in self.client.get(event_url).data["results"] if item["id"] == str(event.id))
        self.assertEqual(anonymous_event["online_url"], "")
        self.client.force_authenticate(self.student)
        self.assertEqual(self.client.post(register_url).status_code, 201)
        self.assertEqual(self.client.post(register_url).status_code, 200)
        registered_event = next(item for item in self.client.get(event_url).data["results"] if item["id"] == str(event.id))
        self.assertEqual(registered_event["online_url"], "https://meet.example.org/campus-gathering")
        self.client.force_authenticate(self.other)
        unregistered_event = next(item for item in self.client.get(event_url).data["results"] if item["id"] == str(event.id))
        self.assertEqual(unregistered_event["online_url"], "")
        self.assertEqual(self.client.post(register_url).status_code, 409)
        self.assertEqual(EventRegistration.objects.filter(event=event).count(), 1)

    def test_private_prayer_is_owner_only_and_shared_prayer_requires_consent_and_review(self):
        self.client.force_authenticate(self.student)
        private = self.client.post("/api/v1/prayers/", {"body": "Keep this private."}, format="json")
        self.assertEqual(private.status_code, 201)
        denied = self.client.post(
            "/api/v1/prayers/",
            {"body": "Share me", "visibility": "public", "share_consent": False},
            format="json",
        )
        self.assertEqual(denied.status_code, 400)
        shared = self.client.post(
            "/api/v1/prayers/",
            {"body": "Please pray for exams.", "visibility": "public", "share_consent": True},
            format="json",
        )
        self.assertEqual(shared.status_code, 201)
        self.assertEqual(shared.json()["moderation_state"], "pending")
        self.assertEqual(len(self.client.get("/api/v1/prayers/").json()["results"]), 2)
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get("/api/v1/prayers/").json()["results"], [])
        self.client.force_authenticate(self.staff)
        queue = self.client.get("/api/v1/prayers/moderation/").json()
        self.assertEqual(len(queue), 1)
        self.assertEqual(queue[0]["body"], "Please pray for exams.")
        approved = self.client.patch(
            f"/api/v1/prayers/moderation/{shared.json()['id']}/",
            {"moderation_state": "approved"},
            format="json",
        )
        self.assertEqual(approved.status_code, 200)
        self.client.force_authenticate(self.other)
        public = self.client.get("/api/v1/prayers/").json()["results"]
        self.assertEqual([row["body"] for row in public], ["Please pray for exams."])

    def test_group_prayer_is_private_to_members_and_leader_moderates_with_consent(self):
        GroupMembership.objects.create(user=self.student, group=self.group, status=GroupMembership.Status.APPROVED)
        self.client.force_authenticate(self.student)
        response = self.client.post(
            "/api/v1/prayers/",
            {"body": "Pray for my family.", "visibility": "group", "group": str(self.group.id), "share_consent": True},
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        prayer_id = response.json()["id"]
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get("/api/v1/prayers/").json()["results"], [])
        self.client.force_authenticate(self.leader)
        queue_url = f"/api/v1/groups/{self.group.id}/prayer/"
        self.assertEqual(len(self.client.get(queue_url).json()), 1)
        self.assertEqual(
            self.client.patch(f"{queue_url}{prayer_id}/", {"moderation_state": "approved"}, format="json").status_code,
            200,
        )
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get("/api/v1/prayers/").json()["results"], [])
        self.client.force_authenticate(self.student)
        self.assertEqual(self.client.get("/api/v1/prayers/").json()["results"][0]["body"], "Pray for my family.")
