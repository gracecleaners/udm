import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Check, Loader2, ShieldAlert, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { api, extractApiError } from "@/lib/api";
import { dateTimeText } from "@/components/curation/cells";
import type { Row } from "@/lib/curation";

const QUEUE = "prayers/moderation/";

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

  const queueQ = useQuery({
    queryKey: ["prayer-queue"],
    queryFn: async () => (await api.get<Row[]>(QUEUE)).data,
    refetchInterval: 60_000,
  });

  const decide = useMutation({
    mutationFn: async ({ id, state }: { id: string; state: "approved" | "rejected" }) =>
      (await api.patch(`${QUEUE}${id}/`, { moderation_state: state })).data,
    onSuccess: (_data, variables) => {
      setDecided((current) => ({ ...current, [variables.state]: current[variables.state] + 1 }));
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
            requests appear on the wall, declined ones stay with the student who wrote them.
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
            {rows.map((row) => (
              <li key={String(row.id)} className="console-prayer">
                <p className="console-prayer-body">{String(row.body)}</p>
                <div className="console-prayer-meta">
                  <span>{dateTimeText(row.created_at)}</span>
                  <span>{row.visibility === "public" ? "Offered to the wall" : String(row.visibility)}</span>
                  {decided.approved + decided.rejected > 0 && (
                    <span className="console-note">
                      This visit: {decided.approved} approved, {decided.rejected} declined
                    </span>
                  )}
                </div>
                <div className="console-prayer-actions">
                  <Button
                    size="sm"
                    onClick={() => decide.mutate({ id: String(row.id), state: "approved" })}
                    disabled={decide.isPending}
                  >
                    <Check size={15} aria-hidden="true" /> Approve for the wall
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => decide.mutate({ id: String(row.id), state: "rejected" })}
                    disabled={decide.isPending}
                  >
                    <X size={15} aria-hidden="true" /> Decline
                  </Button>
                </div>
              </li>
            ))}
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
