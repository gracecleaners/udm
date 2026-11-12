import { useQuery } from "@tanstack/react-query";
import {
  BookOpen,
  BookOpenText,
  Building2,
  CalendarDays,
  CheckCircle2,
  ChevronRight,
  Compass,
  Headphones,
  HeartHandshake,
  Layers,
  Library,
  Lightbulb,
  ListChecks,
  MapPinned,
  ScrollText,
  UsersRound,
} from "lucide-react";
import { Link } from "react-router-dom";
import { api } from "@/lib/api";
import { useAuth } from "@/contexts/AuthContext";

interface Section {
  title: string;
  url: string;
  icon: typeof BookOpen;
  note: string;
}

const sections: Section[] = [
  { title: "Devotional series", url: "/series", icon: Layers, note: "The read-through sets the Devotions tab grids." },
  { title: "Devotionals", url: "/devotions", icon: BookOpenText, note: "Daily readings with Scripture and a written response." },
  { title: "Articles", url: "/articles", icon: ScrollText, note: "Longer teaching pieces, filed by category." },
  {
    title: "Resource guides",
    url: "/resource-guides",
    icon: Compass,
    note: "The home “Find resources on” list, and the steps inside each guide.",
  },
  { title: "Reading plans", url: "/plans", icon: ListChecks, note: "Published plans and their day-by-day assignments." },
  { title: "Translations", url: "/translations", icon: BookOpen, note: "Which Bible editions students may read, and offline." },
  {
    title: "Media shelves",
    url: "/media-shelves",
    icon: Library,
    note: "The Learn tab’s shelves — SOMA, Uliza, the podcast — and the recordings filed inside them.",
  },
  {
    title: "Media recordings",
    url: "/media-recordings",
    icon: Headphones,
    note: "Teaching videos and audio the ministry publishes, with their write-ups.",
  },
  {
    title: "Memory verses",
    url: "/memory-verses",
    icon: Lightbulb,
    note: "The home feed’s memory verse, and the verses students commit to memory.",
  },
  { title: "Universities", url: "/universities", icon: MapPinned, note: "The institutions this ministry works with." },
  { title: "Campuses", url: "/campuses", icon: Building2, note: "Where a fellowship actually meets." },
  { title: "Fellowships", url: "/fellowships", icon: UsersRound, note: "Public and members-only gatherings." },
  { title: "Groups", url: "/groups", icon: HeartHandshake, note: "Discipleship groups, capacity and membership." },
  { title: "Events", url: "/events", icon: CalendarDays, note: "Upcoming gatherings and registration limits." },
];

export default function Overview() {
  const { user } = useAuth();
  // Not a decorative widget: this is the same probe the deployment checks.
  const healthQ = useQuery({
    queryKey: ["health"],
    queryFn: async () => (await api.get("/health/")).data as { status?: string; database?: string },
    retry: 0,
    staleTime: 30_000,
  });

  return (
    <div className="console-page">
      <header className="console-page-head">
        <div>
          <h1>Salaam, {user?.display_name || "friend"}.</h1>
          <p>
            Everything here is written by the console and read by the app. Nothing on this list is a preview —
            publishing changes what students see the next time their feed loads.
          </p>
        </div>
        <p className={`console-health${healthQ.isSuccess ? " is-good" : ""}`} role="status">
          {healthQ.isFetching
            ? "Checking the API…"
            : healthQ.isSuccess
              ? <><CheckCircle2 size={14} aria-hidden="true" /> API reachable{healthQ.data?.database ? ` · database ${healthQ.data.database}` : ""}</>
              : "The API is not answering. Sign-in may still work from your existing session."}
        </p>
      </header>

      <section className="console-section" aria-labelledby="console-sections">
        <h2 id="console-sections" className="console-section-title">Curate</h2>
        <div className="console-card-grid">
          {sections.map(({ title, url, icon: Icon, note }) => (
            <Link key={title} to={url} className="console-nav-card">
              <span className="console-nav-card-icon"><Icon size={17} strokeWidth={1.8} aria-hidden="true" /></span>
              <span className="console-nav-card-copy"><strong>{title}</strong><small>{note}</small></span>
              <ChevronRight size={15} aria-hidden="true" />
            </Link>
          ))}
        </div>
      </section>

      <section className="console-section" aria-labelledby="console-people">
        <h2 id="console-people" className="console-section-title">People</h2>
        <div className="console-card-grid">
          <Link to="/students" className="console-nav-card">
            <span className="console-nav-card-icon"><UsersRound size={17} strokeWidth={1.8} aria-hidden="true" /></span>
            <span className="console-nav-card-copy">
              <strong>Students</strong>
              <small>Who is enrolled. Reading history, bookmarks and notes stay private to each account.</small>
            </span>
            <ChevronRight size={15} aria-hidden="true" />
          </Link>
          <Link to="/prayers" className="console-nav-card">
            <span className="console-nav-card-icon"><HeartHandshake size={17} strokeWidth={1.8} aria-hidden="true" /></span>
            <span className="console-nav-card-copy">
              <strong>Prayer queue</strong>
              <small>Only requests shared publicly, and only after the student chose that scope.</small>
            </span>
            <ChevronRight size={15} aria-hidden="true" />
          </Link>
        </div>
      </section>
    </div>
  );
}
