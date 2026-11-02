from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import User, UserProfile


class UserSummarySerializer(serializers.ModelSerializer):
    display_name = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = ("id", "email", "display_name", "is_email_verified")


class UserProfileSerializer(serializers.ModelSerializer):
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
