import { Suspense, useState } from "react";
import { Outlet } from "react-router-dom";
import { AppSidebar } from "./AppSidebar";
import { Topbar } from "./Topbar";

export function AppShell() {
  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  return (
    <div className="app-frame">
      {mobileNavOpen && (
        <button
          type="button"
          className="mobile-nav-backdrop"
          aria-label="Close navigation"
          onClick={() => setMobileNavOpen(false)}
        />
      )}
      <AppSidebar mobileOpen={mobileNavOpen} onNavigate={() => setMobileNavOpen(false)} />
      <div className="workspace-main">
        <Topbar mobileNavOpen={mobileNavOpen} onMenuClick={() => setMobileNavOpen((open) => !open)} />
        <main className="workspace-content">
          <Suspense fallback={<div className="route-loading" role="status">Loading page…</div>}><Outlet /></Suspense>
        </main>
        <footer className="workspace-footer">
          <span>UDM Ministry Console</span>
          <span>Know Christ. Grow in Christ. Make Disciples.</span>
        </footer>
      </div>
    </div>
  );
}