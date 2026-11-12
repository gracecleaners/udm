import type { LucideIcon } from "lucide-react";
import type { ReactNode } from "react";
import { useEffect, useRef, useState } from "react";
import {
  BookOpen,
  BookOpenText,
  Building2,
  CalendarDays,
  Compass,
  Headphones,
  HeartHandshake,
  LayoutDashboard,
  Layers,
  Library,
  Lightbulb,
  ListChecks,
  ListOrdered,
  MapPinned,
  ScrollText,
  Settings2,
  UsersRound,
  X,
} from "lucide-react";
import { NavLink } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";
import { BrandLockup, BrandMark } from "@/components/BrandLockup";

interface AppSidebarProps {
  mobileOpen: boolean;
  onNavigate: () => void;
}

interface NavItem {
  title: string;
  url: string;
  icon: LucideIcon;
  end?: boolean;
}

const ministryItems: NavItem[] = [
  { title: "Overview", url: "/", icon: LayoutDashboard, end: true },
  { title: "Devotional series", url: "/series", icon: Layers },
  { title: "Devotions", url: "/devotions", icon: BookOpenText },
  { title: "Articles", url: "/articles", icon: ScrollText },
  { title: "Resource guides", url: "/resource-guides", icon: Compass },
  { title: "Resource steps", url: "/resource-steps", icon: ListOrdered },
];

const scriptureItems: NavItem[] = [
  { title: "Reading plans", url: "/plans", icon: ListChecks },
  { title: "Translations", url: "/translations", icon: BookOpen },
];

const learnItems: NavItem[] = [
  { title: "Media shelves", url: "/media-shelves", icon: Library },
  { title: "Media recordings", url: "/media-recordings", icon: Headphones },
  { title: "Memory verses", url: "/memory-verses", icon: Lightbulb },
];

const campusItems: NavItem[] = [
  { title: "Universities", url: "/universities", icon: MapPinned },
  { title: "Campuses", url: "/campuses", icon: Building2 },
  { title: "Fellowships", url: "/fellowships", icon: UsersRound },
  { title: "Groups", url: "/groups", icon: HeartHandshake },
  { title: "Events", url: "/events", icon: CalendarDays },
];

const peopleItems: NavItem[] = [
  { title: "Students", url: "/students", icon: UsersRound },
  { title: "Prayer queue", url: "/prayers", icon: HeartHandshake },
  { title: "Account", url: "/account", icon: Settings2 },
];

function initials(name: string) {
  return name.split(/[\s@._-]+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "UD";
}

export function AppSidebar({ mobileOpen, onNavigate }: AppSidebarProps) {
  const [isMobile, setIsMobile] = useState(() => typeof window !== "undefined" && window.matchMedia("(max-width: 760px)").matches);
  const sidebarRef = useRef<HTMLElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const { user, role } = useAuth();
  const displayName = user?.display_name || user?.email || "Ministry staff";

  const renderItems = (items: NavItem[]) => (
    <ul className="workspace-nav-list">
      {items.map(({ title, url, icon: Icon, end }) => (
        <li key={title}>
          <NavLink
            to={url}
            end={end}
            onClick={onNavigate}
            className={({ isActive }) => `workspace-nav-item${isActive ? " is-active" : ""}`}
          >
            <Icon aria-hidden="true" size={17} strokeWidth={1.8} />
            <span>{title}</span>
          </NavLink>
        </li>
      ))}
    </ul>
  );

  const renderGroup = (label: string, items: NavItem[], accessory?: ReactNode) => (
    <section className="workspace-nav-group" key={label}>
      <div className="workspace-nav-label"><span>{label}</span>{accessory}</div>
      {renderItems(items)}
    </section>
  );

  useEffect(() => {
    const media = window.matchMedia("(max-width: 760px)");
    const updateViewport = () => setIsMobile(media.matches);
    updateViewport();
    media.addEventListener("change", updateViewport);
    return () => media.removeEventListener("change", updateViewport);
  }, []);

  useEffect(() => {
    const sidebar = sidebarRef.current;
    if (!sidebar) return;
    if (isMobile && !mobileOpen) sidebar.setAttribute("inert", "");
    else sidebar.removeAttribute("inert");
  }, [isMobile, mobileOpen]);

  useEffect(() => {
    if (isMobile && mobileOpen) closeButtonRef.current?.focus();
  }, [isMobile, mobileOpen]);

  useEffect(() => {
    if (!isMobile || !mobileOpen) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        onNavigate();
        return;
      }
      if (event.key !== "Tab") return;
      const focusable = Array.from(sidebarRef.current?.querySelectorAll<HTMLElement>('a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])') ?? [])
        .filter((element) => element.getClientRects().length > 0);
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (!first || !last) {
        event.preventDefault();
      } else if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", closeOnEscape);
    return () => document.removeEventListener("keydown", closeOnEscape);
  }, [isMobile, mobileOpen, onNavigate]);

  return (
    <aside id="primary-navigation" ref={sidebarRef} className={`app-sidebar${mobileOpen ? " is-mobile-open" : ""}`} aria-label="Primary navigation" aria-hidden={isMobile && !mobileOpen}>
      <div className="sidebar-brand-row">
        <BrandMark />
        <BrandLockup />
        <button ref={closeButtonRef} type="button" className="sidebar-mobile-close" onClick={onNavigate} aria-label="Close navigation"><X size={19} /></button>
      </div>

      <div className="workspace-switcher">
        <span className="workspace-avatar"><BookOpen size={16} /></span>
        <span className="workspace-switcher-copy">
          <small>MINISTRY CONSOLE</small>
          <strong>UDM Operations</strong>
        </span>
        <span className="workspace-status-dot" title="Signed in" />
      </div>

      <nav className="workspace-navigation">
        {renderGroup("Daily bread", ministryItems)}
        {renderGroup("Scripture", scriptureItems)}
        {renderGroup("Learn", learnItems)}
        {renderGroup("Campus", campusItems)}
        {renderGroup("People", peopleItems)}
      </nav>

      <div className="sidebar-bottom">
        <div className="sidebar-help-card">
          <span className="help-card-icon"><HeartHandshake size={15} /></span>
          <span><strong>Know Christ. Grow in Christ.</strong><small>Make disciples.</small></span>
        </div>
        <div className="sidebar-account">
          <span className="account-avatar">{initials(displayName)}</span>
          <span className="account-meta">
            <strong>{displayName}</strong>
            <small>{role === "superuser" ? "Superuser" : "Ministry staff"}</small>
          </span>
          <span className="account-online-dot" aria-label="Online" />
        </div>
      </div>
    </aside>
  );
}
