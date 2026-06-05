import { createContext, useContext, useState, useCallback, useEffect, type ReactNode } from "react";
import { api } from "../lib/api";
import type { AuthTokens, User } from "../lib/types";

interface AuthContextType {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isInitializing: boolean;
  login: (email: string, password: string, tenantId?: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(() =>
    localStorage.getItem("auth_token"),
  );
  const [isInitializing, setIsInitializing] = useState<boolean>(!!token);

  const isAuthenticated = !!token;

  useEffect(() => {
    if (token) {
      localStorage.setItem("auth_token", token);
    } else {
      localStorage.removeItem("auth_token");
    }
  }, [token]);

  useEffect(() => {
    let cancelled = false;

    const bootstrapUser = async () => {
      if (!token) {
        setUser(null);
        setIsInitializing(false);
        return;
      }

      if (user) {
        setIsInitializing(false);
        return;
      }

      setIsInitializing(true);

      try {
        const me = await api.get<{ data?: User; user?: User }>("/api/v1/auth/me");
        const nextUser = me.data ?? me.user;

        if (!nextUser) {
          throw new Error("Missing user payload from /auth/me");
        }

        if (!cancelled) {
          setUser(nextUser);
        }
      } catch {
        if (!cancelled) {
          setToken(null);
          setUser(null);
          localStorage.removeItem("auth_token");
          localStorage.removeItem("refresh_token");
        }
      } finally {
        if (!cancelled) {
          setIsInitializing(false);
        }
      }
    };

    bootstrapUser();

    return () => {
      cancelled = true;
    };
  }, [token, user]);

  const login = useCallback(async (email: string, password: string, tenantId?: string) => {
    const payload = tenantId ? { email, password, tenant_id: tenantId } : { email, password };
    const result = await api.post<AuthTokens & { user: User }>(
      "/api/v1/auth/login",
      payload,
    );
    setToken(result.access_token);
    setUser(result.user);
    setIsInitializing(false);
  }, []);

  const logout = useCallback(() => {
    setToken(null);
    setUser(null);
    setIsInitializing(false);
    localStorage.removeItem("auth_token");
    localStorage.removeItem("refresh_token");
  }, []);

  return (
    <AuthContext.Provider value={{ user, token, isAuthenticated, isInitializing, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
