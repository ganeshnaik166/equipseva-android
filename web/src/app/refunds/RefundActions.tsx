"use client";

import { useState, useTransition } from "react";
import { approveRefund, rejectRefund } from "@/app/actions/refunds";

export function RefundActions({ requestId }: { requestId: string }) {
  const [pending, startTransition] = useTransition();
  const [done, setDone] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  function trigger(kind: "approve" | "reject") {
    setErr(null);
    startTransition(async () => {
      const note =
        window.prompt(
          kind === "approve" ? "Approver note (optional)" : "Reason for rejection (required)",
        ) ?? "";
      if (kind === "reject" && note.trim().length === 0) return;
      const res =
        kind === "approve"
          ? await approveRefund(requestId, note.trim())
          : await rejectRefund(requestId, note.trim());
      if (res.ok) setDone(kind === "approve" ? "approved" : "rejected");
      else setErr(res.error);
    });
  }

  if (done) {
    return <span className="text-xs text-[var(--color-muted)]">{done}</span>;
  }
  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("approve")}
        className="rounded border border-[var(--color-ok)] px-2 py-0.5 text-xs text-[var(--color-ok)] hover:bg-green-50 disabled:opacity-50"
      >
        Approve
      </button>
      <button
        type="button"
        disabled={pending}
        onClick={() => trigger("reject")}
        className="rounded border border-[var(--color-danger)] px-2 py-0.5 text-xs text-[var(--color-danger)] hover:bg-red-50 disabled:opacity-50"
      >
        Reject
      </button>
      {err && <span className="text-xs text-[var(--color-danger)]">{err}</span>}
    </div>
  );
}
