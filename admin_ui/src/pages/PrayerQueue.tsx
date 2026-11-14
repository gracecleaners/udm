import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Check, Loader2, ShieldAlert, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { api, extractApiError } from "@/lib/api";
import { dateTimeText } from "@/components/curation/cells";
import type { Row } from "@/lib/curation";

const QUEUE = "prayers/moderation/";

/**
 * Which wall a request belongs on. The student picks it when writing; staff can
 * correct a misfiled one here, and the API takes the correction only while the
 * request is still pending — an approved row has already left this queue.
 */
const WALLS = [
  { value: "prayer", label: "Prayer" },
  { value: "testimony", label: "Testimony" },
  { value: "encouragement", label: "Encouragement" },
];

/** What the model itself defaults to, so a row without a category reads honestly. */
const DEFAULT_WALL = "prayer";

const wallOf = (row: Row) =>
  WALLS.some((wall) => wall.value === row.category) ? String(row.category) : DEFAULT_WALL;

const wallLabel = (value: string) => WALLS.find((wall) => wall.value === value)?.label ?? value;

/**
 * Prayer requests students offered to the whole wall.
 *
 * The API hands back only what is still waiting: a public request whose owner
 * gave consent, in `pending` state. Group requests are not here at all — the
 * group’s own leader moderates those in the student app — and nothing a student
 * kept private is reachable from this console.
 */
export default function PrayerQueue() {
  const queryClient = useQueryClient();
  const [error, setError] = useState("");
  const [decided, setDecided] = useState<{ approved: number; rejected: number }>({ approved: 0, rejected: 0 });
  // A wall choice is held here until the decision goes out, because the decision
  // is the only write this endpoint still answers for the row.
  const [wallEdits, setWallEdits] = useState<Record<string, string>>({});

  const queueQ = useQuery({
    queryKey: ["prayer-queue"],
    queryFn: async () => (await api.get<Row[]>(QUEUE)).data,
    refetchInterval: 60_000,
  });

  const decide = useMutation({
    mutationFn: async ({ id, state, category }: { id: string; state: "approved" | "rejected"; category?: string }) => {
      // One PATCH on purpose: correcting the wall after the decision would ask
      // the moderation endpoint for a row it no longer returns.
      const body: Row = { moderation_state: state };
      if (category) body.category = category;
      return (await api.patch<Row>(`${QUEUE}${id}/`, body)).data;
    },
    onSuccess: (_data, { id, state }) => {
      setDecided((current) => ({ ...current, [state]: current[state] + 1 }));
      setWallEdits((current) => {
        if (!(id in current)) return current;
        const next = { ...current };
        delete next[id];
        return next;
      });
      queryClient.invalidateQueries({ queryKey: ["prayer-queue"] });
    },
    onError: (err) => setError(extractApiError(err, "The API refused that decision.")),
  });

  const rows = queueQ.data ?? [];

  return (
    <div className="console-page">
      <header className="console-page-head">
        <div>
          <h1>Prayer queue</h1>
          <p>
            Requests students offered to the community wall, oldest last. A decision is final in the app: approved
            requests appear on the wall, declined ones stay with the student who wrote them. A request names the wall
            it belongs on; correcting it here travels with your decision, because a row that has left this queue can
            no longer be changed.
          </p>
        </div>
        <Badge variant={rows.length ? "secondary" : "outline"}>
          {queueQ.isLoading ? "Loading…" : `${rows.length} waiting`}
        </Badge>
      </header>

      {error && <p className="console-error" role="alert">{error}</p>}

      <div className="console-panel">
        {queueQ.isLoading ? (
          <p className="console-empty"><Loader2 size={15} className="animate-spin" aria-hidden="true" /> Loading the queue…</p>
        ) : queueQ.isError ? (
          <p className="console-error" role="alert">The queue could not be loaded. Nothing here is guessed at.</p>
        ) : rows.length === 0 ? (
          <p className="console-empty">
            Nothing is waiting. Private and group requests never reach this screen, so an empty queue is the normal state.
          </p>
        ) : (
          <ul className="console-prayer-list">
            {rows.map((row) => {
              const id = String(row.id);
              const storedWall = wallOf(row);
              const wall = wallEdits[id] ?? storedWall;
              const wallMoved = wall !== storedWall;
              return (
                <li key={id} className="console-prayer">
                  <p className="console-prayer-body">{String(row.body)}</p>
                  <div className="console-prayer-meta">
                    <span>{dateTimeText(row.created_at)}</span>
                    <span>{row.visibility === "public" ? "Offered to the wall" : String(row.visibility)}</span>
                    <span>{wallLabel(wall)} wall</span>
                    {wallMoved && <span className="console-note">Wall corrected: it saves with your decision.</span>}
                    {decided.approved + decided.rejected > 0 && (
                      <span className="console-note">
                        This visit: {decided.approved} approved, {decided.rejected} declined
                      </span>
                    )}
                  </div>
                  <div className="console-prayer-actions">
                    <Select
                      value={wall}
                      onValueChange={(next) => setWallEdits((current) => ({ ...current, [id]: next }))}
                      disabled={decide.isPending}
                    >
                      <SelectTrigger className="console-prayer-wall-select" aria-label="Wall for this request">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {WALLS.map((option) => (
                          <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <Button
                      size="sm"
                      onClick={() => decide.mutate({ id, state: "approved", category: wallMoved ? wall : undefined })}
                      disabled={decide.isPending}
                    >
                      <Check size={15} aria-hidden="true" /> Approve for the wall
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => decide.mutate({ id, state: "rejected", category: wallMoved ? wall : undefined })}
                      disabled={decide.isPending}
                    >
                      <X size={15} aria-hidden="true" /> Decline
                    </Button>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <p className="console-note">
        <ShieldAlert size={14} aria-hidden="true" />
        &nbsp;A request stays anonymous here: the API returns the text and the date, not the student who wrote it.
      </p>
    </div>
  );
}
