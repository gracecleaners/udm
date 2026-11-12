import { FormEvent, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Loader2, ShieldCheck } from "lucide-react";
import { api, extractApiError } from "@/lib/api";
import { useAuth } from "@/contexts/AuthContext";
import { fetchIdentity } from "@/services/authService";
import { toast } from "@/hooks/use-toast";

export default function Account() {
  const { user, logout } = useAuth();
  const queryClient = useQueryClient();
  const identityQ = useQuery({ queryKey: ["identity"], queryFn: fetchIdentity, staleTime: 60_000 });
  const [fullName, setFullName] = useState<string | null>(null);

  const name = fullName ?? identityQ.data?.display_name ?? user?.display_name ?? "";

  const save = useMutation({
    // The console edits the staff account's own profile; email is server-owned.
    mutationFn: async (value: string) => (await api.patch("/users/me/", { full_name: value.trim() })).data,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["identity"] });
      setFullName(null);
      toast({ title: "Name updated", description: "Students see this on anything you publish as author." });
    },
    onError: (error) => toast({ title: "Could not save", description: extractApiError(error), variant: "destructive" }),
  });

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (name.trim()) save.mutate(name);
  };

  return (
    <div className="console-page console-page-narrow">
      <header className="console-page-head">
        <div>
          <h1>Your console account</h1>
          <p>The API decides what your account may do. This page only reports it.</p>
        </div>
      </header>

      <section className="console-panel" aria-label="Account summary">
        <dl className="console-definition">
          <div><dt>Name</dt><dd>{identityQ.data?.display_name || user?.display_name || "—"}</dd></div>
          <div><dt>Email</dt><dd>{user?.email}</dd></div>
          <div>
            <dt>Access</dt>
            <dd>{user?.is_superuser ? "Superuser" : "Ministry staff"}</dd>
          </div>
        </dl>
        <p className="console-note">
          <ShieldCheck size={13} aria-hidden="true" />
          {user?.is_superuser
            ? "As a platform admin you curate content, read the campus directory and decide which Bible editions students may read — the licensing assertion no other account is allowed to make."
            : "Staff accounts can curate content and the campus directory. Bible licensing is the one surface you read but do not change: only a platform admin decides which editions students may read."}{" "}
          A student&apos;s reading history, bookmarks, notes and private prayer requests are never exposed here —
          that record belongs to the student.
        </p>
      </section>

      <section className="console-panel" aria-label="Name">
        <h2 className="console-section-title">Display name</h2>
        <form onSubmit={submit} className="console-form">
          <label className="console-field">
            <span>Full name</span>
            <input
              value={name}
              onChange={(event) => setFullName(event.target.value)}
              placeholder="Your name as students should see it"
              maxLength={120}
            />
          </label>
          <div className="console-form-actions">
            <button type="submit" className="console-button" disabled={save.isPending || !name.trim()}>
              {save.isPending ? <><Loader2 size={15} className="animate-spin" /> Saving…</> : "Save name"}
            </button>
          </div>
        </form>
      </section>

      <section className="console-panel" aria-label="Session">
        <h2 className="console-section-title">Session</h2>
        <p className="console-note">
          Your refresh cookie is HttpOnly and scoped to the console endpoints. Signing out revokes it on the
          server; signing out with no network only clears this browser.
        </p>
        <div className="console-form-actions">
          <button type="button" className="console-button console-button-quiet" onClick={logout}>Sign out</button>
        </div>
      </section>
    </div>
  );
}
