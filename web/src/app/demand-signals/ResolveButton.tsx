"use client";

import { useState, useTransition } from "react";
import { resolveDemandSignal } from "@/app/actions/demandSignals";

const OPTIONS: { key: string; label: string }[] = [
  { key: "supplier_onboarded", label: "Supplier onboarded" },
  { key: "bonded_intake", label: "Bonded intake landed" },
  { key: "duplicate_of_existing", label: "Duplicate of existing" },
  { key: "fulfilled_offplatform", label: "Fulfilled off-platform" },
  { key: "wont_fulfill", label: "Won't fulfill" },
];

export function ResolveButton({ signalId }: { signalId: string }) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [via, setVia] = useState<string>("supplier_onboarded");
  const [notes, setNotes] = useState<string>("");

  if (done) return <span className="text-xs text-[var(--color-muted)]">resolved</span>;

  function submit() {
    setErr(null);
    if (notes.trim().length < 10) {
      setErr("Notes min 10 chars.");
      return;
    }
    startTransition(async () => {
      const res = await resolveDemandSignal(signalId, via, notes.trim());
      if (res.ok) {
        setDone(true);
        setOpen(false);
      } else {
        setErr(res.error);
      }
    });
  }

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="rounded border border-[var(--color-border)] px-1.5 py-0.5 text-xs hover:bg-gray-50"
      >
        Resolve
      </button>
    );
  }

  return (
    <div className="flex flex-col gap-1 rounded border border-[var(--color-border)] bg-white p-2">
      <select
        value={via}
        onChange={(e) => setVia(e.target.value)}
        className="rounded border border-[var(--color-border)] px-1 py-0.5 text-xs"
      >
        {OPTIONS.map((o) => (
          <option key={o.key} value={o.key}>
            {o.label}
          </option>
        ))}
      </select>
      <input
        type="text"
        value={notes}
        placeholder="notes (min 10 chars)"
        onChange={(e) => setNotes(e.target.value)}
        className="w-44 rounded border border-[var(--color-border)] px-1 py-0.5 text-xs"
      />
      <div className="flex items-center gap-1.5">
        <button
          type="button"
          disabled={pending}
          onClick={submit}
          className="rounded bg-[var(--color-accent)] px-1.5 py-0.5 text-xs text-white disabled:opacity-50"
        >
          Save
        </button>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="rounded border border-[var(--color-border)] px-1.5 py-0.5 text-xs hover:bg-gray-50"
        >
          Cancel
        </button>
        {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
      </div>
    </div>
  );
}
