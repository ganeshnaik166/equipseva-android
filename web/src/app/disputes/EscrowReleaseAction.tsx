"use client";

import { useState, useTransition } from "react";
import { forceReleaseEscrow } from "@/app/actions/disputes";

export function EscrowReleaseAction({ escrowId }: { escrowId: string | null }) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (!escrowId) return <span className="text-xs text-[var(--color-muted)]">no escrow id</span>;
  if (done) return <span className="text-xs text-[var(--color-muted)]">released</span>;

  function trigger() {
    setErr(null);
    startTransition(async () => {
      const reason = window.prompt(
        "Reason for force-releasing escrow (min 10 chars — logged to founder_action_log)",
      );
      if (!reason || reason.trim().length < 10) {
        setErr("Cancelled or reason too short.");
        return;
      }
      const res = await forceReleaseEscrow(escrowId!, reason.trim());
      if (res.ok) setDone(true);
      else setErr(res.error);
    });
  }

  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        disabled={pending}
        onClick={trigger}
        className="rounded border border-[var(--color-warn)] px-2 py-0.5 text-xs text-[var(--color-warn)] hover:bg-yellow-50 disabled:opacity-50"
      >
        Force release
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
