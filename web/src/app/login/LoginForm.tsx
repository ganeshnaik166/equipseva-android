"use client";

import { useState } from "react";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

export function LoginForm() {
  const [email, setEmail] = useState(process.env.NEXT_PUBLIC_FOUNDER_EMAIL ?? "");
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("sending");
    setErrorMsg(null);
    const supabase = getSupabaseBrowserClient();
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    if (error) {
      setStatus("error");
      setErrorMsg(error.message);
      return;
    }
    setStatus("sent");
  }

  if (status === "sent") {
    return (
      <div className="rounded border border-[var(--color-border)] bg-white p-4 text-sm">
        Check <span className="font-medium">{email}</span> for the magic link. Open
        it on this device to sign in.
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="space-y-3">
      <label className="block text-sm font-medium">Email</label>
      <input
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        className="w-full rounded border border-[var(--color-border)] bg-white px-3 py-2 text-sm"
        placeholder="ganesh1431.dhanavath@gmail.com"
        autoComplete="email"
      />
      {errorMsg && (
        <div className="text-sm text-[var(--color-danger)]">{errorMsg}</div>
      )}
      <button
        type="submit"
        disabled={status === "sending"}
        className="w-full rounded bg-[var(--color-accent)] px-3 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        {status === "sending" ? "Sending…" : "Send magic link"}
      </button>
    </form>
  );
}
