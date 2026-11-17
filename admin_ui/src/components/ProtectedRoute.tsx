import { Navigate, useLocation } from "react-router-dom";
import { ReactNode } from "react";
import { useAuth } from "@/contexts/AuthContext";
import type { ConsoleCapability } from "@/services/authService";

/**
 * Every curation screen is reachable by any staff account, because every
 * curation endpoint is staff-readable. What differs between the two roles is
 * which writes each one accepts, and `ResourceScreen` gates those control by
 * control instead of hiding whole pages.
 *
 * A screen the API refuses to even list is the exception, so it names the
 * capability it needs and sends anyone without it back to the overview rather
 * than rendering a table of refusals.
 */
export function ProtectedRoute({
  children,
  capability,
}: {
  children: ReactNode;
  capability?: ConsoleCapability;
}) {
  const { isAuthenticated, isLoading, can } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center text-muted-foreground">
        Loading…
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  if (capability && !can(capability)) {
    return <Navigate to="/" replace />;
  }

  return <>{children}</>;
}
