"use client";

import { useState, useTransition } from "react";
import { inviteSiteToChain } from "@/app/actions/chains";

export function InviteForm({ chainId }: { chainId: string }) {
  const [pending, startTransition] = useTransition();
  const [email, setEmail] = useState("");
  const [label, setLabel] = useState("");
  const [msg, setMsg] = useState<{ kind: "ok" | "err"; text: string } | null>(null);

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setMsg(null);
    startTransition(async () => {
      const res = await inviteSiteToChain({
        chainId,
        email,
        siteLabel: label || undefined,
      });
      if (res.ok) {
        setMsg({ kind: "ok", text: `Invite created. id=${res.id.slice(0, 8)}…` });
        setEmail("");
        setLabel("");
      } else {
        setMsg({ kind: "err", text: res.error });
      }
    });
  }

  return (
    <form
      onSubmit={onSubmit}
      className="flex flex-wrap items-end gap-3 rounded border border-[var(--color-border)] bg-white p-3"
    >
      <label className="block text-sm">
        <span className="text-xs text-[var(--color-muted)]">Site admin email</span>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mt-1 w-72 rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          placeholder="ops@site.clovedental.com"
        />
      </label>
      <label className="block text-sm">
        <span className="text-xs text-[var(--color-muted)]">Site label (optional)</span>
        <input
          type="text"
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          className="mt-1 w-72 rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          placeholder="Clove Banjara Hills"
        />
      </label>
      <button
        type="submit"
        disabled={pending}
        className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm font-medium text-white disabled:opacity-50"
      >
        {pending ? "Inviting…" : "Send invite"}
      </button>
      {msg && (
        <span
          className={
            msg.kind === "ok"
              ? "text-sm text-[var(--color-ok)]"
              : "text-sm text-[var(--color-danger)]"
          }
        >
          {msg.text}
        </span>
      )}
      <p className="basis-full text-xs text-[var(--color-muted)]">
        Invite token expires in 14 days. The invited email must match the redeemer&rsquo;s
        Supabase Auth email exactly (case-insensitive) to prevent token replay.
      </p>
    </form>
  );
}
