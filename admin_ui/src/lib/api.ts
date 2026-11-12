import axios, { AxiosError, InternalAxiosRequestConfig } from "axios";

// The console talks to the same origin it is served from in production, and
// through the Vite proxy in development, so the refresh cookie is first-party
// in both cases and never needs credentialed cross-origin requests.
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "/api/v1";

// Access credentials live only for this page's lifetime. The refresh
// credential is an HttpOnly cookie the API owns; JavaScript never sees it.
let accessToken: string | null = null;
let sessionActive = false;
let sessionEpoch = 0;
let refreshing: Promise<string | null> | null = null;
let endingSession: Promise<void> | null = null;

export const tokenStorage = {
  getAccess: () => accessToken,
  set: (access: string) => { accessToken = access; sessionActive = true; },
  clear: () => { accessToken = null; sessionActive = false; sessionEpoch += 1; },
};

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 20_000,
  headers: { "Content-Type": "application/json" },
});

type RetriableConfig = InternalAxiosRequestConfig & { _retry?: boolean; _sessionEpoch?: number };

function tokenExpiry(token: string | null): number | null {
  if (!token) return null;
  try {
    const payload = token.split(".")[1];
    if (!payload) return null;
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const decoded = JSON.parse(atob(base64.padEnd(Math.ceil(base64.length / 4) * 4, "="))) as { exp?: unknown };
    return typeof decoded.exp === "number" ? decoded.exp : null;
  } catch { return null; }
}

function expiresWithin(token: string | null, seconds: number): boolean {
  const exp = tokenExpiry(token);
  return exp !== null && exp <= Math.floor(Date.now() / 1000) + seconds;
}

/**
 * Renews the access token from the cookie the API set at sign-in.
 *
 * The console's session endpoints live under `/auth/admin/`, which is also the
 * cookie's path, so this is the only way to get back in after a reload.
 */
export function restoreSession(): Promise<string | null> {
  if (endingSession) return Promise.resolve(null);
  if (!refreshing) {
    const epoch = sessionEpoch;
    refreshing = axios.post<{ access: string }>(
      `${API_BASE_URL}/auth/admin/token/refresh/`,
      {},
      { withCredentials: true, timeout: 15_000 },
    )
      .then(({ data }) => {
        if (epoch !== sessionEpoch) throw new Error("Session changed during refresh.");
        if (typeof data.access !== "string" || !data.access) throw new Error("Invalid refresh response.");
        tokenStorage.set(data.access);
        return data.access;
      })
      .catch((error: unknown) => {
        const status = axios.isAxiosError(error) ? error.response?.status : undefined;
        if (epoch === sessionEpoch && (status === 400 || status === 401 || status === 403)) {
          tokenStorage.clear();
          window.dispatchEvent(new Event("udm:logout"));
        }
        throw error;
      })
      .finally(() => { refreshing = null; });
  }
  return refreshing;
}

export function endSession(): Promise<void> {
  if (endingSession) return endingSession;
  const pendingRefresh = refreshing;
  tokenStorage.clear();
  endingSession = (async () => {
    // A delayed refresh can still set a cookie. Revoke after it settles.
    if (pendingRefresh) await pendingRefresh.catch(() => undefined);
    await axios.post(`${API_BASE_URL}/auth/admin/token/logout/`, {}, { withCredentials: true, timeout: 15_000 });
  })().finally(() => { endingSession = null; });
  return endingSession;
}

api.interceptors.request.use(async (config: RetriableConfig) => {
  const epoch = sessionEpoch;
  config._sessionEpoch = epoch;
  let token = tokenStorage.getAccess();
  if (token && expiresWithin(token, 45)) {
    try { token = await restoreSession(); }
    catch { token = tokenStorage.getAccess(); }
  }
  if (epoch !== sessionEpoch) throw new axios.CanceledError("Session changed.");
  if (token && config.headers) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (response) => {
    if ((response.config as RetriableConfig)._sessionEpoch !== sessionEpoch) throw new axios.CanceledError("Session changed.");
    return response;
  },
  async (error: AxiosError) => {
    const original = error.config as RetriableConfig | undefined;
    if (!original || original._sessionEpoch !== sessionEpoch) return Promise.reject(error);
    const sentHeader = original.headers?.Authorization;
    const sentToken = typeof sentHeader === "string" ? sentHeader.replace(/^Bearer\s+/i, "") : null;
    const status = error.response?.status;
    const shouldRefresh = status === 401 || (status === 403 && expiresWithin(sentToken, 0));
    if (!shouldRefresh || original._retry || !sessionActive || !sentToken) return Promise.reject(error);
    original._retry = true;
    try {
      const latest = tokenStorage.getAccess();
      const fresh = latest && latest !== sentToken && !expiresWithin(latest, 0)
        ? latest : await restoreSession();
      if (original._sessionEpoch !== sessionEpoch) throw new axios.CanceledError("Session changed.");
      if (fresh && original.headers) {
        original.headers.Authorization = `Bearer ${fresh}`;
        return api(original);
      }
    } catch { /* Refresh errors already invalidate rejected sessions. */ }
    return Promise.reject(error);
  },
);

/**
 * The API repeats its whole error envelope as `detail`, `code` and `errors`, and
 * `detail` is only generic ("The submitted data is not valid.") when a field
 * carries the actual reason — so `errors` has to win for a curator to know what
 * to fix.
 */
function firstFieldError(errors: unknown): string {
  if (!errors || typeof errors !== "object") return "";
  const map = errors as Record<string, unknown>;
  const message = (value: unknown) =>
    Array.isArray(value) && typeof value[0] === "string" ? value[0] : typeof value === "string" ? value : firstFieldError(value);

  for (const key of ["non_field_errors", "__all__"]) {
    const text = message(map[key]);
    if (text) return text;
  }
  for (const [key, value] of Object.entries(map)) {
    const text = message(value);
    if (text) return `${key.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase())}: ${text}`;
  }
  return "";
}

export function extractApiError(err: unknown, fallback = "Something went wrong"): string {
  if (axios.isAxiosError(err)) {
    const data = err.response?.data as Record<string, unknown> | undefined;
    if (data) {
      const envelope = data.error;
      if (envelope && typeof envelope === "object" && "message" in envelope && typeof envelope.message === "string") return envelope.message;
      const fieldError = firstFieldError(data.errors);
      if (fieldError) return fieldError;
      if (typeof data.detail === "string") return data.detail;
      if (typeof data.message === "string") return data.message;
      const firstField = Object.values(data)[0];
      if (Array.isArray(firstField) && typeof firstField[0] === "string") return firstField[0];
      if (typeof firstField === "string") return firstField;
    }
    return err.message || fallback;
  }
  return fallback;
}
