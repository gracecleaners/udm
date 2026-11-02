"""Shared settings for every UDM environment.

Environment-specific values come from the process environment, loaded from the
repository-root `.env` file when present. See `.env.example`.
"""

import os
from datetime import timedelta
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured
from dotenv import load_dotenv

PACKAGE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = PACKAGE_DIR.parent
BACKEND_DIR = PROJECT_DIR.parent
REPO_DIR = BACKEND_DIR.parent

load_dotenv(REPO_DIR / ".env")


def env(name, default=None):
    value = os.environ.get(name, default)
    return value if value not in (None, "") else default


def env_bool(name, default=False):
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in ("1", "true", "yes", "on")


def env_list(name, default=""):
    return [item.strip() for item in env(name, default).split(",") if item.strip()]


def env_int(name, default):
    raw = env(name)
    if raw is None:
        return default
    try:
        return int(raw)
    except ValueError:
        raise ImproperlyConfigured(f"{name} must be an integer, got {raw!r}.")


def env_minutes(name, default):
    return timedelta(minutes=env_int(name, default))


def env_days(name, default):
    return timedelta(days=env_int(name, default))


def require_env(name):
    value = env(name)
    if not value:
        raise ImproperlyConfigured(f"{name} must be set outside development.")
    return value


# Core ---------------------------------------------------------------------

SECRET_KEY = env("UDM_SECRET_KEY")

DEBUG = False
ALLOWED_HOSTS = env_list("UDM_ALLOWED_HOSTS", "localhost,127.0.0.1")

ROOT_URLCONF = "udm_backend.urls"
WSGI_APPLICATION = "udm_backend.wsgi.application"
ASGI_APPLICATION = "udm_backend.asgi.application"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "corsheaders",
    "drf_spectacular",
    "accounts",
    "content",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [PROJECT_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# Database: PostgreSQL only ------------------------------------------------

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": env("UDM_DB_NAME", "udm"),
        "USER": env("UDM_DB_USER", "udm"),
        "PASSWORD": env("UDM_DB_PASSWORD", ""),
        "HOST": env("UDM_DB_HOST", "127.0.0.1"),
        "PORT": env("UDM_DB_PORT", "5432"),
        "CONN_MAX_AGE": env_int("UDM_DB_CONN_MAX_AGE", 60),
        "CONN_HEALTH_CHECKS": True,
    }
}

# Auth ---------------------------------------------------------------------

AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 10}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# API ----------------------------------------------------------------------

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    # Fail closed: public endpoints opt in explicitly with AllowAny.
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": [
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ],
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "core.errors.udm_exception_handler",
    "DEFAULT_THROTTLE_CLASSES": ["rest_framework.throttling.ScopedRateThrottle"],
    "DEFAULT_THROTTLE_RATES": {
        "content": env("UDM_THROTTLE_CONTENT", "120/min"),
        "auth": env("UDM_THROTTLE_AUTH", "10/min"),
    },
    "COERCE_DECIMAL_TO_STRING": False,
}

SPECTACULAR_SETTINGS = {
    "TITLE": "UDM API",
    "DESCRIPTION": "University Discipleship Mission content, discipleship and campus ministry API.",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "COMPONENT_SPLIT_REQUEST": True,
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": env_minutes("UDM_JWT_ACCESS_MINUTES", 30),
    "REFRESH_TOKEN_LIFETIME": env_days("UDM_JWT_REFRESH_DAYS", 14),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "ALGORITHM": "HS256",
    "SIGNING_KEY": SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",
    "TOKEN_OBTAIN_SERIALIZER": "accounts.serializers.UdmTokenObtainPairSerializer",
}

CORS_ALLOWED_ORIGINS = env_list("UDM_CORS_ALLOWED_ORIGINS")
CORS_ALLOW_CREDENTIALS = False

# i18n, static, media ------------------------------------------------------

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BACKEND_DIR / "staticfiles"

MEDIA_URL = "media/"
MEDIA_ROOT = Path(env("UDM_MEDIA_ROOT", str(BACKEND_DIR / "media")))

# Content rules ------------------------------------------------------------

# Featured verses may only come from public-domain or licensed translations.
UDM_FEATURED_VERSE_TRANSLATIONS = env_list("UDM_FEATURED_VERSE_TRANSLATIONS", "kjv,web,asv")

# Logging ------------------------------------------------------------------

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {"udm": {"format": "[{asctime}] {levelname} {name}: {message}", "style": "{"}},
    "handlers": {"console": {"class": "logging.StreamHandler", "formatter": "udm"}},
    "root": {"handlers": ["console"], "level": env("UDM_LOG_LEVEL", "INFO")},
    "loggers": {
        "django.request": {"handlers": ["console"], "level": "WARNING", "propagate": False},
        "udm": {"handlers": ["console"], "level": env("UDM_LOG_LEVEL", "INFO"), "propagate": False},
    },
}
