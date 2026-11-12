import { FormEvent, useState } from "react";
import { BookOpenText, Loader2, MapPinned, ShieldCheck } from "lucide-react";
import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";
import { BrandLockup, BrandMark } from "@/components/BrandLockup";

export default function Login() {
  const { isAuthenticated, login } = useAuth();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [pending, setPending] = useState(false);

  if (isAuthenticated) {
    return <Navigate to={(location.state as { from?: { pathname?: string } })?.from?.pathname || "/"} replace />;
  }

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError("");
    setPending(true);
    try {
      await login(email.trim(), password);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "We could not sign you in.");
      setPending(false);
    }
  };

  return (
    <main className="auth-screen">
      <div className="auth-shell">
        <section className="auth-brand-panel" aria-label="About the ministry console">
          <div className="auth-brand-top">
            <BrandMark size={44} id="udm-auth-mark" />
            <div className="auth-brand-name"><strong>UDM</strong><small>MINISTRY CONSOLE</small></div>
          </div>

          <div className="auth-brand-copy">
            <span className="auth-eyebrow">Know Christ · Grow in Christ · Make Disciples</span>
            <h1>Curate what<br /><span>students read next.</span></h1>
            <p>
              Devotionals, articles, recordings, reading plans and the campus directory — published from here to
              the app, with every licence and privacy rule enforced by the same server.
            </p>
            <div className="auth-capabilities">
              <span className="auth-capability"><BookOpenText size={13} /> Daily devotionals</span>
              <span className="auth-capability"><ShieldCheck size={13} /> Licensed Scripture</span>
              <span className="auth-capability"><MapPinned size={13} /> Campus &amp; events</span>
            </div>
          </div>

          <div className="auth-brand-bottom">
            © {new Date().getFullYear()} University Discipleship Mission · Staff accounts only
          </div>
        </section>

        <section className="auth-form-panel">
          <div className="auth-form-wrap">
            <div className="auth-mobile-brand">
              <BrandMark size={38} id="udm-auth-mark-mobile" />
              <BrandLockup />
            </div>

            <div className="auth-form-heading">
              <span className="auth-eyebrow">Staff sign in</span>
              <h2>Ministry console</h2>
              <p>
                This console is for ministry staff accounts. A student account is turned away here rather than
                given tokens it could not use.
              </p>
            </div>

            <form onSubmit={submit} className="auth-form">
              <div className="auth-field">
                <label htmlFor="email">Work email</label>
                <input
                  id="email"
                  type="email"
                  autoComplete="email"
                  autoFocus
                  placeholder="you@udm.org"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  required
                />
              </div>
              <div className="auth-field">
                <label htmlFor="password">Password</label>
                <input
                  id="password"
                  type="password"
                  autoComplete="current-password"
                  placeholder="Your console password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  required
                />
              </div>

              {error && <p className="auth-form-error" role="alert">{error}</p>}

              <button type="submit" className="auth-primary-action" disabled={pending || !email.trim() || !password}>
                {pending
                  ? <><Loader2 size={16} className="animate-spin" /> Signing in…</>
                  : "Sign in"}
              </button>
            </form>

            <p className="auth-form-note">
              <ShieldCheck size={13} /> Your session cookie is HttpOnly and scoped to the console, so no script on
              this page can read it. Signing out revokes it on the server.
            </p>
          </div>
        </section>
      </div>
    </main>
  );
}
