"""Reading a pasted YouTube link back into the id the player needs.

Staff copy addresses from the browser bar, a share sheet or a video description,
so the same recording arrives as `watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`,
`/live/`, sometimes with tracking parameters and a timestamp attached. One video
also has many addresses, which is why the link is normalised to its id before it
is stored: the id is what the player, the thumbnail and the duplicate check all
need, and an address the app cannot read is refused at save time rather than
shown as a broken player.
"""

import re
from urllib.parse import parse_qs, urlsplit

VIDEO_ID = re.compile(r"^[A-Za-z0-9_-]{11}$")
SHORT_HOSTS = {"youtu.be", "www.youtu.be", "m.youtu.be"}
LONG_HOSTS = {
    "youtube.com",
    "www.youtube.com",
    "m.youtube.com",
    "music.youtube.com",
    "www.youtube-nocookie.com",
    "youtube-nocookie.com",
}
# The path forms that carry the id in the segment rather than the query string.
PATH_KEYS = ("embed", "shorts", "live", "v")


def youtube_video_id(url):
    """The 11-character id behind a YouTube address, or None if there is none.

    A bare id is accepted too, because the ministry's own docs and edit lists
    keep videos by id, and an id typed straight in is not an error to punish.
    """
    value = (url or "").strip()
    if not value:
        return None
    if VIDEO_ID.match(value):
        return value

    candidate = value if "://" in value else f"https://{value}"
    parts = urlsplit(candidate)
    host = (parts.hostname or "").lower()
    segments = [segment for segment in parts.path.split("/") if segment]

    if host in SHORT_HOSTS:
        return _accepted(segments[0] if segments else None)

    if host in LONG_HOSTS:
        query = parse_qs(parts.query)
        for key in ("v", "video_id"):
            if query.get(key):
                return _accepted(query[key][0])
        if segments and segments[0].lower() in PATH_KEYS:
            return _accepted(segments[1] if len(segments) > 1 else None)

    return None


def _accepted(value):
    if value and VIDEO_ID.match(value):
        return value
    return None


def youtube_thumbnail(url):
    """YouTube's own still for a link, or None when there is no video to read.

    The ministry's artwork always wins; this exists so a list of recordings is
    never a wall of text just because nobody uploaded a cover.
    """
    video_id = youtube_video_id(url)
    return f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg" if video_id else None
