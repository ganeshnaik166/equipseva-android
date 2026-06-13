"use client";

import { useState, useTransition } from "react";
import { cancelPayout, markPayoutPaid } from "@/app/actions/payouts";

export function PayoutActions({ payoutId, status }: { payoutId: string; status: string }) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const settled =
    status === "paid" || status === "cancelled" || status === "processed" || status === "completed";
  if (settled || done) {
    return <span className="text-xs text-[var(--color-muted)]">{done ?? status}</span>;
  }

  function triggerPaid() {
    setErr(null);
    startTransition(async () => {
      const utr = window.prompt("UTR / reference number (required)") ?? "";
      if (utr.trim().length === 0) return;
      const mode = window.prompt("Mode (IMPS / NEFT / UPI / RTGS)") ?? "";
      const notes = window.prompt("Founder notes (optional)") ?? "";
      const res = await markPayoutPaid(payoutId, utr.trim(), mode.trim(), notes.trim());
      if (res.ok) setDone("paid");
      else setErr(res.error);
    });
  }

  function triggerCancel() {
    setErr(null);
    startTransition(async () => {
      const reason = window.prompt("Reason for cancel (required)") ?? "";
      if (reason.trim().length === 0) return;
      const res = await cancelPayout(payoutId, reason.trim());
      if (res.ok) setDone("cancelled");
      else setErr(res.error);
    });
  }

  return (
    <div className="flex items-center gap-1.5">
      <button
        type="button"
        disabled={pending}
        onClick={triggerPaid}
        className="rounded border border-[var(--color-ok)] px-1.5 py-0.5 text-xs text-[var(--color-ok)] hover:bg-green-50 disabled:opacity-50"
      >
        Mark paid
      </button>
      <button
        type="button"
        disabled={pending}
        onClick={triggerCancel}
        className="rounded border border-[var(--color-danger)] px-1.5 py-0.5 text-xs text-[var(--color-danger)] hover:bg-red-50 disabled:opacity-50"
      >
        Cancel
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
