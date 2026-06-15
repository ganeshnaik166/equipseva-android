"use client";

import { useState, useTransition } from "react";
import { revokeSupervision } from "@/app/actions/training";

export function RevokeAssignmentButton({ assignmentId }: { assignmentId: string }) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (done) return <span className="text-xs text-[var(--color-muted)]">revoked</span>;

  function trigger() {
    setErr(null);
    startTransition(async () => {
      const reason = window.prompt("Revoke reason (min 10 chars — logged forever)");
      if (!reason || reason.trim().length < 10) {
        setErr("Cancelled or reason too short.");
        return;
      }
      const res = await revokeSupervision(assignmentId, reason.trim());
      if (res.ok) setDone(true);
      else setErr(res.error);
    });
  }

  return (
    <div className="flex items-center gap-1.5">
      <button
        type="button"
        disabled={pending}
        onClick={trigger}
        className="rounded border border-[var(--color-danger)] px-1.5 py-0.5 text-xs text-[var(--color-danger)] hover:bg-red-50 disabled:opacity-50"
      >
        Revoke
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
