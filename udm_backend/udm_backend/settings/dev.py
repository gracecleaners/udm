"""Local development settings: debug on, permissive CORS, console email."""

from .base import *  # noqa: F403
from .base import SIMPLE_JWT, env, env_bool, env_list  # noqa: F403

DEBUG = env_bool("UDM_DEBUG", True)

# Development-only fallback so a fresh clone runs before `.env` exists.
# Production refuses to boot without UDM_SECRET_KEY (see prod.py).
SECRET_KEY = env("UDM_SECRET_KEY") or "django-insecure-udm-dev-only-do-not-use-in-production"
SIMPLE_JWT = {**SIMPLE_JWT, "SIGNING_KEY": SECRET_KEY}

ALLOWED_HOSTS = env_list("UDM_ALLOWED_HOSTS", "localhost,127.0.0.1,testserver")

# Flutter web and desktop debug builds run on ad-hoc localhost ports.
CORS_ALLOW_ALL_ORIGINS = env_bool("UDM_CORS_ALLOW_ALL_ORIGINS", True)
CORS_ALLOWED_ORIGINS = env_list("UDM_CORS_ALLOWED_ORIGINS")

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
