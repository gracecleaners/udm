import { createContext, useCallback, useContext, useEffect, useMemo, useState, ReactNode } from "react";
import { tokenStorage, restoreSession, endSession } from "@/lib/api";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "@/hooks/use-toast";
import { fetchIdentity, signIn, type ConsoleIdentity } from "@/services/authService";

/**
 * Two roles, mirroring the API: ministry staff author content, and a platform
 * admin additionally owns the surfaces a change cannot undo — Bible licensing.
 */
export type ConsoleRole = "superuser" | "staff" | "guest";

export type AuthUser = ConsoleIdentity;

interface AuthContextValue {
  user: AuthUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  role: ConsoleRole;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

function roleFor(user: AuthUser | null): ConsoleRole {
  if (!user) return "guest";
  if (user.is_superuser) return "superuser";
  return "staff";
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const queryClient = useQueryClient();

  useEffect(() => {
    let cancelled = false;
    const restore = async () => {
      try {
        const access = await restoreSession();
        if (!access || cancelled) return;
        // A session is authenticated only once the API has named the account.
        const identity = await fetchIdentity();
        if (!cancelled && tokenStorage.getAccess() === access) setUser(identity);
      } catch {
        tokenStorage.clear();
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };
    void restore();
    return () => { cancelled = true; };
  }, []);

  const logout = useCallback(() => {
    void queryClient.cancelQueries();
    queryClient.clear();
    setUser(null);
    void endSession().catch(() => {
      toast({
        title: "Server sign-out could not be confirmed",
        description: "Your browser session was cleared. Reconnect and sign out again to revoke the console session.",
        variant: "destructive",
      });
    });
  }, [queryClient]);

  useEffect(() => {
    const handler = () => logout();
    window.addEventListener("udm:logout", handler);
    return () => window.removeEventListener("udm:logout", handler);
  }, [logout]);

  const login = useCallback(async (email: string, password: string) => {
    const { access, identity } = await signIn(email, password);
    void queryClient.cancelQueries();
    queryClient.clear();
    tokenStorage.set(access);
    setUser(identity);
  }, [queryClient]);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      isAuthenticated: !!user,
      isLoading,
      role: roleFor(user),
      login,
      logout,
    }),
    [user, isLoading, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
