from django.conf import settings
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import User, UserProfile

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
    # Uploads arrive with the media-library work; accepting them here without
    # size and content validation would be a fake implementation.
    photo = serializers.ImageField(read_only=True)

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
        allowed = settings.UDM_FEATURED_VERSE_TRANSLATIONS
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

    class Meta:
        model = User
        fields = ("email", "password", "full_name")

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
        user = User.objects.create_user(
            email=validated_data["email"], password=validated_data["password"]
        )
        profile = UserProfile.for_user(user)
        profile.full_name = validated_data["full_name"].strip()
        profile.save(update_fields=["full_name", "updated_at"])
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
