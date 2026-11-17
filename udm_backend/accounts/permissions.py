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

`CONSOLE_CAPABILITIES` below is what each of those two may actually reach. It
lives here rather than inside the console because the routes enforce the same
list: a page that hides a control the API would still accept is decoration, and
an endpoint open to a role the menu never offers is dead surface.
"""

from rest_framework import permissions

# Read once by `AdminIdentitySerializer`, so the console builds its own
# navigation from what the server already decided rather than a second copy of
# these rules written in TypeScript.
CONSOLE_CAPABILITIES = {
    "staff": ("curation", "directory", "moderation"),
    "superuser": ("curation", "directory", "moderation", "translations", "accounts"),
}


def role_for(user) -> str:
    """The console's role name for a user, or `student` / `guest` outside it."""
    if not (user and user.is_authenticated):
        return "guest"
    if user.is_superuser:
        return "superuser"
    if user.is_staff:
        return "staff"
    return "student"


def capabilities_for(user) -> tuple[str, ...]:
    """What this account may do in the console — empty for anyone outside it."""
    return CONSOLE_CAPABILITIES.get(role_for(user), ())


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
