"use client";

import { useState, useTransition } from "react";
import { decideEvidencePack, type PackDecision } from "@/app/actions/vault";

export function PackActions({ packId }: { packId: string }) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function trigger(decision: PackDecision) {
    setErr(null);
    startTransition(async () => {
      const note = window.prompt(
        `Mediator note (min 5 chars — logged forever):\n\nWill mark this pack as ${decision.toUpperCase()}.`,
      );
      if (!note || note.trim().length < 5) {
        setErr("Cancelled or note too short.");
        return;
      }
      const res = await decideEvidencePack(packId, decision, note.trim());
      if (res.ok) setDone(decision);
      else setErr(res.error);
    });
  }

  if (done) return <span className="text-xs text-[var(--color-muted)]">{done}</span>;

  return (
    <div className="flex items-center gap-1.5">
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("accepted")}
        className="rounded border border-[var(--color-ok)] px-2 py-0.5 text-xs text-[var(--color-ok)] hover:bg-green-50 disabled:opacity-50"
      >
        Accept
      </button>
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("rejected")}
        className="rounded border border-[var(--color-danger)] px-2 py-0.5 text-xs text-[var(--color-danger)] hover:bg-red-50 disabled:opacity-50"
      >
        Reject
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
