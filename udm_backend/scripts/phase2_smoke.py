"""End-to-end check of the Phase 2 client contracts against a running API.

Walks the same order `AuthRepository` and `UdmApi` use, so a field name, a
rotation or an idempotency rule that the client would trip over shows up here
before it reaches a device. Run the dev server first, then:

    ../venv/Scripts/python.exe scripts/phase2_smoke.py

It registers a throwaway account per run, so it needs a development database.
"""

import json
import time
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:8000/api/v1"
EMAIL = f"smoke.{int(time.time())}@udm.test"
PASSWORD = "Pilgrim2026road"


def call(method, path, body=None, token=None):
    """Returns (status, parsed payload) for any HTTP answer, including errors."""
    request = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={
            "Content-Type": "application/json",
            **({"Authorization": f"Bearer {token}"} if token else {}),
        },
    )
    try:
        with urllib.request.urlopen(request) as response:
            return response.status, json.loads(response.read() or b"null")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"null")


def check(label, method, path, body=None, token=None, ok=(200, 201)):
    status, payload = call(method, path, body, token)
    assert status in ok, f"{label}: {method} {path} -> {status} {payload}"
    print(f"  ok  {label} ({method} {path} -> {status})")
    return payload


def check_refused(label, method, path, body=None, token=None):
    status, payload = call(method, path, body, token)
    assert status >= 400, f"{label}: {method} {path} unexpectedly returned {status} {payload}"
    reason = payload.get("detail") or payload.get("errors") or payload
    print(f"  ok  {label} -> {status}: {str(reason)[:100]}")


session = check(
    "register returns a session",
    "POST",
    "/auth/register/",
    {"email": EMAIL, "password": PASSWORD, "full_name": "Smoke Tester"},
)
assert {"access", "refresh", "user"} <= session.keys(), sorted(session)
access, refresh = session["access"], session["refresh"]

me = check("profile for the new token", "GET", "/users/me/", token=access)
assert me["email"] == EMAIL and me["display_name"] == "Smoke Tester", me

# Exactly the body `UserProfile.patchPayload()` produces: read-only fields absent.
patch = {
    "full_name": "Grace Nabukeera",
    "university": "Uganda Martyrs University",
    "year_of_study": 4,
    "preferred_translation_code": "kjv",
    "interests": ["Worship", "Study"],
}
saved = check("profile edit persists", "PATCH", "/users/me/", patch, token=access)
assert saved["university"] == patch["university"] and saved["year_of_study"] == 4, saved

home = check("public home feed", "GET", "/home/")
devotional_id = home["devotion"]["id"]
check("mark a devotion read", "POST", "/progress/", {"kind": "devotional", "content_id": devotional_id}, token=access)
check(
    "marking it again is allowed",
    "POST",
    "/progress/",
    {"kind": "devotional", "content_id": devotional_id, "note": "Read with my group"},
    token=access,
)
history = check("reading history", "GET", "/progress/", token=access)
rows = history["results"] if isinstance(history, dict) else history
marked = [row for row in rows if row["content_id"] == devotional_id]
assert len(marked) == 1, f"a repeat marking must stay one row, got {len(marked)}"
print(f"  ok  one progress row per item, note kept: {bool(marked[0]['note'])}")

check("mark an article read", "POST", "/progress/", {"kind": "article", "content_id": home["articles"][0]["id"]}, token=access)
check_refused(
    "an unknown content id is refused",
    "POST",
    "/progress/",
    {"kind": "devotional", "content_id": "not-a-uuid"},
    token=access,
)
check_refused("an unknown translation code is refused", "PATCH", "/users/me/", {"preferred_translation_code": "niv"}, token=access)
check_refused(
    "a year outside 1..13 is refused",
    "PATCH",
    "/users/me/",
    {"year_of_study": 40},
    token=access,
)

rotated = check("refresh rotates the pair", "POST", "/auth/token/refresh/", {"refresh": refresh})
assert rotated["access"] != access and rotated.get("refresh"), rotated
check_refused("the spent refresh token is blacklisted", "POST", "/auth/token/refresh/", {"refresh": refresh})

check("logout blacklists the current refresh", "POST", "/auth/token/logout/", {"refresh": rotated["refresh"]}, token=rotated["access"])
check_refused("a logged-out session cannot refresh", "POST", "/auth/token/refresh/", {"refresh": rotated["refresh"]})
check_refused("anonymous profile access", "GET", "/users/me/")
check_refused("an invalid bearer token", "GET", "/users/me/", token="201")

print("\nAll Phase 2 client contracts hold against the live API.")
