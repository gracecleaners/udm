import { format } from "date-fns";
import { Badge } from "@/components/ui/badge";

/** Small renderers shared by every curation table. */

const STATE_TONE: Record<string, "default" | "secondary" | "outline" | "destructive"> = {
  live: "default",
  published: "default",
  approved: "default",
  active: "default",
  scheduled: "secondary",
  draft: "secondary",
  requested: "secondary",
  cancelled: "destructive",
  inactive: "outline",
  rejected: "destructive",
};

const STATE_LABEL: Record<string, string> = {
  live: "Live",
  scheduled: "Scheduled",
  draft: "Draft",
  published: "Published",
  cancelled: "Cancelled",
  active: "Active",
  inactive: "Hidden",
};

export function StateBadge({ state }: { state: string }) {
  return <Badge variant={STATE_TONE[state] ?? "outline"}>{STATE_LABEL[state] ?? state}</Badge>;
}

export function dateText(value: unknown): string {
  if (typeof value !== "string" || !value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "—" : format(date, "d MMM yyyy");
}

export function dateTimeText(value: unknown): string {
  if (typeof value !== "string" || !value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "—" : format(date, "d MMM yyyy, HH:mm");
}

export function ellipsis(value: unknown, max = 110): string {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text.length > max ? `${text.slice(0, max - 1)}…` : text || "—";
}

export function countText(value: unknown, singular: string, plural?: string): string {
  const n = Number(value ?? 0);
  return `${n} ${n === 1 ? singular : plural ?? `${singular}s`}`;
}

/**
 * A recording's length, in the shape the app prints next to it: `15:40`, or
 * `1:02:05` once it passes an hour. Staff read the same number the student
 * sees, so a length that looks wrong in the console is wrong on the server too.
 */
export function durationText(value: unknown): string {
  const seconds = Number(value ?? 0);
  if (!Number.isFinite(seconds) || seconds <= 0) return "—";
  const pad = (n: number) => String(n).padStart(2, "0");
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const rest = seconds % 60;
  return hours ? `${hours}:${pad(minutes)}:${pad(rest)}` : `${minutes}:${pad(rest)}`;
}

export function YesNo({ value }: { value: unknown }) {
  return <span className={value ? "console-yes" : "console-no"}>{value ? "Yes" : "No"}</span>;
}
