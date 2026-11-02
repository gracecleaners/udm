"""Custom user (email is the login identifier) and the student profile shell.

Defining `AUTH_USER_MODEL` before the first migration is intentional: Django
cannot switch the user model afterwards without rebuilding migration history.
"""

import uuid

from django.contrib.auth.base_user import BaseUserManager, AbstractBaseUser
from django.contrib.auth.models import PermissionsMixin
from django.db import models


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email, password, **extra):
        if not email:
            raise ValueError("An email address is required.")
        user = self.model(email=self.normalize_email(email), **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra):
        extra.setdefault("is_staff", False)
        extra.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra)

    def create_superuser(self, email, password=None, **extra):
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        extra.setdefault("is_email_verified", True)
        if extra.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")
        return self._create_user(email, password, **extra)


class TimestampedModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class User(TimestampedModel, AbstractBaseUser, PermissionsMixin):
    email = models.EmailField("email address", unique=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_email_verified = models.BooleanField(default=False)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.email

    @property
    def display_name(self):
        profile = getattr(self, "profile", None)
        if profile and profile.full_name:
            return profile.full_name
        return self.email.split("@")[0]


class Gender(models.TextChoices):
    MALE = "male", "Male"
    FEMALE = "female", "Female"
    PREFER_NOT = "unspecified", "Prefer not to say"


class UserProfile(TimestampedModel):
    """Onboarding answers captured after registration.

    University and campus are free text until the `campuses` app owns them in
    Phase 5; the values are replaced by foreign keys in that migration.
    """

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")
    full_name = models.CharField(max_length=150, blank=True)
    phone_number = models.CharField(max_length=32, blank=True)
    photo = models.ImageField(upload_to="profiles/", null=True, blank=True)
    gender = models.CharField(max_length=16, choices=Gender.choices, default=Gender.PREFER_NOT)
    country = models.CharField(max_length=80, blank=True)
    city = models.CharField(max_length=80, blank=True)
    university = models.CharField(max_length=200, blank=True)
    campus = models.CharField(max_length=200, blank=True)
    course = models.CharField(max_length=200, blank=True)
    year_of_study = models.PositiveSmallIntegerField(null=True, blank=True)
    church = models.CharField(max_length=200, blank=True)
    interests = models.JSONField(default=list, blank=True)
    preferred_translation_code = models.CharField(max_length=16, default="kjv")

    class Meta:
        constraints = [
            models.CheckConstraint(
                name="profile_year_of_study_positive",
                condition=models.Q(year_of_study__gt=0) | models.Q(year_of_study__isnull=True),
            )
        ]

    def __str__(self):
        return self.full_name or self.user.email
