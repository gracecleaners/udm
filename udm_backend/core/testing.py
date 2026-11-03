"""Shared helpers for the API test suite."""

from django.core.cache import cache
from rest_framework.test import APITestCase


class UdmAPITestCase(APITestCase):
    """Base case for API tests.

    Rate-limit history lives in the cache and the test process shares one cache,
    so a suite of login and registration requests trips the auth throttle long
    before the tenth test runs. The reset happens in `_pre_setup` rather than
    `setUp` because test classes that override `setUp` for their own fixtures do
    not always chain to the parent, and a skipped `super()` must not silently
    re-enable the limit.
    """

    def _pre_setup(self):
        super()._pre_setup()
        cache.clear()
