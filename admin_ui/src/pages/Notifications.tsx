import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Loader2, Megaphone, Send, ShieldAlert } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { api, extractApiError } from "@/lib/api";
import type { Row } from "@/lib/curation";

const BROADCAST = "admin/notifications/";

const TITLE_MAX = 160;
const BODY_MAX = 600;

/**
 * The notice's own kind, which the phone turns into an icon. Free text on the
 * API, so the console offers the five the app draws and nothing else.
 */
const KINDS = [
  { value: "announcement", label: "Announcement" },
  { value: "reading", label: "Reading plan" },
  { value: "devotion", label: "Devotional" },
  { value: "event", label: "Event" },
  { value: "community", label: "Community" },
];

/**
 * Where a notice may open. The app keeps its own list of screens it can build
 * without being handed an id, and every route here is one of them: a staff
 * member is never offered a link the phone would quietly drop.
 */
const DESTINATIONS = [
  { value: "__none__", label: "No link — inbox only" },
  { value: "/feed", label: "Home feed" },
  { value: "/notifications", label: "The notice inbox itself" },
  { value: "/reading-day", label: "Today’s reading" },
  { value: "/reading-history", label: "Reading history" },
  { value: "/articles", label: "Articles" },
  { value: "/community", label: "Community" },
  { value: "/courses", label: "Courses" },
  { value: "/new-believer", label: "New believer" },
  { value: "/settings", label: "Settings" },
];

/**
 * One message, every active student's inbox.
 *
 * The write is a single POST to `admin/notifications/` that answers with how
 * many inboxes it filled. There is no list of what was sent: the same rows are
 * students' private reading records, and staff status does not buy a right to
 * read them, so this screen can write and cannot look.
 */
export default function Notifications() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [kind, setKind] = useState("announcement");
  const [destination, setDestination] = useState("__none__");
  const [error, setError] = useState("");
  const [sent, setSent] = useState<number | null>(null);
  // A broadcast cannot be unsent, so the button asks once and only the second
  // press writes. Anything edited after arming disarms it again.
  const [armed, setArmed] = useState(false);

  const send = useMutation({
    mutationFn: async () => {
      const payload: Row = { title, body, kind };
      if (destination !== "__none__") payload.destination = destination;
      return (await api.post<Row>(BROADCAST, payload)).data;
    },
    onSuccess: (row) => {
      setSent(Number(row.created_for ?? 0));
      setArmed(false);
      setTitle("");
      setBody("");
      setDestination("__none__");
      setKind("announcement");
    },
    onError: (err) => setError(extractApiError(err, "The API refused this message.")),
  });

  const blank = !title.trim() || !body.trim();
  const tooLong = title.length > TITLE_MAX || body.length > BODY_MAX;

  const arm = () => {
    setError("");
    setSent(null);
    if (!send.isPending) send.mutate();
  };

  return (
    <div className="console-page">
      <header className="console-page-head">
        <div>
          <h1>Notifications</h1>
          <p>
            A message written here is saved into every active student's inbox, and the unread count on the app's bell
            changes the next time they open it. Sending is one write and there is no taking it back.
          </p>
        </div>
        <Badge variant={sent === null ? "outline" : "secondary"}>
          {sent === null ? "Nothing sent this visit" : `${sent} ${sent === 1 ? "inbox" : "inboxes"} written`}
        </Badge>
      </header>

      <div className="console-panel">
        <div className="console-form-grid">
          <div className="console-field">
            <Label htmlFor="broadcast-title">Title</Label>
            <Input
              id="broadcast-title"
              value={title}
              maxLength={TITLE_MAX}
              placeholder="Friday prayer night moves to 6pm"
              onChange={(event) => {
                setTitle(event.target.value);
                setArmed(false);
              }}
            />
            <p className="console-field-help">{title.length}/{TITLE_MAX} characters.</p>
          </div>

          <div className="console-field console-field-wide">
            <Label htmlFor="broadcast-body">Message</Label>
            <Textarea
              id="broadcast-body"
              rows={5}
              value={body}
              maxLength={BODY_MAX}
              placeholder="What a student needs to know, in the ministry's own words."
              onChange={(event) => {
                setBody(event.target.value);
                setArmed(false);
              }}
            />
            <p className="console-field-help">
              {body.length}/{BODY_MAX} characters. The inbox shows the whole text; a phone's notification banner shows
              the first line or two.
            </p>
          </div>

          <div className="console-field">
            <Label>Kind</Label>
            <Select
              value={kind}
              onValueChange={(next) => {
                setKind(next);
                setArmed(false);
              }}
            >
              <SelectTrigger aria-label="Notice kind">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {KINDS.map((option) => (
                  <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="console-field-help">The phone draws this kind's icon beside the row.</p>
          </div>

          <div className="console-field">
            <Label>Opens</Label>
            <Select
              value={destination}
              onValueChange={(next) => {
                setDestination(next);
                setArmed(false);
              }}
            >
              <SelectTrigger aria-label="Destination screen">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {DESTINATIONS.map((option) => (
                  <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="console-field-help">
              Tapping the notice opens this screen. One devotion, article or reading day cannot be named: a notice
              reaches every student at once, so it links to a place, not to a page.
            </p>
          </div>
        </div>

        {error && <p className="console-error" role="alert">{error}</p>}
        {sent !== null && !send.isPending && (
          <p className="console-saved">
            <Megaphone size={15} aria-hidden="true" />
            &nbsp;Written into {sent} {sent === 1 ? "student's inbox" : "students' inboxes"}.
          </p>
        )}

        <div className="console-broadcast-actions">
          <Button
            size="sm"
            variant={armed ? "default" : "outline"}
            disabled={blank || tooLong || send.isPending}
            onClick={() => (armed ? arm() : setArmed(true))}
          >
            {send.isPending ? (
              <><Loader2 size={15} className="animate-spin" aria-hidden="true" /> Sending…</>
            ) : armed ? (
              <><Send size={15} aria-hidden="true" /> Confirm — it cannot be taken back</>
            ) : (
              <><Send size={15} aria-hidden="true" /> Send to every active student</>
            )}
          </Button>
          {armed && !send.isPending && (
            <Button size="sm" variant="ghost" onClick={() => setArmed(false)}>Cancel</Button>
          )}
        </div>
      </div>

      <p className="console-note">
        <ShieldAlert size={14} aria-hidden="true" />
        &nbsp;Inboxes are written the moment you send. A push to a locked phone additionally needs the ministry's
        Firebase service account on the server (`UDM_FIREBASE_SERVICE_ACCOUNT`); without it the message still waits in
        the inbox and only the banner is skipped.
      </p>
      <p className="console-note">
        There is no history on this screen on purpose. What a student has been sent, and what they have read, is their
        own record — the API exposes it only to the account it belongs to.
      </p>
    </div>
  );
}
