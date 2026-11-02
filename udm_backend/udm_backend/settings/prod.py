"""Production/staging settings. Required values must come from the environment."""

from .base import *  # noqa: F403
from .base import SIMPLE_JWT, env, env_bool, env_int, env_list, require_env  # noqa: F403

DEBUG = False

SECRET_KEY = require_env("UDM_SECRET_KEY")
SIMPLE_JWT = {**SIMPLE_JWT, "SIGNING_KEY": SECRET_KEY}

ALLOWED_HOSTS = env_list("UDM_ALLOWED_HOSTS")
if not ALLOWED_HOSTS:
    raise ImproperlyConfigured("UDM_ALLOWED_HOSTS must list every production hostname.")  # noqa: F405

CSRF_TRUSTED_ORIGINS = env_list("UDM_CSRF_TRUSTED_ORIGINS")

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env_bool("UDM_SECURE_SSL_REDIRECT", True)
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = env_int("UDM_HSTS_SECONDS", 31536000)  # noqa: F405
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"

CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = env_list("UDM_CORS_ALLOWED_ORIGINS")

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = require_env("UDM_EMAIL_HOST")
EMAIL_PORT = env_int("UDM_EMAIL_PORT", 587)  # noqa: F405
EMAIL_USE_TLS = env_bool("UDM_EMAIL_USE_TLS", True)
EMAIL_HOST_USER = env("UDM_EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = env("UDM_EMAIL_HOST_PASSWORD", "")

LOGGING["root"]["level"] = env("UDM_LOG_LEVEL", "INFO")  # noqa: F405
