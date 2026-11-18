from django.conf import settings
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import PermissionDenied, ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

# `media_file_url` is this project's one rule for turning an uploaded file into
# an address a device loads; a profile picture is such a file, so the accounts
# app reads it rather than restating the missing-bytes guard beside it.
from content.services import media_file_url
from .models import User, UserProfile
from .permissions import capabilities_for, role_for

# Interests and year bounds are client-visible rules, not decoration: the form
# and the API must reject the same input.
MAX_INTERESTS = 12
MAX_INTEREST_LENGTH = 40


class UserSummarySerializer(serializers.ModelSerializer):
    display_name = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = ("id", "email", "display_name", "is_email_verified")


class UserProfileSerializer(serializers.ModelSerializer):
    # Profile photos are written at registration time. This serializer exposes
    # their served URL but keeps later profile edits from writing arbitrary URLs.
    photo = serializers.SerializerMethodField()

    class Meta:
        model = UserProfile
        fields = (
            "full_name",
            "phone_number",
            "photo",
            "gender",
            "country",
            "city",
            "university",
            "campus",
            "course",
            "year_of_study",
            "church",
            "interests",
            "preferred_translation_code",
        )

    def get_photo(self, profile):
        """The picture as an address the device can load, or None.

        The same rule every other uploaded image in this project follows, in
        `content.services`: `ImageField.url` raises when the row exists but its
        bytes were never written, and the app draws the student's initials for
        that state rather than asking the server to fail.
        """
        return media_file_url(profile.photo, self.context.get("request"))

    def validate_year_of_study(self, value):
        if value is not None and not 1 <= value <= 13:
            raise serializers.ValidationError("Year of study must be between 1 and 13.")
        return value

    def validate_interests(self, value):
        if not isinstance(value, list):
            raise serializers.ValidationError("Interests must be a list.")
        if len(value) > MAX_INTERESTS:
            raise serializers.ValidationError(f"Choose at most {MAX_INTERESTS} interests.")
        cleaned = []
        for item in value:
            if not isinstance(item, str) or not item.strip():
                raise serializers.ValidationError("Each interest must be a non-empty label.")
            label = item.strip()
            if len(label) > MAX_INTEREST_LENGTH:
                raise serializers.ValidationError(f"Interest '{label[:20]}…' is too long.")
            cleaned.append(label)
        return cleaned

    def validate_preferred_translation_code(self, value):
        code = value.strip().lower()
        allowed = settings.UDM_MEMORY_VERSE_TRANSLATIONS
        if code not in allowed:
            raise serializers.ValidationError(f"{code} is not an available translation.")
        return code


class CurrentUserSerializer(UserProfileSerializer):
    email = serializers.EmailField(source="user.email", read_only=True)
    display_name = serializers.CharField(source="user.display_name", read_only=True)
    is_email_verified = serializers.BooleanField(source="user.is_email_verified", read_only=True)

    class Meta(UserProfileSerializer.Meta):
        fields = UserProfileSerializer.Meta.fields + ("email", "display_name", "is_email_verified")


class RegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, style={"input_type": "password"})
    full_name = serializers.CharField(max_length=150)
    photo = serializers.ImageField(required=False, allow_null=True, write_only=True)

    class Meta:
        model = User
        fields = ("email", "password", "full_name", "photo")

    def validate_photo(self, value):
        if value and value.size > 5 * 1024 * 1024:
            raise serializers.ValidationError("Profile pictures must be 5 MB or smaller.")
        return value

    def validate_email(self, value):
        email = value.strip().lower()
        if User.objects.filter(email=email).exists():
            raise serializers.ValidationError(
                "An account already uses this email address. Sign in instead."
            )
        return email

    def validate_password(self, value):
        # AUTH_PASSWORD_VALIDATORS is the single source of strength rules.
        try:
            validate_password(value)
        except DjangoValidationError as error:
            raise serializers.ValidationError(list(error.messages))
        return value

    def create(self, validated_data):
        photo = validated_data.pop("photo", None)
        user = User.objects.create_user(
            email=validated_data["email"], password=validated_data["password"]
        )
        profile = UserProfile.for_user(user)
        profile.full_name = validated_data["full_name"].strip()
        if photo is not None:
            profile.photo = photo
        profile.save(update_fields=["full_name", "photo", "updated_at"])
        return user


class UdmTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Adds the safe identity summary so the client needs no follow-up call."""

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["email"] = user.email
        token["display_name"] = user.display_name
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data["user"] = UserSummarySerializer(self.user).data
        return data


class StaffTokenObtainPairSerializer(UdmTokenObtainPairSerializer):
    """The same credentials check, refused for anyone outside the ministry team.

    Signing in through the console with a student account fails here rather than
    handing out tokens the console could not use, so the two surfaces cannot be
    confused by a wrong password manager entry.
    """

    def validate(self, attrs):
        data = super().validate(attrs)
        if not (self.user.is_staff and self.user.is_active):
            raise PermissionDenied("This console is for ministry staff accounts.")
        return data


class AdminIdentitySerializer(serializers.ModelSerializer):
    """What the signed-in console account may reach, named by the server.

    `role` and `capabilities` come from `accounts.permissions`, which is the
    same table the routes are guarded by, so a page cannot offer a control the
    API would refuse.
    """

    role = serializers.SerializerMethodField()
    capabilities = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ("id", "email", "display_name", "is_staff", "is_superuser", "role", "capabilities")
        read_only_fields = fields

    def get_role(self, obj):
        return role_for(obj)

    def get_capabilities(self, obj):
        return list(capabilities_for(obj))


class StaffAccountSerializer(serializers.ModelSerializer):
    """A console account the platform owner opens for somebody on the team.

    The staff flag is the only role this route can give. `is_superuser` is
    read-only, so no HTTP call — not one made through a hijacked admin session
    either — can mint a second owner or hand out the rights to delete the
    platform; that still takes Django Admin or a terminal.
    """

    password = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
        style={"input_type": "password"},
    )
    display_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    role = serializers.SerializerMethodField()
    capabilities = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            "id", "email", "display_name", "password", "is_staff", "is_active",
            "is_superuser", "role", "capabilities", "created_at", "updated_at",
        )
        # `is_staff` is read although `create` sets it: an edit that could turn
        # the flag off would drop the row from this page's own list, leaving an
        # account that can sign in nowhere and that no console screen can find
        # again to restore it.
        read_only_fields = (
            "id", "is_staff", "is_superuser", "role", "capabilities", "created_at", "updated_at",
        )

    def get_role(self, obj):
        return role_for(obj)

    def get_capabilities(self, obj):
        return list(capabilities_for(obj))

    def validate_email(self, value):
        return value.strip().lower()

    def validate_password(self, value):
        # An empty password on an edit means "keep the one they have", which is
        # how the console's form arrives when a curator is only renaming someone.
        if not value:
            return value
        # The same strength rules a student meets at sign-up, because a staff
        # account that reaches the whole ministry is the more valuable one to
        # guess.
        try:
            validate_password(value)
        except DjangoValidationError as error:
            raise serializers.ValidationError(list(error.messages))
        return value

    def validate(self, attrs):
        if self.instance is None and not attrs.get("password"):
            raise serializers.ValidationError({"password": "A new console account needs a password."})
        return attrs

    def create(self, validated_data):
        full_name = validated_data.pop("display_name", "")
        password = validated_data.pop("password")
        user = User.objects.create_user(
            email=validated_data["email"],
            password=password,
            # This route exists to open staff accounts, so the flag is set
            # here rather than trusted from the request body.
            is_staff=True,
            # The owner typed this address as their own team member's; there is
            # no confirmation link for that person to wait on before signing in.
            is_email_verified=True,
            is_active=validated_data.get("is_active", True),
        )
        _write_display_name(user, full_name)
        return user

    def update(self, instance, validated_data):
        full_name = validated_data.pop("display_name", None)
        password = validated_data.pop("password", "")
        for name, value in validated_data.items():
            setattr(instance, name, value)
        if password:
            instance.set_password(password)
        instance.save()
        if full_name is not None:
            _write_display_name(instance, full_name)
        return instance


def _write_display_name(user, full_name):
    """Put the console's name on the profile the read path already uses.

    `User.display_name` reads `profile.full_name`, so a staff account with no
    profile row would list itself as an email prefix.
    """
    profile = UserProfile.for_user(user)
    profile.full_name = (full_name or "").strip()
    profile.save(update_fields=["full_name", "updated_at"])


class StudentDirectorySerializer(serializers.ModelSerializer):
    """Roster columns for the ministry console.

    Identity, the staff flag and two counts of *public* ministry work only.
    Prayer requests, bookmarks, notes, progress rows and quiz attempts are
    deliberately absent: staff status is not a licence to read a student's
    discipleship record, which is the same reason `UserContentProgress` stays
    out of Django Admin.
    """

    display_name = serializers.CharField(read_only=True)
    photo_url = serializers.SerializerMethodField()
    groups_led = serializers.IntegerField(read_only=True)
    events_organized = serializers.IntegerField(read_only=True)

    class Meta:
        model = User
        fields = (
            "id", "email", "display_name", "photo_url", "is_staff", "is_superuser", "is_active", "created_at",
            "groups_led", "events_organized",
        )
        read_only_fields = fields

    def get_photo_url(self, user):
        """The roster avatar, from the profile the view already joined.

        Served here but not on the community wall unless the student published
        a name: staff are reading an identity list, the wall is not.
        """
        profile = getattr(user, "profile", None)
        return media_file_url(profile.photo, self.context.get("request")) if profile else None
