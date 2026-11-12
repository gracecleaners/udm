import { useEffect, useMemo, useRef } from "react";
import { ChevronRight, LogOut, Menu, UserRound, X } from "lucide-react";
import { useLocation, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@/contexts/AuthContext";
import { fetchIdentity } from "@/services/authService";

const routeTitles: Array<[string, string]> = [
  ["/", "Console overview"],
  ["/devotions", "Devotionals"],
  ["/series", "Devotional series"],
  ["/articles", "Articles"],
  ["/resource-guides", "Resource guides"],
  ["/resource-steps", "Resource steps"],
  ["/plans", "Reading plans"],
  ["/translations", "Bible translations"],
  ["/media-shelves", "Media shelves"],
  ["/media-recordings", "Media recordings"],
  ["/memory-verses", "Memory verses"],
  ["/universities", "Universities"],
  ["/campuses", "Campuses"],
  ["/fellowships", "Fellowships"],
  ["/groups", "Discipleship groups"],
  ["/events", "Events"],
  ["/students", "Students"],
  ["/prayers", "Prayer moderation"],
  ["/account", "Account"],
];

interface TopbarProps {
  mobileNavOpen: boolean;
  onMenuClick: () => void;
}

export function Topbar({ mobileNavOpen, onMenuClick }: TopbarProps) {
  const { user, role, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const mobileMenuButtonRef = useRef<HTMLButtonElement>(null);
  const wasMobileNavOpen = useRef(false);
  const profileMenuRef = useRef<HTMLDetailsElement>(null);
  // The API names the account; the token payload is never treated as the truth.
  const profileQ = useQuery({ queryKey: ["identity"], queryFn: fetchIdentity, staleTime: 60_000 });
  const displayName = profileQ.data?.display_name || user?.display_name || user?.email || "Ministry staff";
  const initials = displayName.split(/[\s@._-]+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "UD";

  const pageTitle = useMemo(() => {
    const exact = routeTitles.find(([path]) => location.pathname === path);
    if (exact) return exact[1];
    return "Ministry console";
  }, [location.pathname]);

  useEffect(() => {
    if (wasMobileNavOpen.current && !mobileNavOpen) mobileMenuButtonRef.current?.focus();
    wasMobileNavOpen.current = mobileNavOpen;
  }, [mobileNavOpen]);

  useEffect(() => {
    const closeOnOutsideClick = (event: PointerEvent) => {
      if (!profileMenuRef.current?.contains(event.target as Node)) profileMenuRef.current?.removeAttribute("open");
    };
    document.addEventListener("pointerdown", closeOnOutsideClick);
    return () => document.removeEventListener("pointerdown", closeOnOutsideClick);
  }, []);

  return (
    <header className="workspace-topbar">
      <button ref={mobileMenuButtonRef} type="button" className="chrome-icon-button mobile-menu-button" onClick={onMenuClick} aria-label={mobileNavOpen ? "Close navigation" : "Open navigation"} aria-expanded={mobileNavOpen} aria-controls="primary-navigation">{mobileNavOpen ? <X size={19} /> : <Menu size={19} />}</button>
      <div className="topbar-heading">
        <span className="topbar-crumb">UDM <ChevronRight size={13} /> <span>{role === "superuser" ? "Superuser" : "Staff"}</span></span>
        <strong>{pageTitle}</strong>
      </div>
      <div className="topbar-actions">
        <div className="topbar-divider" />
        <details className="profile-menu" ref={profileMenuRef}>
          <summary className="profile-trigger">
            <span className="profile-avatar">{initials}</span>
            <span className="profile-trigger-copy">
              <strong>{displayName}</strong>
              <small>{user?.email}</small>
            </span>
            <ChevronRight className="profile-chevron" size={15} />
          </summary>
          <div className="profile-menu-popover">
            <div className="profile-popover-name"><strong>{displayName}</strong><span>{user?.email}</span></div>
            <button type="button" onClick={() => { profileMenuRef.current?.removeAttribute("open"); navigate("/account"); }}><UserRound size={16} /> Account</button>
            <button type="button" onClick={() => { profileMenuRef.current?.removeAttribute("open"); logout(); }} className="logout-action"><LogOut size={16} /> Sign out</button>
          </div>
        </details>
      </div>
    </header>
  );
}
