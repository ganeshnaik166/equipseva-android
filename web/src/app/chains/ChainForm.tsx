"use client";

import { useState, useTransition } from "react";
import { registerHospitalChain } from "@/app/actions/chains";

export function ChainForm() {
  const [pending, startTransition] = useTransition();
  const [name, setName] = useState("");
  const [adminId, setAdminId] = useState("");
  const [gstin, setGstin] = useState("");
  const [notes, setNotes] = useState("");
  const [msg, setMsg] = useState<{ kind: "ok" | "err"; text: string } | null>(null);

  function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setMsg(null);
    startTransition(async () => {
      const res = await registerHospitalChain({
        name,
        primaryAdminUserId: adminId,
        billingGstin: gstin || undefined,
        notes: notes || undefined,
      });
      if (res.ok) {
        setMsg({ kind: "ok", text: `Registered. id=${res.id.slice(0, 8)}…` });
        setName("");
        setAdminId("");
        setGstin("");
        setNotes("");
      } else {
        setMsg({ kind: "err", text: res.error });
      }
    });
  }

  return (
    <form onSubmit={onSubmit} className="space-y-3 rounded border border-[var(--color-border)] bg-white p-4">
      <h3 className="text-sm font-semibold">Register hospital chain</h3>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        <label className="block text-sm md:col-span-2">
          <span className="text-xs text-[var(--color-muted)]">Chain name</span>
          <input
            type="text"
            required
            minLength={3}
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            placeholder="Clove Dental"
          />
        </label>
        <label className="block text-sm md:col-span-2">
          <span className="text-xs text-[var(--color-muted)]">
            Primary admin user_id (UUID)
          </span>
          <input
            type="text"
            required
            value={adminId}
            onChange={(e) => setAdminId(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 font-mono text-xs"
            placeholder="copy from /audit row or /engineers/[id] URL"
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Billing GSTIN (optional)</span>
          <input
            type="text"
            value={gstin}
            onChange={(e) => setGstin(e.target.value.toUpperCase())}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 font-mono text-xs uppercase"
            placeholder="29ABCDE1234F1Z5"
            maxLength={15}
          />
        </label>
        <label className="block text-sm">
          <span className="text-xs text-[var(--color-muted)]">Notes (optional)</span>
          <input
            type="text"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            className="mt-1 w-full rounded border border-[var(--color-border)] px-2 py-1 text-sm"
            placeholder="Pilot agreement signed 2026-06"
          />
        </label>
      </div>
      {msg && (
        <div
          className={
            msg.kind === "ok"
              ? "text-sm text-[var(--color-ok)]"
              : "text-sm text-[var(--color-danger)]"
          }
        >
          {msg.text}
        </div>
      )}
      <button
        type="submit"
        disabled={pending}
        className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm font-medium text-white disabled:opacity-50"
      >
        {pending ? "Registering…" : "Register chain"}
      </button>
      <p className="text-xs text-[var(--color-muted)]">
        Writes to <code>founder_action_log</code>. Auto-adds the primary admin as a chain
        member with role <code>admin</code>.
      </p>
    </form>
  );
}
