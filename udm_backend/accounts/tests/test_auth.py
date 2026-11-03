from django.conf import settings
from django.urls import reverse

from accounts.models import User, UserProfile
from core.testing import UdmAPITestCase


def register(client, email="new@udm.ac.ug", password="Pilgrim2026road", full_name="Susan Kato"):
    return client.post(
        reverse("register"),
        {"email": email, "password": password, "full_name": full_name},
        format="json",
    )


class RegistrationTests(UdmAPITestCase):
    def test_registration_creates_account_profile_and_session(self):
        response = register(self.client)
        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertIn("access", body)
        self.assertIn("refresh", body)
        self.assertEqual(body["user"]["email"], "new@udm.ac.ug")

        user = User.objects.get(email="new@udm.ac.ug")
        self.assertEqual(user.profile.full_name, "Susan Kato")
        self.assertFalse(user.is_staff)

    def test_email_is_normalised_and_sign_in_works_afterwards(self):
        register(self.client, email="  New@UDM.ac.ug ")
        response = self.client.post(
            reverse("token_obtain_pair"),
            {"email": "new@udm.ac.ug", "password": "Pilgrim2026road"},
            format="json",
        )
        self.assertEqual(response.status_code, 200)

    def test_duplicate_email_is_rejected_with_the_error_envelope(self):
        register(self.client)
        response = register(self.client)
        self.assertEqual(response.status_code, 400)
        body = response.json()
        self.assertEqual(body["code"], "invalid")
        self.assertEqual(body["status"], 400)
        self.assertIn("email", body["errors"])

    def test_weak_password_is_rejected_by_the_django_validators(self):
        response = register(self.client, password="1234")
        self.assertEqual(response.status_code, 400)
        self.assertIn("password", response.json()["errors"])

    def test_missing_full_name_is_rejected(self):
        response = self.client.post(
            reverse("register"), {"email": "x@udm.ac.ug", "password": "Pilgrim2026road"}, format="json"
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("full_name", response.json()["errors"])

    def test_registration_is_reachable_anonymously(self):
        self.assertEqual(register(self.client).status_code, 201)


class LogoutTests(UdmAPITestCase):
    def setUp(self):
        self.session = register(self.client).json()

    def test_logout_revokes_the_refresh_token(self):
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.session['access']}")
        response = self.client.post(
            reverse("token_logout"), {"refresh": self.session["refresh"]}, format="json"
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            self.client.post(reverse("token_refresh"), {"refresh": self.session["refresh"]}, format="json").status_code,
            401,
        )

    def test_logout_requires_authentication(self):
        self.client.credentials()
        response = self.client.post(
            reverse("token_logout"), {"refresh": self.session["refresh"]}, format="json"
        )
        self.assertEqual(response.status_code, 401)


class CurrentUserTests(UdmAPITestCase):
    def setUp(self):
        self.session = register(self.client).json()
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.session['access']}")

    def test_me_returns_only_my_own_fields(self):
        body = self.client.get(reverse("me")).json()
        self.assertEqual(body["email"], "new@udm.ac.ug")
        self.assertEqual(body["full_name"], "Susan Kato")
        self.assertNotIn("password", body)

    def test_editable_fields_are_persisted(self):
        response = self.client.patch(
            reverse("me"),
            {
                "course": "Medicine",
                "year_of_study": 3,
                "university": "Makerere University",
                "campus": "Main",
                "country": "Uganda",
                "city": "Kampala",
                "gender": "female",
                "interests": ["Bible study", "Missions"],
                "preferred_translation_code": "web",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        profile = UserProfile.objects.get(user__email="new@udm.ac.ug")
        self.assertEqual(profile.course, "Medicine")
        self.assertEqual(profile.year_of_study, 3)
        self.assertEqual(profile.interests, ["Bible study", "Missions"])
        self.assertEqual(profile.preferred_translation_code, "web")

    def test_unlicensed_translation_is_refused(self):
        response = self.client.patch(reverse("me"), {"preferred_translation_code": "niv"}, format="json")
        self.assertEqual(response.status_code, 400)
        self.assertIn("preferred_translation_code", response.json()["errors"])

    def test_out_of_range_year_of_study_is_refused(self):
        self.assertEqual(self.client.patch(reverse("me"), {"year_of_study": 0}, format="json").status_code, 400)
        self.assertEqual(self.client.patch(reverse("me"), {"year_of_study": 40}, format="json").status_code, 400)

    def test_blank_interest_labels_are_refused(self):
        response = self.client.patch(reverse("me"), {"interests": ["  "]}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_photo_is_not_writable_through_json(self):
        response = self.client.patch(reverse("me"), {"photo": "http://evil.example/x.png"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(UserProfile.objects.get(user__email="new@udm.ac.ug").photo.name, "")

    def test_another_account_cannot_reach_my_profile(self):
        other = User.objects.create_user(email="other@udm.ac.ug", password="Pilgrim2026road")
        self.client.force_authenticate(user=other)
        self.assertEqual(self.client.get(reverse("me")).json()["email"], "other@udm.ac.ug")
        # Only /users/me/ exists; profiles are not addressable by primary key.
        self.assertEqual(self.client.get(f"/api/v1/users/{other.id}/").status_code, 404)


class ThrottleTests(UdmAPITestCase):
    """The configured auth limit is real, and a refusal uses the same envelope
    as every other error. DRF binds throttle rates at import time, so the test
    exercises the deployed limit instead of overriding it."""

    def test_a_burst_of_registration_attempts_is_refused(self):
        limit = int(settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]["auth"].split("/")[0])
        for index in range(limit):
            self.assertEqual(register(self.client, email=f"burst{index}@udm.ac.ug").status_code, 201)

        response = register(self.client, email=f"burst{limit}@udm.ac.ug")
        self.assertEqual(response.status_code, 429)
        body = response.json()
        self.assertEqual(body["code"], "throttled")
        self.assertEqual(body["status"], 429)
        self.assertIn("Expected available", body["detail"])
