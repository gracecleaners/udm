"""Single error envelope for every API response.

Clients may rely on `detail`, `code`, `status` and `errors` instead of parsing
DRF's varied default shapes.
"""

from django.core.exceptions import PermissionDenied
from django.http import Http404
from rest_framework.settings import api_settings
from rest_framework.views import exception_handler

GENERIC_INVALID = "The submitted data is not valid."

# DRF re-raises some Django exceptions after this module has the original one,
# so the status code is the reliable last resort for naming a failure.
CODE_BY_STATUS = {
    400: "invalid",
    401: "not_authenticated",
    403: "permission_denied",
    404: "not_found",
    405: "method_not_allowed",
    409: "conflict",
    429: "throttled",
}


def udm_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is None or response.data is None:
        return response

    detail, errors = _split(response.data)
    response.data = {
        "detail": detail,
        "code": _code_for(exc, response),
        "status": response.status_code,
        "errors": errors,
    }
    return response


def _code_for(exc, response):
    code = getattr(exc, "default_code", None)
    if code:
        return code
    if isinstance(exc, Http404):
        return "not_found"
    if isinstance(exc, PermissionDenied):
        return "permission_denied"
    return CODE_BY_STATUS.get(response.status_code, "error")


def _split(data):
    detail_keys = (api_settings.NON_FIELD_ERRORS_KEY, "detail")

    if isinstance(data, dict):
        errors = {key: value for key, value in data.items() if key not in detail_keys}
        for key in detail_keys:
            value = data.get(key)
            if isinstance(value, str):
                return value, errors
            if value is not None:
                return _first(value), errors
        return (GENERIC_INVALID if errors else "Unexpected error."), errors

    if isinstance(data, list):
        return _first(data), {}

    return str(data), {}


def _first(value):
    if isinstance(value, list) and value:
        return str(value[0])
    return str(value)
