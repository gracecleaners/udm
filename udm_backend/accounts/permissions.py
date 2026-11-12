"""Who the console lets do what.

Two kinds of account sign in to the ministry console, and the difference is
irreversibility:

* **Ministry staff** (`is_staff`) are employed to add and edit content and to
  watch the system. Everything they do here can be undone by editing it again.
* **Platform admins** (`is_superuser`) own the platform. They delete student
  accounts and assert the right to publish a Bible translation — the two acts
  this deployment cannot take back.

`is_staff` is Django's own console flag and `is_superuser` its own owner flag,
so no parallel role field can drift out of sync with the Django Admin site that
reads the same two columns.
"""

from rest_framework import permissions


class IsMinistryStaff(permissions.BasePermission):
    """Any console account: ministry staff and platform admins alike."""

    message = "Ministry staff or platform admin access is required."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.is_staff)


class IsPlatformAdmin(permissions.BasePermission):
    """Superusers only, for what cannot be undone."""

    message = "Platform admin access is required."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.is_superuser)


class StaffReadAndAdminWrite(permissions.BasePermission):
    """Staff may look, only an admin may change.

    Used where the reading is monitoring — which is staff's job — and the
    writing is a legal or irreversible act: Bible licensing metadata, and the
    student roster's destructive end.
    """

    message = "Platform admin access is required to change this."

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_authenticated and user.is_staff):
            return False
        return request.method in permissions.SAFE_METHODS or user.is_superuser
